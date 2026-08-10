import 'package:mindpilot/export.dart';

enum EngagementAction {
  focusComplete,
  journalEntry,
  decisionAnalyzed,
  chatMessage,
  taskCompleted,
  insightExplained,
  bibleQuizComplete,
  bibleChapterRead,
  meetingRated,
}

class EngagementService {
  static final EngagementService _instance = EngagementService._internal();
  factory EngagementService() => _instance;
  EngagementService._internal();

  static const int xpPerLevel = 50;

  static const Map<EngagementAction, int> _xpRewards = {
    EngagementAction.focusComplete: 15,
    EngagementAction.journalEntry: 10,
    EngagementAction.decisionAnalyzed: 20,
    EngagementAction.chatMessage: 5,
    EngagementAction.taskCompleted: 8,
    EngagementAction.insightExplained: 5,
    EngagementAction.bibleQuizComplete: 20,
    EngagementAction.bibleChapterRead: 10,
    EngagementAction.meetingRated: 10,
  };

  static const Set<EngagementAction> _streakActions = {
    EngagementAction.focusComplete,
    EngagementAction.journalEntry,
    EngagementAction.decisionAnalyzed,
    EngagementAction.bibleQuizComplete,
    EngagementAction.bibleChapterRead,
  };

  int levelFromXp(int xp) => 1 + (xp ~/ xpPerLevel);

  int xpProgressInLevel(int xp) => xp % xpPerLevel;

  int xpToNextLevel(int xp) => xpPerLevel - xpProgressInLevel(xp);

  String generateReferralCode(String uid) {
    final segment = uid.length >= 6 ? uid.substring(0, 6) : uid;
    return 'MP${segment.toUpperCase()}';
  }

  Future<void> ensureReferralCode(User user) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && (doc.data()?['referralCode'] as String?)?.isNotEmpty == true) {
        return;
      }
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'referralCode': generateReferralCode(user.uid),
        'referralCount': doc.data()?['referralCount'] ?? 0,
      }, SetOptions(merge: true));
    } catch (e) {
      safePrint('Error ensuring referral code: $e');
    }
  }

  Future<Map<String, dynamic>> loadEngagementData() async {
    final streak = await SharedPrefs.getInt('STREAK_COUNT') ?? 0;
    final lastEngagement =
        await SharedPrefs.getString('LAST_ENGAGEMENT_DATE');
    final xp = await SharedPrefs.getInt('USER_XP') ?? 0;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          final remoteStreak = data['streak'] as int? ?? streak;
          final remoteXp = data['xp'] as int? ?? xp;
          final remoteLast =
              data['lastEngagementDate'] as String? ?? lastEngagement;

          await SharedPrefs.setInt('STREAK_COUNT', remoteStreak);
          await SharedPrefs.setInt('USER_XP', remoteXp);
          if (remoteLast.isNotEmpty) {
            await SharedPrefs.setString('LAST_ENGAGEMENT_DATE', remoteLast);
          }

          return {
            'streak': remoteStreak,
            'xp': remoteXp,
            'level': levelFromXp(remoteXp),
            'lastEngagementDate': remoteLast,
            'hasCompletedFirstSession':
                data['hasCompletedFirstSession'] ?? false,
            'referralCode': data['referralCode'],
            'referralCount': data['referralCount'] ?? 0,
            'referredBy': data['referredBy'],
            'personalization':
                List<String>.from(data['personalization'] ?? []),
          };
        }
      } catch (e) {
        safePrint('Error loading engagement from Firestore: $e');
      }
    }

    return {
      'streak': streak,
      'xp': xp,
      'level': levelFromXp(xp),
      'lastEngagementDate': lastEngagement,
      'hasCompletedFirstSession': false,
      'referralCode': null,
      'referralCount': 0,
      'referredBy': null,
      'personalization': <String>[],
    };
  }

  Future<void> recordLastAppOpen() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'lastAppOpen': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      safePrint('Error recording last app open: $e');
    }
  }

  /// Records the last screen the user visited so admins can see
  /// their most recent in-app location alongside [lastActive].
  Future<void> recordScreenVisit(String screenName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'lastVisitedScreen': screenName,
        'lastVisitedScreenAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      safePrint('Error recording screen visit: $e');
    }
  }

  Future<({int streak, int xp, int level, bool leveledUp})> recordAction(
    EngagementAction action, {
    int bonusAmount = 0,
  }) async {
    final xpGain = (_xpRewards[action] ?? 5) + bonusAmount;
    var xp = (await SharedPrefs.getInt('USER_XP') ?? 0) + xpGain;
    var streak = await SharedPrefs.getInt('STREAK_COUNT') ?? 0;
    final previousLevel = levelFromXp(xp - xpGain);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastEngagement =
        await SharedPrefs.getString('LAST_ENGAGEMENT_DATE');
    var streakUpdated = false;

    if (_streakActions.contains(action) && lastEngagement != today) {
      if (lastEngagement.isEmpty) {
        streak = 1;
      } else {
        final lastDate = DateTime.tryParse(lastEngagement);
        if (lastDate != null) {
          final diff = DateTime.parse(today).difference(lastDate).inDays;
          if (diff == 1) {
            streak += 1;
          } else if (diff > 1) {
            streak = 1;
          }
        } else {
          streak = 1;
        }
      }
      await SharedPrefs.setString('LAST_ENGAGEMENT_DATE', today);
      streakUpdated = true;
      await AnalyticsService.logStreakDay(streak);
    }

    await SharedPrefs.setInt('USER_XP', xp);
    if (streakUpdated) {
      await SharedPrefs.setInt('STREAK_COUNT', streak);
    }

    final level = levelFromXp(xp);
    final leveledUp = level > previousLevel;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final updates = <String, dynamic>{
          'xp': xp,
          'level': level,
          'lastActive': FieldValue.serverTimestamp(),
        };
        if (streakUpdated) {
          updates['streak'] = streak;
          updates['lastEngagementDate'] = today;
        }
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(updates, SetOptions(merge: true));
      } catch (e) {
        safePrint('Error syncing engagement to Firestore: $e');
      }
    }

    await AnalyticsService.logEngagementAction(
      action.name,
      xpGain: xpGain,
      streak: streak,
      level: level,
    );

    if (leveledUp) {
      await AnalyticsService.logLevelUp(level);
    }

    _notifyProviders(streak: streak, xp: xp, level: level);
    await scheduleStreakAtRiskReminder(streak);

    return (streak: streak, xp: xp, level: level, leveledUp: leveledUp);
  }

  Future<void> markFirstSessionComplete(String sessionType) async {
    await SharedPrefs.setBool('HAS_COMPLETED_FIRST_SESSION', true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'hasCompletedFirstSession': true,
          'firstSessionType': sessionType,
        }, SetOptions(merge: true));
      } catch (e) {
        safePrint('Error marking first session: $e');
      }
    }
    await AnalyticsService.logFirstSessionComplete(sessionType);
  }

  Future<bool> hasCompletedFirstSession() async {
    if (await SharedPrefs.getBool('HAS_COMPLETED_FIRST_SESSION') == true) {
      return true;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      return doc.data()?['hasCompletedFirstSession'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> applyReferralCode(String code) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || code.trim().isEmpty) return;

    final normalized = code.trim().toUpperCase();
    final myCode = generateReferralCode(user.uid);
    if (normalized == myCode) return;

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('referralCode', isEqualTo: normalized)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw Exception('Invalid referral code');
      }

      final referrerDoc = query.docs.first;
      if (referrerDoc.id == user.uid) return;

      final myDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (myDoc.data()?['referredBy'] != null) {
        throw Exception('Referral already applied');
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'referredBy': normalized,
        'referredAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(referrerDoc.id)
          .set({
        'referralCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      await rewardReferral(user.uid, referrerDoc.id);
      await AnalyticsService.logReferralApplied(normalized);
    } catch (e) {
      safePrint('Referral error: $e');
      rethrow;
    }
  }

  Future<void> rewardReferral(String refereeId, String referrerId) async {
    const bonusCredits = 1;
    try {
      final referrerRef =
          FirebaseFirestore.instance.collection('users').doc(referrerId);
      final refereeRef =
          FirebaseFirestore.instance.collection('users').doc(refereeId);

      // Fetch referrer's current premiumExpiresAt to add 3 days onto it
      final referrerDoc = await referrerRef.get();
      final currentPremiumExpires = referrerDoc.data()?['premiumExpiresAt'] as Timestamp?;
      DateTime newExpiry = DateTime.now().add(const Duration(days: 3));
      if (currentPremiumExpires != null) {
        final currentExpiryDateTime = currentPremiumExpires.toDate();
        if (currentExpiryDateTime.isAfter(DateTime.now())) {
          newExpiry = currentExpiryDateTime.add(const Duration(days: 3));
        }
      }

      await referrerRef.set({
        'bonusDecisionCredits': FieldValue.increment(bonusCredits),
        'premiumExpiresAt': Timestamp.fromDate(newExpiry),
      }, SetOptions(merge: true));

      await refereeRef.set({
        'bonusDecisionCredits': FieldValue.increment(bonusCredits),
      }, SetOptions(merge: true));
    } catch (e) {
      safePrint('Referral reward error: $e');
    }
  }

  Future<void> scheduleStreakAtRiskReminder(int currentStreak) async {
    if (currentStreak <= 0) {
      await NotificationService().cancelStreakAtRiskReminder();
      return;
    }

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastEngagement =
        await SharedPrefs.getString('LAST_ENGAGEMENT_DATE');

    if (lastEngagement == today) {
      await NotificationService().cancelStreakAtRiskReminder();
      return;
    }

    await NotificationService().scheduleStreakAtRiskReminder(currentStreak);
  }

  List<String> orderedQuickActions(List<String> personalization) {
    const defaultOrder = [
      'Expand My Knowledge',
      'Sharpen My Mind',
      'Make Better Decisions',
    ];

    if (personalization.isEmpty) {
      return defaultOrder;
    }

    final ordered = <String>[];
    for (final goal in personalization) {
      if (!ordered.contains(goal)) ordered.add(goal);
    }
    for (final goal in defaultOrder) {
      if (!ordered.contains(goal)) ordered.add(goal);
    }
    return ordered;
  }

  String primaryGoalAction(List<String> personalization) {
    if (personalization.isEmpty) return 'focus';
    final primary = personalization.first;
    if (primary.contains('Knowledge') || primary.contains('Spiritual')) return 'bible_quiz';
    if (primary.contains('Sharpen') || primary.contains('Habits')) return 'focus';
    if (primary.contains('Decision')) return 'decision';
    if (primary.contains('Growth') || primary.contains('Track')) return 'journal';
    return 'focus';
  }

  void _notifyProviders({required int streak, required int xp, required int level}) {
    final context = R.N.navKey.currentContext;
    if (context == null || !context.mounted) return;
    try {
      context.read<AppProvider>().applyEngagementSync(streak: streak);
      context.read<AppAuthProvider>().applyEngagementSync(xp: xp, level: level);
    } catch (_) {}
  }
}
