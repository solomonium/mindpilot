import 'package:firebase_auth/firebase_auth.dart';
import 'package:mindpilot/export.dart';

class AuthProvider extends BaseProvider {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  User? _user;
  User? get user => _user;

  AuthProvider() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<void> loginWithGoogle(BuildContext context) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        _user = user;
        notifyListeners();
        context.pushOff(const MainScreen());
      } else {
        // Handle error or cancellation
        context.showInAppNotification('Google Sign-In failed or was cancelled');
      }
    } catch (e) {
      context.showInAppNotification('An error occurred: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loginWithEmail(BuildContext context, String email, String password) async {
    _isLoading = true;
    notifyListeners();

    // Implement email login logic here if needed
    // For now, just simulate success
    await Future.delayed(const Duration(seconds: 1));
    context.pushOff(const MainScreen());

    _isLoading = false;
    notifyListeners();
  }
}
