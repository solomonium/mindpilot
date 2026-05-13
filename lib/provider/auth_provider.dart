import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mindpilot/export.dart';

class AuthProvider extends BaseProvider {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  User? _user;
  User? get user => _user;

  String _userType = "Freemium";
  String get userType => _userType;
  bool get isPro => _userType == "Pro Member";

  bool _isAdmin = false;
  bool get isAdmin => _isAdmin;
  final List<String> _superAdmins = ['laleyesolomon2@gmail.com', 'solteqinnovationsltd@gmail.com'];

  StreamSubscription? _userDocSubscription;

  AuthProvider() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      _user = user;
      if (user != null) {
        _listenToUserType(user);
        _checkAdminStatus(user);
      } else {
        _userDocSubscription?.cancel();
        _userType = "Freemium";
        _isAdmin = false;
      }
      notifyListeners();
    });
  }

  void _checkAdminStatus(User user) async {
    final email = user.email?.toLowerCase();
    if (email == null) return;

    if (_superAdmins.contains(email)) {
      _isAdmin = true;
      notifyListeners();
      return;
    }

    // Check Firestore admins collection
    try {
      final doc = await _firestore.collection('admins').doc(email).get();
      _isAdmin = doc.exists;
      notifyListeners();
    } catch (e) {
      safePrint('Admin check error: $e');
    }
  }

  void _listenToUserType(User user) {
    _userDocSubscription?.cancel();

    // Check if it's a super admin (always Pro)
    if (_superAdmins.contains(user.email?.toLowerCase())) {
      _userType = "Pro Member";
      notifyListeners();
      return;
    }

    // Otherwise, listen to Firestore
    _userDocSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
          if (doc.exists) {
            _userType = doc.data()?['userType'] ?? "Freemium";
          } else {
            // Create the user doc if it doesn't exist
            _firestore.collection('users').doc(user.uid).set({
              'email': user.email,
              'userType': 'Freemium',
              'createdAt': FieldValue.serverTimestamp(),
            });
            _userType = "Freemium";
          }
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
        context.showInAppNotification('Google Sign-In failed or was cancelled');
      }
    } catch (e) {
      context.showInAppNotification('An error occurred: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loginWithEmail(
    BuildContext context,
    String email,
    String password,
  ) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(seconds: 1));
    context.pushOff(const MainScreen());
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _userDocSubscription?.cancel();
    super.dispose();
  }
}
