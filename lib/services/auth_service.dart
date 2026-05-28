import 'package:mindpilot/export.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache name from the most recent Apple Sign-In authorization
  static String? lastAppleFullName;

  Future<User?> signInWithGoogle() async {
    try {
      // Ensure the plugin is initialized with correct server client ID, avoiding overriding platform client ID on iOS/Android
      await GoogleSignIn.instance.initialize(
        clientId: kIsWeb ? dotenv.env['GOOGLE_SIGN_IN_CLIENT_ID'] : null,
        serverClientId: dotenv.env['GOOGLE_SIGN_IN_SERVER_CLIENT_ID'] ?? '802202587833-rqih2hp4dmur1lrqku0dq08bblf6ng6m.apps.googleusercontent.com',
      );

      final GoogleSignInAccount? googleUser = await GoogleSignIn.instance.authenticate();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      // In version 7+, accessToken is handled separately via the authorizationClient
      final authorization = await GoogleSignIn.instance.authorizationClient.authorizeScopes(['email', 'profile']);
      final String? accessToken = authorization.accessToken;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        safePrint('🎉 Successful Google Sign-In! Firebase User details:');
        safePrint('  UID: ${user.uid}');
        safePrint('  Email: ${user.email}');
        safePrint('  Display Name: ${user.displayName}');
        safePrint('  Photo URL: ${user.photoURL}');
      }

      return userCredential.user;
    } catch (e) {
      safePrint('Error during Google Sign-In: $e');
      return null;
    }
  }

  Future<User?> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Cache the full name immediately before signing in (since authStateChanges fires instantly)
      if (credential.givenName != null || credential.familyName != null) {
        lastAppleFullName = '${credential.givenName ?? ''} ${credential.familyName ?? ''}'.trim();
      }

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(oauthCredential);
      final User? user = userCredential.user;

      safePrint('🍏 Successful Apple Sign-In! Raw Credential details:');
      safePrint('  User Identifier: ${credential.userIdentifier}');
      safePrint('  Given Name: ${credential.givenName}');
      safePrint('  Family Name: ${credential.familyName}');
      safePrint('  Email: ${credential.email}');
      safePrint('  Identity Token length: ${credential.identityToken?.length}');
      safePrint('  Authorization Code length: ${credential.authorizationCode.length}');

      if (user != null) {
        safePrint('🎉 Firebase User details:');
        safePrint('  UID: ${user.uid}');
        safePrint('  Email: ${user.email}');
        safePrint('  Display Name: ${user.displayName}');
        safePrint('  Photo URL: ${user.photoURL}');
      }

      if (user != null && lastAppleFullName != null && lastAppleFullName!.isNotEmpty) {
        try {
          await user.updateDisplayName(lastAppleFullName);
          await user.reload();
        } catch (e) {
          safePrint('Error updating Apple display name: $e');
        }
      }

      return _auth.currentUser;
    } catch (e) {
      safePrint('Error during Apple Sign-In: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.disconnect();
      await _auth.signOut();
    } catch (e) {
      safePrint('Error signing out: $e');
    }
  }
}
