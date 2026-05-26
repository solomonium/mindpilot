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

  String? _displayName;
  String? get displayName => _displayName;

  String? _email;
  String? get email => _email;

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
        _displayName = user.displayName;
        _email = user.email;
        ensureFirestoreUserExists(user).then((_) {
          _listenToUserType(user);
          _checkAdminStatus(user);
          PaymentService.syncSubscriptionStatus();
        });
        final displayName = (user.displayName != null && user.displayName!.isNotEmpty)
            ? user.displayName
            : AuthService.lastAppleFullName;
        final name = displayName?.getFirstName();
        GeminiService().setUserName(name);
        
        // Sync FCM Token immediately on login/startup
        NotificationService().logDeviceToken();
      } else {
        _userDocSubscription?.cancel();
        _userType = "Freemium";
        _isAdmin = false;
        _aiTone = "Balanced";
        _aiPersonality = "Encouraging";
        _displayName = null;
        _email = null;
        GeminiService().setUserName(null);
        GeminiService().setAiPreferences("Balanced", "Encouraging");
      }
      notifyListeners();
    });
  }

  Future<void> ensureFirestoreUserExists(User user) async {
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        final fallbackName = (user.displayName != null && user.displayName!.isNotEmpty)
            ? user.displayName!
            : (AuthService.lastAppleFullName ?? '');

        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'name': fallbackName,
          'fullName': fallbackName,
          'displayName': fallbackName,
          'userType': 'Freemium',
          'personalization': [],
          'aiTone': 'Balanced',
          'aiPersonality': 'Encouraging',
          'explanationCount': 0,
          'insightIntervalHours': 1,
          'country': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
        safePrint('🚀 Proactively created missing Firestore user document for UID: ${user.uid}');

        try {
          await _firestore.collection('app_config').doc('settings').set({
            'authenticated_users_count': FieldValue.increment(1),
          }, SetOptions(merge: true));
          safePrint('📈 Automatically incremented authenticated_users_count in settings');
        } catch (e) {
          safePrint('⚠️ Failed to increment authenticated_users_count: $e');
        }
      }
    } catch (e) {
      safePrint('⚠️ Error ensuring Firestore user exists: $e');
    }
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
            
            final docDisplayName = doc.data()?['displayName'] ?? doc.data()?['name'] ?? doc.data()?['fullName'];
            if (docDisplayName != null && docDisplayName.toString().isNotEmpty) {
              _displayName = docDisplayName.toString();
              final name = _displayName?.getFirstName();
              GeminiService().setUserName(name);
            }
            final docEmail = doc.data()?['email'];
            if (docEmail != null && docEmail.toString().isNotEmpty) {
              _email = docEmail.toString();
            }
            
            final personalization = List<String>.from(doc.data()?['personalization'] ?? []);
            GeminiService().setPersonalization(personalization);
            GeminiService().setAiPreferences(_aiTone, _aiPersonality);
            
            _syncTempPersonalization(user.uid);

            // Retroactive name sync for Apple users whose name fields are currently empty
            final currentName = doc.data()?['name'] ?? '';
            final currentDisplayName = doc.data()?['displayName'] ?? '';
            final currentFullName = doc.data()?['fullName'] ?? '';

            if ((currentName.isEmpty || currentDisplayName.isEmpty || currentFullName.isEmpty) &&
                AuthService.lastAppleFullName != null &&
                AuthService.lastAppleFullName!.isNotEmpty) {
              _firestore.collection('users').doc(user.uid).update({
                'name': AuthService.lastAppleFullName,
                'fullName': AuthService.lastAppleFullName,
                'displayName': AuthService.lastAppleFullName,
              }).then((_) {
                safePrint('Successfully retroactively updated Apple user name to: ${AuthService.lastAppleFullName}');
                AuthService.lastAppleFullName = null; // Consume the cached name
              }).catchError((e) {
                safePrint('Error retroactively updating Apple name: $e');
              });
            }
          } else {
            final fallbackName = (user.displayName != null && user.displayName!.isNotEmpty)
                ? user.displayName!
                : (AuthService.lastAppleFullName ?? '');

            _firestore.collection('users').doc(user.uid).set({
              'email': user.email,
              'name': fallbackName,
              'fullName': fallbackName,
              'displayName': fallbackName,
              'userType': 'Freemium',
              'personalization': [],
              'aiTone': 'Balanced',
              'aiPersonality': 'Encouraging',
              'explanationCount': 0,
              'insightIntervalHours': 1,
              'country': '',
              'createdAt': FieldValue.serverTimestamp(),
            }).then((_) {
              _syncTempPersonalization(user.uid);
              AuthService.lastAppleFullName = null; // Consume the cached name

              _firestore.collection('app_config').doc('settings').set({
                'authenticated_users_count': FieldValue.increment(1),
              }, SetOptions(merge: true)).catchError((e) {
                safePrint('⚠️ Failed to increment count: $e');
              });
            });
            _displayName = fallbackName;
            _email = user.email;
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

  Future<void> updateUserProfile({String? displayName, String? phoneNumber, String? location, String? country}) async {
    if (_user == null) return;
    
    final updates = <String, dynamic>{};
    if (displayName != null) {
      _displayName = displayName;
      updates['name'] = displayName;
      updates['fullName'] = displayName;
      updates['displayName'] = displayName;
      
      try {
        await _user!.updateDisplayName(displayName);
        await _user!.reload();
        _user = FirebaseAuth.instance.currentUser;
      } catch (e) {
        safePrint('Error updating firebase auth displayName: $e');
      }
    }
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
      safePrint('Error updating user profile: $e');
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

  Future<void> rewardExplanationCount() async {
    if (_user == null) return;
    if (_explanationCount > 0) {
      _explanationCount--;
      notifyListeners();
      try {
        await _firestore.collection('users').doc(_user!.uid).update({
          'explanationCount': _explanationCount,
        });
      } catch (e) {
        safePrint('Error: $e');
      }
    }
  }

  Future<void> rewardDecisionCredit() async {
    _decisionCredits++;
    await SharedPrefs.setInt('DECISION_CREDITS', _decisionCredits);
    notifyListeners();
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
        
        await ensureFirestoreUserExists(user);
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

  Future<void> loginWithApple(BuildContext context) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = await _authService.signInWithApple();
      if (user != null) {
        _user = user;
        
        await ensureFirestoreUserExists(user);
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

      // Decrement the authenticated_users_count in settings
      try {
        await _firestore.collection('app_config').doc('settings').set({
          'authenticated_users_count': FieldValue.increment(-1),
        }, SetOptions(merge: true));
        safePrint('📉 Automatically decremented authenticated_users_count in settings');
      } catch (e) {
        safePrint('⚠️ Failed to decrement authenticated_users_count: $e');
      }

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
