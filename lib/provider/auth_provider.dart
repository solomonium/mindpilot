import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mindpilot/export.dart';

class AppAuthProvider extends BaseProvider {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  User? _user;
  User? get user => _user;

  String _userType = "Freemium";
  String get userType => _userType;
  bool get isPro => _userType == "Pro Member";

  String _aiTone = "Balanced";
  String get aiTone => _aiTone;

  String _aiPersonality = "Encouraging";
  String get aiPersonality => _aiPersonality;

  String? _phoneNumber;
  String? get phoneNumber => _phoneNumber;
  
  String? _location;
  String? get location => _location;

  String? _country;
  String? get country => _country;

  bool _isAdmin = false;
  bool get isAdmin => _isAdmin;
  int _explanationCount = 0;
  int get explanationCount => _explanationCount;

  int _decisionCredits = 3;
  int get decisionCredits => _decisionCredits;

  int _insightIntervalHours = 1;
  int get insightIntervalHours => _insightIntervalHours;

  final List<String> _superAdmins = ['laleyesolomon2@gmail.com', 'solteqinnovationsltd@gmail.com'];

  StreamSubscription? _userDocSubscription;

  AppAuthProvider() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      _user = user;
      if (user != null) {
        _listenToUserType(user);
        _checkAdminStatus(user);
        final name = user.displayName?.getFirstName();
        GeminiService().setUserName(name);
        
        // Sync FCM Token immediately on login/startup
        FirebaseMessaging.instance.getToken().then((token) {
          if (token != null) updateFcmToken(token);
        });
      } else {
        _userDocSubscription?.cancel();
        _userType = "Freemium";
        _isAdmin = false;
        _aiTone = "Balanced";
        _aiPersonality = "Encouraging";
        GeminiService().setUserName(null);
        GeminiService().setAiPreferences("Balanced", "Encouraging");
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

    try {
      final doc = await _firestore.collection('admins').doc(email).get();
      _isAdmin = doc.exists;
      notifyListeners();
    } catch (e) {
      safePrint('Error: $e');
    }
  }

  void _listenToUserType(User user) {
    _userDocSubscription?.cancel();

    if (_superAdmins.contains(user.email?.toLowerCase())) {
      _userType = "Pro Member";
      notifyListeners();
      return;
    }

    _userDocSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
          if (doc.exists) {
            _userType = doc.data()?['userType'] ?? "Freemium";
            _explanationCount = doc.data()?['explanationCount'] ?? 0;
            _aiTone = doc.data()?['aiTone'] ?? "Balanced";
            _aiPersonality = doc.data()?['aiPersonality'] ?? "Encouraging";
            _phoneNumber = doc.data()?['phoneNumber'];
            _location = doc.data()?['location'];
            _country = doc.data()?['country'];
            _insightIntervalHours = doc.data()?['insightIntervalHours'] ?? 1;
            
            final personalization = List<String>.from(doc.data()?['personalization'] ?? []);
            GeminiService().setPersonalization(personalization);
            GeminiService().setAiPreferences(_aiTone, _aiPersonality);
            
            _syncTempPersonalization(user.uid);
          } else {
            _firestore.collection('users').doc(user.uid).set({
              'email': user.email,
              'name': user.displayName ?? '',
              'fullName': user.displayName ?? '',
              'displayName': user.displayName ?? '',
              'userType': 'Freemium',
              'personalization': [],
              'aiTone': 'Balanced',
              'aiPersonality': 'Encouraging',
              'explanationCount': 0,
              'insightIntervalHours': 1,
              'country': '',
              'createdAt': FieldValue.serverTimestamp(),
            }).then((_) => _syncTempPersonalization(user.uid));
            _userType = "Freemium";
          }
          notifyListeners();
          _checkAndResetDecisionCredits();
        });
  }

  Future<void> _checkAndResetDecisionCredits() async {
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final lastReset = await SharedPrefs.getString('LAST_DECISION_RESET_DATE');

    if (lastReset != today) {
      _decisionCredits = 3;
      await SharedPrefs.setString('LAST_DECISION_RESET_DATE', today);
      await SharedPrefs.setInt('DECISION_CREDITS', 3);
    } else {
      _decisionCredits = await SharedPrefs.getInt('DECISION_CREDITS') ?? 3;
    }
    notifyListeners();
  }

  Future<void> useDecisionCredit() async {
    if (isPro) return;
    if (_decisionCredits > 0) {
      _decisionCredits--;
      await SharedPrefs.setInt('DECISION_CREDITS', _decisionCredits);
      notifyListeners();
    }
  }

  Future<void> updateUserProfile({String? phoneNumber, String? location, String? country}) async {
    if (_user == null) return;
    
    final updates = <String, dynamic>{};
    if (phoneNumber != null) {
      _phoneNumber = phoneNumber;
      updates['phoneNumber'] = phoneNumber;
    }
    if (location != null) {
      _location = location;
      updates['location'] = location;
    }
    if (country != null) {
      _country = country;
      updates['country'] = country;
    }
    
    if (updates.isEmpty) return;
    notifyListeners();
    
    try {
      await _firestore.collection('users').doc(_user!.uid).update(updates);
    } catch (e) {
      safePrint('Error: $e');
    }
  }

  Future<void> updateAiPreferences(String tone, String personality) async {
    if (_user == null) return;
    _aiTone = tone;
    _aiPersonality = personality;
    notifyListeners();
    
    try {
      await _firestore.collection('users').doc(_user!.uid).update({
        'aiTone': tone,
        'aiPersonality': personality,
      });
      GeminiService().setAiPreferences(tone, personality);
    } catch (e) {
      safePrint('Error: $e');
    }
  }

  Future<void> _syncTempPersonalization(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tempGoals = prefs.getStringList('TEMP_PERSONALIZATION');
      
      if (tempGoals != null && tempGoals.isNotEmpty) {
        await _firestore.collection('users').doc(uid).update({
          'personalization': tempGoals,
          'hasCompletedSetup': true,
        });
        await prefs.remove('TEMP_PERSONALIZATION');
      }
    } catch (e) {
      safePrint('Error: $e');
    }
  }

  Future<void> incrementExplanationCount() async {
    if (_user == null) return;
    _explanationCount++;
    notifyListeners();
    try {
      await _firestore.collection('users').doc(_user!.uid).update({
        'explanationCount': _explanationCount,
      });
    } catch (e) {
      safePrint('Error: $e');
    }
  }

  Future<void> updateInsightInterval(int hours) async {
    if (_user == null) return;
    _insightIntervalHours = hours;
    notifyListeners();
    try {
      await _firestore.collection('users').doc(_user!.uid).update({
        'insightIntervalHours': hours,
      });
    } catch (e) {
      safePrint('Error: $e');
    }
  }

  Future<void> updateFcmToken(String? token) async {
    if (_user == null || token == null) return;
    try {
      await _firestore.collection('users').doc(_user!.uid).update({
        'fcmToken': token,
      });
    } catch (e) {
      safePrint('Error: $e');
    }
  }

  Future<void> loginWithGoogle(BuildContext context) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        _user = user;
        
        final doc = await _firestore.collection('users').doc(user.uid).get().timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('Login check timed out'),
        );
        final hasPersonalized = doc.data()?['hasCompletedSetup'] ?? false;
        
        if (context.mounted) {
          context.read<JournalProvider>().loadInitialData();
          context.read<TaskProvider>().loadTasks();
          
          if (!hasPersonalized) {
            context.pushOff(const PersonalizationScreen());
          } else {
            context.pushOff(const MainScreen());
          }
        }

        notifyListeners();
      } else {
        context.showInAppNotification('Sign-In failed');
      }
    } catch (e) {
      context.showInAppNotification('Error: $e');
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

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    notifyListeners();
  }

  Future<void> deleteAccount(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      context.showInAppNotification('No user is currently signed in.');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final uid = currentUser.uid;

      // Cancel user document subscription BEFORE deleting the document
      // to prevent the snapshot listener from auto-recreating it.
      _userDocSubscription?.cancel();
      _userDocSubscription = null;

      // 1. Delete all tasks from the user's tasks subcollection in Firestore
      final tasksSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .get();
      for (var doc in tasksSnapshot.docs) {
        await doc.reference.delete();
      }

      // 2. Delete all journals from the user's journals subcollection in Firestore
      final journalsSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('journals')
          .get();
      for (var doc in journalsSnapshot.docs) {
        await doc.reference.delete();
      }

      // 3. Delete the user's main document in Firestore
      await _firestore.collection('users').doc(uid).delete();

      // 4. Delete the user from Firebase Authentication
      await currentUser.delete();

      // 5. Clear all local DB entries
      await DatabaseHelper().clearAll();

      // 6. Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (context.mounted) {
        context.showInAppNotification(
          'Account and all data deleted successfully.',
          type: InAppNotificationType.success,
        );
        context.pushOff(const LoginScreen());
      }
    } on FirebaseAuthException catch (e) {
      safePrint('FirebaseAuthException: ${e.code} - ${e.message}');
      if (e.code == 'requires-recent-login') {
        if (context.mounted) {
          context.showInAppNotification(
            'For your security, please log out and log back in, then try again.',
            type: InAppNotificationType.error,
          );
        }
      } else {
        if (context.mounted) {
          context.showInAppNotification(e.message ?? 'Failed to delete account.');
        }
      }
    } catch (e) {
      safePrint('Error during account deletion: $e');
      if (context.mounted) {
        context.showInAppNotification('Error deleting account: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _userDocSubscription?.cancel();
    super.dispose();
  }
}
