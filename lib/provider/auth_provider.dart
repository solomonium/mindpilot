import 'dart:async';
import 'dart:ui' as ui;
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

  Timestamp? _premiumExpiresAt;
  Timestamp? get premiumExpiresAt => _premiumExpiresAt;

  bool get isPro {
    if (_userType == "Pro Member") return true;
    if (_premiumExpiresAt != null) {
      final now = DateTime.now();
      final expiry = _premiumExpiresAt!.toDate();
      if (expiry.isAfter(now)) return true;
    }
    return false;
  }

  String _aiTone = "Balanced";
  String get aiTone => _aiTone;

  String _aiPersonality = "Encouraging";
  String get aiPersonality => _aiPersonality;

  String _selectedLlmProvider = "Direct Gemini";
  String get selectedLlmProvider => _selectedLlmProvider;

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

  int _xp = 0;
  int get xp => _xp;

  int _level = 1;
  int get level => _level;

  List<String> _personalization = [];
  List<String> get personalization => _personalization;

  String? _referralCode;
  String? get referralCode => _referralCode;

  int _referralCount = 0;
  int get referralCount => _referralCount;

  String? _referredBy;
  String? get referredBy => _referredBy;

  bool _hasCompletedFirstSession = false;
  bool get hasCompletedFirstSession => _hasCompletedFirstSession;

  int _insightIntervalHours = 3;
  int get insightIntervalHours => _insightIntervalHours;

  final List<String> _superAdmins = [
    'laleyesolomon2@gmail.com',
    'solteqinnovationsltd@gmail.com',
  ];

  StreamSubscription? _userDocSubscription;

  AppAuthProvider() {
    _initAuth();
  }

  Future<void> _checkAppVersionAndForceLogout() async {
    try {
      final currentVersion = ConfigService().currentAppVersion;
      final lastStoredVersion = await SharedPrefs.getString(
        'LAST_INSTALLED_APP_VERSION',
      );

      if (lastStoredVersion != currentVersion) {
        if (FirebaseAuth.instance.currentUser != null) {
          await FirebaseAuth.instance.signOut();
          safePrint(
            '🔄 New app version detected (stored: "$lastStoredVersion", current: "$currentVersion"). Forced logout for data migration.',
          );
        }
        await SharedPrefs.setString(
          'LAST_INSTALLED_APP_VERSION',
          currentVersion,
        );
      }
    } catch (e) {
      safePrint('⚠️ Error checking app version for force logout: $e');
    }
  }

  Future<void> _initAuth() async {
    await _checkAppVersionAndForceLogout();

    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      _user = user;
      if (user != null) {
        _displayName = user.displayName;
        _email = user.email;
        ensureFirestoreUserExists(user).then((_) {
          _listenToUserType(user);
          _checkAdminStatus(user);
          PaymentService.syncSubscriptionStatus();
          EngagementService().ensureReferralCode(user);
        });
        final displayName =
            (user.displayName != null && user.displayName!.isNotEmpty)
            ? user.displayName
            : AuthService.lastAppleFullName;
        final name = displayName?.getFirstName();
        GeminiService().setUserName(name);

        // Sync FCM Token immediately on login/startup
        NotificationService().logDeviceToken();

        // Idempotently restart broadcasts subscription on login
        final context = R.N.navKey.currentContext;
        if (context != null) {
          try {
            context.read<NotificationProvider>().listenToBroadcasts();
          } catch (_) {}
        }
      } else {
        _userDocSubscription?.cancel();
        _userType = "Freemium";
        _isAdmin = false;
        _aiTone = "Balanced";
        _aiPersonality = "Encouraging";
        _selectedLlmProvider = "Direct Gemini";
        _displayName = null;
        _email = null;
        GeminiService().setIsPro(false);
        GeminiService().setUserName(null);
        GeminiService().setAiPreferences("Balanced", "Encouraging");
        GeminiService().setLlmProvider("Direct Gemini");

        // Cancel broadcasts subscription on sign-out before permissions are lost
        final context = R.N.navKey.currentContext;
        if (context != null) {
          try {
            context.read<NotificationProvider>().cancelBroadcastsSubscription();
          } catch (_) {}
        }
      }
      notifyListeners();
    });
  }

  String _detectCountry() {
    try {
      final String code =
          ui.PlatformDispatcher.instance.locale.countryCode?.toUpperCase() ??
          '';
      switch (code) {
        case 'UG':
          return 'Uganda';
        case 'KE':
          return 'Kenya';
        case 'NG':
          return 'Nigeria';
        case 'GH':
          return 'Ghana';
        case 'ZA':
          return 'South Africa';
        case 'US':
          return 'United States';
        case 'GB':
          return 'United Kingdom';
        case 'CA':
          return 'Canada';
        case 'AU':
          return 'Australia';
        case 'DE':
          return 'Germany';
        case 'FR':
          return 'France';
        default:
          return code.isNotEmpty ? code : 'Unknown';
      }
    } catch (_) {
      return 'Unknown';
    }
  }

  Future<void> ensureFirestoreUserExists(User user, {String? heardFrom}) async {
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();

      String fallbackName =
          (user.displayName != null && user.displayName!.isNotEmpty)
          ? user.displayName!
          : (AuthService.lastAppleFullName ?? 'MindPilot User');

      if (fallbackName.trim().isEmpty) {
        if (user.email != null && user.email!.isNotEmpty) {
          fallbackName = user.email!.split('@').first;
        } else {
          fallbackName = 'MindPilot User';
        }
      }

      if (!doc.exists) {
        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'name': fallbackName,
          'fullName': fallbackName,
          'displayName': fallbackName,
          'userType': 'Freemium',
          'personalization': [],
          'aiTone': 'Balanced',
          'aiPersonality': 'Encouraging',
          'selectedLlmProvider': 'Direct Gemini',
          'explanationCount': 0,
          'insightIntervalHours': 3,
          'streak': 0,
          'xp': 0,
          'level': 1,
          'referralCode':
              'MP${user.uid.substring(0, user.uid.length >= 6 ? 6 : user.uid.length).toUpperCase()}',
          'referralCount': 0,
          'hasCompletedFirstSession': false,
          'country': '',
          'regCountry': _detectCountry(),
          'heardFrom': heardFrom ?? 'Unknown',
          'totalTimeSpent': 0,
          'lastActive': FieldValue.serverTimestamp(),
          'lastAppOpen': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        safePrint(
          '🚀 Proactively created missing Firestore user document for UID: ${user.uid}',
        );

        try {
          await _firestore.collection('app_config').doc('settings').set({
            'authenticated_users_count': FieldValue.increment(1),
          }, SetOptions(merge: true));
          safePrint(
            '📈 Automatically incremented authenticated_users_count in settings',
          );
        } catch (e) {
          safePrint('⚠️ Failed to increment authenticated_users_count: $e');
        }
      } else {
        // Retroactively backfill missing profile fields or default fields
        final data = doc.data();
        if (data != null) {
          final Map<String, dynamic> updates = {};

          // 1. Backfill email if missing or empty
          final existingEmail = data['email'] as String? ?? '';
          if (existingEmail.isEmpty &&
              user.email != null &&
              user.email!.isNotEmpty) {
            updates['email'] = user.email;
          }

          // 2. Backfill name, fullName, displayName if missing or empty
          final existingName = data['name'] as String? ?? '';
          final existingFullName = data['fullName'] as String? ?? '';
          final existingDisplayName = data['displayName'] as String? ?? '';

          if (existingName.isEmpty) updates['name'] = fallbackName;
          if (existingFullName.isEmpty) updates['fullName'] = fallbackName;
          if (existingDisplayName.isEmpty)
            updates['displayName'] = fallbackName;

          // 3. Backfill registration date (createdAt) if missing
          bool isStub =
              !data.containsKey('createdAt') ||
              data['createdAt'] == null ||
              !data.containsKey('userType');
          if (!data.containsKey('createdAt') || data['createdAt'] == null) {
            final creationTime = user.metadata.creationTime;
            if (creationTime != null) {
              updates['createdAt'] = Timestamp.fromDate(creationTime);
            } else {
              updates['createdAt'] = FieldValue.serverTimestamp();
            }
          }

          // 4. Backfill regCountry if missing or empty
          if (!data.containsKey('regCountry') ||
              data['regCountry'] == null ||
              data['regCountry'].toString().isEmpty) {
            updates['regCountry'] = _detectCountry();
          }

          // Backfill country if missing or empty using phone number from firestore
          final currentCountry = data['country'] as String? ?? '';
          final existingPhone = data['phoneNumber'] as String? ?? '';
          if (currentCountry.trim().isEmpty && existingPhone.isNotEmpty) {
            String? derivedCountry;
            if (existingPhone.startsWith('+234')) derivedCountry = 'Nigeria';
            else if (existingPhone.startsWith('+256')) derivedCountry = 'Uganda';
            else if (existingPhone.startsWith('+254')) derivedCountry = 'Kenya';
            else if (existingPhone.startsWith('+233')) derivedCountry = 'Ghana';
            else if (existingPhone.startsWith('+27')) derivedCountry = 'South Africa';
            else if (existingPhone.startsWith('+1')) derivedCountry = 'United States';
            else if (existingPhone.startsWith('+44')) derivedCountry = 'United Kingdom';
            
            if (derivedCountry != null) {
              updates['country'] = derivedCountry;
            }
          }

          // 5. Backfill heardFrom if missing, null, empty or Unknown, and heardFrom param is provided
          final currentHeardFrom = data['heardFrom'] as String? ?? '';
          if (heardFrom != null &&
              (!data.containsKey('heardFrom') ||
                  data['heardFrom'] == null ||
                  currentHeardFrom.trim().isEmpty ||
                  currentHeardFrom == 'Unknown')) {
            updates['heardFrom'] = heardFrom;
          }

          // 6. Backfill other default fields if completely missing from the document
          if (!data.containsKey('userType')) updates['userType'] = 'Freemium';
          if (!data.containsKey('personalization'))
            updates['personalization'] = [];
          if (!data.containsKey('aiTone')) updates['aiTone'] = 'Balanced';
          if (!data.containsKey('aiPersonality'))
            updates['aiPersonality'] = 'Encouraging';
          if (!data.containsKey('explanationCount'))
            updates['explanationCount'] = 0;
          if (!data.containsKey('insightIntervalHours'))
            updates['insightIntervalHours'] = 3;
          if (!data.containsKey('streak')) updates['streak'] = 0;
          if (!data.containsKey('xp')) updates['xp'] = 0;
          if (!data.containsKey('level')) updates['level'] = 1;
          if (!data.containsKey('referralCode')) {
            updates['referralCode'] =
                'MP${user.uid.substring(0, user.uid.length >= 6 ? 6 : user.uid.length).toUpperCase()}';
          }
          if (!data.containsKey('referralCount')) updates['referralCount'] = 0;
          if (!data.containsKey('hasCompletedFirstSession'))
            updates['hasCompletedFirstSession'] = false;
          if (!data.containsKey('country')) updates['country'] = '';

          if (updates.isNotEmpty) {
            await _firestore.collection('users').doc(user.uid).update(updates);
            safePrint(
              '🌍 Retroactively updated user document: ${user.uid} with $updates',
            );
          }

          if (isStub) {
            try {
              await _firestore.collection('app_config').doc('settings').set({
                'authenticated_users_count': FieldValue.increment(1),
              }, SetOptions(merge: true));
              safePrint(
                '📈 Automatically incremented authenticated_users_count in settings for stub conversion',
              );
            } catch (e) {
              safePrint('⚠️ Failed to increment count for stub conversion: $e');
            }
          }
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
      GeminiService().setIsPro(true);
      notifyListeners();
      return;
    }

    _userDocSubscription = _firestore.collection('users').doc(user.uid).snapshots().listen((
      doc,
    ) {
      if (doc.exists) {
        _userType = doc.data()?['userType'] ?? "Freemium";
        _premiumExpiresAt = doc.data()?['premiumExpiresAt'] as Timestamp?;
        GeminiService().setIsPro(isPro);
        _explanationCount = doc.data()?['explanationCount'] ?? 0;
        _aiTone = doc.data()?['aiTone'] ?? "Balanced";
        _aiPersonality = doc.data()?['aiPersonality'] ?? "Encouraging";
        _selectedLlmProvider = doc.data()?['selectedLlmProvider'] ?? "Direct Gemini";
        _phoneNumber = doc.data()?['phoneNumber'];
        _location = doc.data()?['location'];
        _country = doc.data()?['country'];
        final loadedHours = doc.data()?['insightIntervalHours'] ?? 3;
        _insightIntervalHours = (loadedHours == 0) ? 0 : 3;
        _xp = doc.data()?['xp'] ?? 0;
        _level = doc.data()?['level'] ?? EngagementService().levelFromXp(_xp);
        _referralCode = doc.data()?['referralCode'];
        _referralCount = doc.data()?['referralCount'] ?? 0;
        _referredBy = doc.data()?['referredBy'];
        _hasCompletedFirstSession =
            doc.data()?['hasCompletedFirstSession'] ?? false;

        SharedPrefs.setInt('USER_XP', _xp);
        SharedPrefs.setInt('STREAK_COUNT', doc.data()?['streak'] ?? 0);
        final lastEng = doc.data()?['lastEngagementDate'] as String? ?? '';
        if (lastEng.isNotEmpty) {
          SharedPrefs.setString('LAST_ENGAGEMENT_DATE', lastEng);
        }

        final personalization = List<String>.from(
          doc.data()?['personalization'] ?? [],
        );
        _personalization = personalization;
        GeminiService().setPersonalization(personalization);
        GeminiService().setAiPreferences(_aiTone, _aiPersonality);
        GeminiService().setLlmProvider(_selectedLlmProvider);

        final docDisplayName =
            doc.data()?['displayName'] ??
            doc.data()?['name'] ??
            doc.data()?['fullName'];
        if (docDisplayName != null && docDisplayName.toString().isNotEmpty) {
          _displayName = docDisplayName.toString();
          final name = _displayName?.getFirstName();
          GeminiService().setUserName(name);
        }
        final docEmail = doc.data()?['email'];
        if (docEmail != null && docEmail.toString().isNotEmpty) {
          _email = docEmail.toString();
        }

        final navContext = R.N.navKey.currentContext;
        if (navContext != null && navContext.mounted) {
          try {
            navContext.read<AppProvider>().applyEngagementSync(
              streak: doc.data()?['streak'] ?? 0,
            );
          } catch (_) {}
        }

        _syncTempPersonalization(user.uid);

        // Retroactive name sync for Apple users whose name fields are currently empty
        final currentName = doc.data()?['name'] ?? '';
        final currentDisplayName = doc.data()?['displayName'] ?? '';
        final currentFullName = doc.data()?['fullName'] ?? '';

        if ((currentName.isEmpty ||
                currentDisplayName.isEmpty ||
                currentFullName.isEmpty) &&
            AuthService.lastAppleFullName != null &&
            AuthService.lastAppleFullName!.isNotEmpty) {
          _firestore
              .collection('users')
              .doc(user.uid)
              .update({
                'name': AuthService.lastAppleFullName,
                'fullName': AuthService.lastAppleFullName,
                'displayName': AuthService.lastAppleFullName,
              })
              .then((_) {
                safePrint(
                  'Successfully retroactively updated Apple user name to: ${AuthService.lastAppleFullName}',
                );
                AuthService.lastAppleFullName = null; // Consume the cached name
              })
              .catchError((e) {
                safePrint('Error retroactively updating Apple name: $e');
              });
        }
      } else {
        final fallbackName =
            (user.displayName != null && user.displayName!.isNotEmpty)
            ? user.displayName!
            : (AuthService.lastAppleFullName ?? '');

        _firestore
            .collection('users')
            .doc(user.uid)
            .set({
              'email': user.email,
              'name': fallbackName,
              'fullName': fallbackName,
              'displayName': fallbackName,
              'userType': 'Freemium',
              'personalization': [],
              'aiTone': 'Balanced',
              'aiPersonality': 'Encouraging',
              'explanationCount': 0,
              'insightIntervalHours': 3,
              'streak': 0,
              'xp': 0,
              'level': 1,
              'referralCode':
                  'MP${user.uid.substring(0, user.uid.length >= 6 ? 6 : user.uid.length).toUpperCase()}',
              'referralCount': 0,
              'hasCompletedFirstSession': false,
              'country': '',
              'regCountry': _detectCountry(),
              'createdAt': FieldValue.serverTimestamp(),
            })
            .then((_) {
              _syncTempPersonalization(user.uid);
              AuthService.lastAppleFullName = null; // Consume the cached name

              _firestore
                  .collection('app_config')
                  .doc('settings')
                  .set({
                    'authenticated_users_count': FieldValue.increment(1),
                  }, SetOptions(merge: true))
                  .catchError((e) {
                    safePrint('⚠️ Failed to increment count: $e');
                  });
            });
        _displayName = fallbackName;
        _email = user.email;
        _userType = "Freemium";
      }
      notifyListeners();
      _checkAndResetDecisionCredits();
      _checkAndResetExplanationCount();
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

  Future<void> _checkAndResetExplanationCount() async {
    if (_user == null) return;
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final lastReset = await SharedPrefs.getString(
      'LAST_EXPLANATION_RESET_DATE',
    );

    if (lastReset != today) {
      _explanationCount = 0;
      await SharedPrefs.setString('LAST_EXPLANATION_RESET_DATE', today);
      try {
        await _firestore.collection('users').doc(_user!.uid).update({
          'explanationCount': 0,
        });
      } catch (e) {
        safePrint('Error resetting daily explanationCount in Firestore: $e');
      }
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

  Future<void> updateUserProfile({
    String? displayName,
    String? phoneNumber,
    String? location,
    String? country,
  }) async {
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

  Future<void> updateAiPreferences(String tone, String personality, String provider) async {
    if (_user == null) return;
    _aiTone = tone;
    _aiPersonality = personality;
    _selectedLlmProvider = provider;
    notifyListeners();

    try {
      await _firestore.collection('users').doc(_user!.uid).update({
        'aiTone': tone,
        'aiPersonality': personality,
        'selectedLlmProvider': provider,
      });
      GeminiService().setAiPreferences(tone, personality);
      GeminiService().setLlmProvider(provider);
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

  void applyEngagementSync({required int xp, required int level}) {
    _xp = xp;
    _level = level;
    notifyListeners();
  }

  Future<void> refreshReferralData() async {
    if (_user == null) return;
    try {
      final doc = await _firestore.collection('users').doc(_user!.uid).get();
      if (doc.exists) {
        _referralCode = doc.data()?['referralCode'];
        _referralCount = doc.data()?['referralCount'] ?? 0;
        _referredBy = doc.data()?['referredBy'];
        notifyListeners();
      }
    } catch (e) {
      safePrint('Error refreshing referral data: $e');
    }
  }

  void markFirstSessionComplete() {
    _hasCompletedFirstSession = true;
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

  Future<void> loginWithGoogle(
    BuildContext context, {
    String? heardFrom,
  }) async {
    bool hasNet = await AppHelper.isOnline();
    if (!hasNet) {
      if (context.mounted) {
        NoInternetDialog.show(context, onRetry: () async {
          loginWithGoogle(context, heardFrom: heardFrom);
        });
      }
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        _user = user;

        await ensureFirestoreUserExists(user, heardFrom: heardFrom);
        final doc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(
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
        if (context.mounted) context.showInAppNotification('Sign-In failed');
      }
    } catch (e) {
      if (context.mounted) context.showInAppNotification('Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loginWithApple(BuildContext context, {String? heardFrom}) async {
    bool hasNet = await AppHelper.isOnline();
    if (!hasNet) {
      if (context.mounted) {
        NoInternetDialog.show(context, onRetry: () async {
          loginWithApple(context, heardFrom: heardFrom);
        });
      }
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final user = await _authService.signInWithApple();
      if (user != null) {
        _user = user;

        await ensureFirestoreUserExists(user, heardFrom: heardFrom);
        final doc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(
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
        if (context.mounted) context.showInAppNotification('Sign-In failed');
      }
    } catch (e) {
      if (context.mounted) context.showInAppNotification('Error: $e');
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
    try {
      final context = R.N.navKey.currentContext;
      if (context != null && context.mounted) {
        Provider.of<AppProvider>(context, listen: false).accumulateTimeSpent();
      }
    } catch (e) {
      safePrint('Error during logout time accumulation: $e');
    }
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
        safePrint(
          '📉 Automatically decremented authenticated_users_count in settings',
        );
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
          context.showInAppNotification(
            e.message ?? 'Failed to delete account.',
          );
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
