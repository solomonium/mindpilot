import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<User?> signInWithGoogle() async {
    try {
      // Ensure the plugin is initialized with the Web Client ID for Android
      await GoogleSignIn.instance.initialize(
        serverClientId: '802202587833-rqih2hp4dmur1lrqku0dq08bblf6ng6m.apps.googleusercontent.com',
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
      return userCredential.user;
    } catch (e) {
      print('Error during Google Sign-In: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.disconnect();
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }
}
