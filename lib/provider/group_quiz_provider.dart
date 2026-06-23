import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:mindpilot/export.dart';

class GroupQuizProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GeminiService _geminiService = GeminiService();
  final AudioPlayer _lobbyAudioPlayer = AudioPlayer();

  GroupQuizProvider() {
    _initAudioContext();
    tryRestoreSession();
  }

  void _initAudioContext() {
    try {
      _lobbyAudioPlayer.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.gainTransient,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.mixWithOthers,
              AVAudioSessionOptions.defaultToSpeaker,
            },
          ),
        ),
      );
    } catch (e) {
      safePrint("Error initializing lobby audio context: $e");
    }
  }

  String? _restoredGroupId;
  String? get restoredGroupId => _restoredGroupId;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _activeGenerationToken;

  // Active group & game states
  String? _activeGroupId;
  String? get activeGroupId => _activeGroupId;

  Map<String, dynamic>? _groupData;
  Map<String, dynamic>? get groupData => _groupData;

  Map<String, dynamic>? _gameData;
  Map<String, dynamic>? get gameData => _gameData;

  StreamSubscription? _groupSubscription;
  StreamSubscription? _gameSubscription;

  // Local state for lobby setup
  int _questionsPerParticipant = 3;
  int get questionsPerParticipant => _questionsPerParticipant;
  set questionsPerParticipant(int val) {
    if (_questionsPerParticipant != val) {
      _questionsPerParticipant = val;
      notifyListeners();
      _updateSettingsInFirestore();
    }
  }

  int get questionCount => _questionsPerParticipant * acceptedMembersCount;

  int get acceptedMembersCount {
    if (_groupData == null) return 1;
    final membersMap = _groupData!['members'] as Map<String, dynamic>?;
    if (membersMap == null) return 1;
    int count = 0;
    membersMap.forEach((uid, val) {
      if (val['status'] == 'accepted') {
        count++;
      }
    });
    return count > 0 ? count : 1;
  }

  List<Map<String, String>> _emailSuggestions = [];
  List<Map<String, String>> get emailSuggestions => _emailSuggestions;

  int _timerSeconds = 30;
  int get timerSeconds => _timerSeconds;
  set timerSeconds(int val) {
    if (_timerSeconds != val) {
      _timerSeconds = val;
      notifyListeners();
      _updateSettingsInFirestore();
    }
  }

  String _scopeType = 'general'; // 'chapter' or 'general'
  String get scopeType => _scopeType;
  set scopeType(String val) {
    if (_scopeType != val) {
      _scopeType = val;
      notifyListeners();
      _updateSettingsInFirestore();
    }
  }

  String _scopeValue = 'Genesis 1';
  String get scopeValue => _scopeValue;
  set scopeValue(String val) {
    if (_scopeValue != val) {
      _scopeValue = val;
      notifyListeners();
      _updateSettingsInFirestore();
    }
  }

  Future<void> _updateSettingsInFirestore() async {
    final groupId = _activeGroupId;
    if (groupId == null || _groupData == null) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _groupData!['createdBy'] != currentUser.uid) return;

    try {
      await _firestore.collection('groups').doc(groupId).update({
        'settings': {
          'questionsPerParticipant': _questionsPerParticipant,
          'timerSeconds': _timerSeconds,
          'scopeType': _scopeType,
          'scopeValue': _scopeValue,
        }
      });
    } catch (e) {
      safePrint("Error updating group settings in Firestore: $e");
    }
  }

  // Active game local timer details
  int _secondsRemaining = 0;
  int get secondsRemaining => _secondsRemaining;
  Timer? _gameTimer;

  void setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void cancelGameGeneration() {
    _activeGenerationToken = null;
    _isLoading = false;
    notifyListeners();
    if (_activeGroupId != null) {
      _firestore.collection('groups').doc(_activeGroupId).update({
        'isGeneratingGame': false,
      }).catchError((e) => safePrint("Error resetting generating status: $e"));
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 1. Group & Invitation Management
  // ───────────────────────────────────────────────────────────────────────────

  /// Create a new group lobby
  Future<String?> createGroup(String groupName) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;

    setLoading(true);
    try {
      final docRef = await _firestore.collection('groups').add({
        'name': groupName,
        'createdBy': currentUser.uid,
        'creatorEmail': currentUser.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'activeGameId': null,
        'isGeneratingGame': false,
        'settings': {
          'questionsPerParticipant': _questionsPerParticipant,
          'timerSeconds': _timerSeconds,
          'scopeType': _scopeType,
          'scopeValue': _scopeValue,
        },
        'members': {
          currentUser.uid: {
            'email': currentUser.email ?? '',
            'displayName': currentUser.displayName ?? currentUser.email ?? 'Creator',
            'status': 'accepted',
            'role': 'creator',
            'joinedAt': DateTime.now().toIso8601String(),
          }
        }
      });
      await _saveSession(docRef.id);
      setLoading(false);
      return docRef.id;
    } catch (e) {
      safePrint("Error creating group: $e");
      setLoading(false);
      return null;
    }
  }

  /// Query a user by email and send a push notification invitation
  Future<String?> inviteUserByEmail(String groupId, String groupName, String email) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return "You must be signed in.";

    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail == currentUser.email?.toLowerCase()) {
      return "You cannot invite yourself.";
    }

    setLoading(true);
    try {
      // Find recipient by email in the users collection
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setLoading(false);
        return "User with email '$email' not found. Please verify they have registered in the app.";
      }

      final recipientDoc = query.docs.first;
      final recipientUid = recipientDoc.id;
      final recipientData = recipientDoc.data();
      final recipientName = recipientData['displayName'] ?? recipientData['name'] ?? cleanEmail;

      // Update Group members to include this user as pending
      await _firestore.collection('groups').doc(groupId).update({
        'members.$recipientUid': {
          'email': cleanEmail,
          'displayName': recipientName,
          'status': 'pending',
          'role': 'member',
          'invitedAt': DateTime.now().toIso8601String(),
        }
      });

      // Add invitation document which triggers Cloud Function for FCM Notification
      await _firestore.collection('group_invitations').add({
        'groupId': groupId,
        'groupName': groupName,
        'senderUid': currentUser.uid,
        'senderEmail': currentUser.email ?? '',
        'senderName': currentUser.displayName ?? currentUser.email ?? 'A user',
        'recipientEmail': cleanEmail,
        'recipientUid': recipientUid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      setLoading(false);
      return null; // Success
    } catch (e) {
      safePrint("Error inviting user: $e");
      setLoading(false);
      return "An error occurred: $e";
    }
  }

  Future<void> searchEmails(String prefix) async {
    final queryText = prefix.trim();
    if (queryText.length < 2) {
      _emailSuggestions = [];
      notifyListeners();
      return;
    }

    final queryTextLower = queryText.toLowerCase();
    String capitalized = queryText;
    if (queryText.isNotEmpty) {
      capitalized = queryText[0].toUpperCase() + queryText.substring(1);
    }

    try {
      final futures = [
        // 1. Email query (by lowercase email)
        _firestore
            .collection('users')
            .orderBy('email')
            .startAt([queryTextLower])
            .endAt(['$queryTextLower\uf8ff'])
            .limit(10)
            .get(),
        // 2. DisplayName query (exact / lowercase)
        _firestore
            .collection('users')
            .orderBy('displayName')
            .startAt([queryTextLower])
            .endAt(['$queryTextLower\uf8ff'])
            .limit(10)
            .get(),
        // 3. DisplayName query (capitalized)
        _firestore
            .collection('users')
            .orderBy('displayName')
            .startAt([capitalized])
            .endAt(['$capitalized\uf8ff'])
            .limit(10)
            .get(),
        // 4. Name query (exact / lowercase)
        _firestore
            .collection('users')
            .orderBy('name')
            .startAt([queryTextLower])
            .endAt(['$queryTextLower\uf8ff'])
            .limit(10)
            .get(),
        // 5. Name query (capitalized)
        _firestore
            .collection('users')
            .orderBy('name')
            .startAt([capitalized])
            .endAt(['$capitalized\uf8ff'])
            .limit(10)
            .get(),
      ];

      final results = await Future.wait(futures);
      final currentUserEmail = FirebaseAuth.instance.currentUser?.email?.toLowerCase();
      final currentUid = FirebaseAuth.instance.currentUser?.uid;

      // Use a Map keyed by doc ID to deduplicate users
      final Map<String, Map<String, String>> uniqueUsers = {};

      for (var querySnapshot in results) {
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          final uid = doc.id;
          if (uid == currentUid) continue;

          final email = (data['email'] as String? ?? '').trim();
          if (email.isEmpty || email.toLowerCase() == currentUserEmail) continue;

          final displayName = (data['displayName'] ?? data['name'] ?? email).toString().trim();

          uniqueUsers[uid] = {
            'email': email,
            'displayName': displayName,
          };
        }
      }

      // PopulateSuggestions
      _emailSuggestions = uniqueUsers.values.toList();
      notifyListeners();
    } catch (e) {
      safePrint("Error searching emails/names: $e");
    }
  }

  void clearSuggestions() {
    _emailSuggestions = [];
    notifyListeners();
  }

  /// Accept an invitation to join a group
  Future<void> acceptInvitation(String groupId, String invitationId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // First check if the group still exists
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) {
        // Group no longer exists (creator disbanded it). Clean up the invitation.
        await _firestore.collection('group_invitations').doc(invitationId).update({'status': 'expired'});
        safePrint("Group $groupId does not exist. Marked invitation as expired.");
        return;
      }

      final batch = _firestore.batch();

      // Update invitation doc status
      final inviteRef = _firestore.collection('group_invitations').doc(invitationId);
      batch.update(inviteRef, {'status': 'accepted'});

      // Update Group members status to accepted
      final groupRef = _firestore.collection('groups').doc(groupId);
      batch.update(groupRef, {
        'members.${currentUser.uid}.status': 'accepted',
        'members.${currentUser.uid}.joinedAt': DateTime.now().toIso8601String(),
      });

      await batch.commit();
      safePrint("Successfully accepted invitation to group: $groupId");
    } catch (e) {
      safePrint("Error accepting invitation: $e");
      // Fallback: if batch failed, try updating just the invitation status so user is not stuck
      try {
        await _firestore.collection('group_invitations').doc(invitationId).update({'status': 'rejected'});
      } catch (innerErr) {
        safePrint("Fallback error updating invitation: $innerErr");
      }
    }
  }

  /// Reject an invitation
  Future<void> rejectInvitation(String groupId, String invitationId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // First check if the group still exists
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) {
        // Group no longer exists. Clean up invitation.
        await _firestore.collection('group_invitations').doc(invitationId).update({'status': 'rejected'});
        safePrint("Group $groupId does not exist. Marked invitation as rejected.");
        return;
      }

      final batch = _firestore.batch();

      // Update invitation doc status
      final inviteRef = _firestore.collection('group_invitations').doc(invitationId);
      batch.update(inviteRef, {'status': 'rejected'});

      // Update Group members status to rejected
      final groupRef = _firestore.collection('groups').doc(groupId);
      batch.update(groupRef, {
        'members.${currentUser.uid}.status': 'rejected',
      });

      await batch.commit();
      safePrint("Rejected invitation: $invitationId");
    } catch (e) {
      safePrint("Error rejecting invitation: $e");
      // Fallback: if batch failed, try updating just the invitation status so user is not stuck
      try {
        await _firestore.collection('group_invitations').doc(invitationId).update({'status': 'rejected'});
      } catch (innerErr) {
        safePrint("Fallback error rejecting invitation: $innerErr");
      }
    }
  }

  /// Remove/Kick a member from the group (Creator only)
  Future<String?> removeMemberFromGroup(String groupId, String memberUid) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return "You must be signed in.";

    try {
      // 1. Update the Group's members map to delete this UID
      await _firestore.collection('groups').doc(groupId).update({
        'members.$memberUid': FieldValue.delete(),
      });

      // 2. Also delete any pending invitations for this recipient in this group
      final invitesQuery = await _firestore
          .collection('group_invitations')
          .where('groupId', isEqualTo: groupId)
          .where('recipientUid', isEqualTo: memberUid)
          .get();

      final batch = _firestore.batch();
      for (var doc in invitesQuery.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      safePrint("Successfully kicked member $memberUid from group $groupId");
      return null; // Success
    } catch (e) {
      safePrint("Error removing member: $e");
      return "An error occurred: $e";
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. Real-time Listeners
  // ───────────────────────────────────────────────────────────────────────────

  /// Listen to group updates
  void listenToGroup(String groupId) {
    _activeGroupId = groupId;
    _saveSession(groupId);
    _groupSubscription?.cancel();
    _groupSubscription = _firestore
        .collection('groups')
        .doc(groupId)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final oldData = _groupData;
        _groupData = doc.data();

        // Sync settings from Firestore
        final currentUser = FirebaseAuth.instance.currentUser;
        final creatorUid = _groupData?['createdBy'];
        if (currentUser != null && _groupData != null) {
          final settings = _groupData!['settings'] as Map<String, dynamic>?;
          if (settings != null) {
            // Non-creators always sync; creator only syncs once upon initial load to restore settings
            if (creatorUid != currentUser.uid || oldData == null) {
              _questionsPerParticipant = settings['questionsPerParticipant'] ?? 3;
              _timerSeconds = settings['timerSeconds'] ?? 30;
              _scopeType = settings['scopeType'] ?? 'general';
              _scopeValue = settings['scopeValue'] ?? 'Genesis 1';
            }
          }
        }

        if (oldData != null && _groupData != null) {
          _checkForNewJoins(oldData, _groupData!);
        }

        notifyListeners();

        // If an active game ID is set, start listening to it as well
        final activeGameId = _groupData?['activeGameId'] as String?;
        if (activeGameId != null && activeGameId.isNotEmpty) {
          listenToGame(activeGameId);
        } else {
          _gameSubscription?.cancel();
          _gameData = null;
          _stopTimer();
          notifyListeners();
        }
      } else {
        // Group was deleted/disbanded!
        _clearSession();
        _groupSubscription?.cancel();
        _gameSubscription?.cancel();
        _groupData = null;
        _gameData = null;
        _activeGroupId = null;
        _stopTimer();
        notifyListeners();
      }
    });
  }

  /// Listen to game updates
  void listenToGame(String gameId) {
    _gameSubscription?.cancel();
    _gameSubscription = _firestore
        .collection('games')
        .doc(gameId)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final oldIndex = _gameData?['currentQuestionIndex'];
        final oldTurn = _gameData?['currentTurnPlayerUid'];
        final oldStatus = _gameData?['status'];
        _gameData = doc.data();

        // Play sound and vibrate immediately in the background on game start
        final currentIdx = _gameData?['currentQuestionIndex'] as int? ?? 0;
        if (oldStatus != 'playing' && _gameData?['status'] == 'playing' && currentIdx == 0) {
          playQuizStartedSoundAndVibrate();
        }

        // Restart local timer if turn or question has advanced
        if (oldIndex != _gameData?['currentQuestionIndex'] ||
            oldTurn != _gameData?['currentTurnPlayerUid'] ||
            _gameTimer == null) {
          _syncLocalTimer();
        }

        notifyListeners();
      }
    });
  }

  /// Stop all active Firestore listeners
  void leaveGroup() {
    final currentUser = FirebaseAuth.instance.currentUser;
    final groupId = _activeGroupId;

    if (groupId != null && currentUser != null) {
      if (_groupData != null) {
        final isCreator = _groupData!['createdBy'] == currentUser.uid;
        final gameId = _groupData?['activeGameId'] as String?;
        if (isCreator) {
          _firestore.collection('groups').doc(groupId).delete().catchError((e) => safePrint("Error deleting group: $e"));

          if (gameId != null && gameId.isNotEmpty) {
            _firestore.collection('games').doc(gameId).delete().catchError((e) => safePrint("Error deleting active game: $e"));
          }

          _firestore
              .collection('group_invitations')
              .where('groupId', isEqualTo: groupId)
              .get()
              .then((snapshot) {
            final batch = _firestore.batch();
            for (var doc in snapshot.docs) {
              batch.delete(doc.reference);
            }
            batch.commit().catchError((e) => safePrint("Error deleting group invitations: $e"));
          }).catchError((e) => safePrint("Error fetching invitations for deletion: $e"));
        } else {
          _firestore.collection('groups').doc(groupId).update({
            'members.${currentUser.uid}': FieldValue.delete(),
          }).catchError((e) => safePrint("Error removing member from group: $e"));
        }
      } else {
        // Fallback: if _groupData is null, fetch the group doc to verify who is the creator
        _firestore.collection('groups').doc(groupId).get().then((doc) {
          if (doc.exists) {
            final data = doc.data();
            final isCreator = data?['createdBy'] == currentUser.uid;
            if (isCreator) {
              _firestore.collection('groups').doc(groupId).delete().catchError((e) => safePrint("Error deleting group: $e"));
              final gameId = data?['activeGameId'] as String?;
              if (gameId != null && gameId.isNotEmpty) {
                _firestore.collection('games').doc(gameId).delete().catchError((e) => safePrint("Error deleting active game: $e"));
              }
              _firestore
                  .collection('group_invitations')
                  .where('groupId', isEqualTo: groupId)
                  .get()
                  .then((snapshot) {
                final batch = _firestore.batch();
                for (var doc in snapshot.docs) {
                  batch.delete(doc.reference);
                }
                batch.commit().catchError((e) => safePrint("Error deleting group invitations: $e"));
              }).catchError((e) => safePrint("Error fetching invitations: $e"));
            } else {
              _firestore.collection('groups').doc(groupId).update({
                'members.${currentUser.uid}': FieldValue.delete(),
              }).catchError((e) => safePrint("Error removing member from group: $e"));
            }
          }
        }).catchError((e) => safePrint("Error fetching group on leaveGroup: $e"));
      }
    }

    _clearSession();
    _groupSubscription?.cancel();
    _gameSubscription?.cancel();
    _groupData = null;
    _gameData = null;
    _activeGroupId = null;
    _stopTimer();
    notifyListeners();
  }

  /// Delete or leave a specific restored group session
  Future<void> leaveRestoredGroup(String groupId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final doc = await _firestore.collection('groups').doc(groupId).get();
      if (doc.exists) {
        final data = doc.data();
        final isCreator = data?['createdBy'] == currentUser.uid;
        if (isCreator) {
          // Delete group
          await _firestore.collection('groups').doc(groupId).delete();
          // Delete active game if exists
          final gameId = data?['activeGameId'] as String?;
          if (gameId != null && gameId.isNotEmpty) {
            await _firestore.collection('games').doc(gameId).delete();
          }
          // Delete all invitations
          final invitesQuery = await _firestore
              .collection('group_invitations')
              .where('groupId', isEqualTo: groupId)
              .get();
          final batch = _firestore.batch();
          for (var doc in invitesQuery.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        } else {
          // Member leaves
          await _firestore.collection('groups').doc(groupId).update({
            'members.${currentUser.uid}': FieldValue.delete(),
          });
        }
      }
    } catch (e) {
      safePrint("Error leaving restored group: $e");
    } finally {
      _clearSession();
      notifyListeners();
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 3. Gameplay & AI Generation
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _setGeneratingGame(bool value) async {
    final groupId = _activeGroupId;
    if (groupId == null) return;
    try {
      await _firestore.collection('groups').doc(groupId).update({
        'isGeneratingGame': value,
      });
    } catch (e) {
      safePrint("Error updating isGeneratingGame to $value: $e");
    }
  }

  /// Start the quiz game (Creator only). Generates AI questions and sets activeGameId.
  Future<String?> startGame() async {
    if (_activeGroupId == null || _groupData == null) return "No group selected.";

    // Check that at least one other participant has accepted the invite
    final membersMap = _groupData!['members'] as Map<String, dynamic>? ?? {};
    final creatorUid = _groupData!['createdBy'];
    bool hasOtherAccepted = false;
    membersMap.forEach((uid, val) {
      if (uid != creatorUid && val['status'] == 'accepted') {
        hasOtherAccepted = true;
      }
    });

    if (!hasOtherAccepted) {
      return "At least one invited participant must accept the invitation before starting the game.";
    }

    final currentToken = DateTime.now().microsecondsSinceEpoch.toString();
    _activeGenerationToken = currentToken;

    setLoading(true);
    await _setGeneratingGame(true);

    try {
      // 0. Clean up any existing game document first
      final existingGameId = _groupData?['activeGameId'] as String?;
      if (existingGameId != null && existingGameId.isNotEmpty) {
        try {
          await _firestore.collection('games').doc(existingGameId).delete();
        } catch (e) {
          safePrint("Error deleting previous game: $e");
        }
      }

      if (_activeGenerationToken != currentToken) {
        await _setGeneratingGame(false);
        return "Generation cancelled.";
      }

      final List<dynamic> askedQuestions = _groupData?['askedQuestions'] as List<dynamic>? ?? [];

      // 1. Build prompt based on settings
      String prompt = "";
      String systemInstruction = "";

      if (_scopeType == 'chapter') {
        prompt = "You are a Bible trivia generator. Generate exactly $questionCount multiple-choice Bible quiz questions based strictly on the Bible chapter: '$_scopeValue'.\n"
            "CRITICAL: The questions must be 100% theological, historical, and biblical. They must only ask about the scripture text and details within the chapter '$_scopeValue'.\n"
            "Under no circumstances should you generate questions about the MindPilot app, technology, software, or other non-biblical topics.\n";
        systemInstruction = "You are a precise Bible quiz generator. You generate high-quality Bible trivia questions based strictly on the specified chapter. Under no circumstances do you generate questions about any other topic. Only facts from the specified chapter are allowed.";
      } else if (_scopeType == 'general') {
        prompt = "You are a Bible trivia generator. Generate exactly $questionCount general knowledge Bible quiz questions with multiple-choice options.\n"
            "CRITICAL: The questions must be 100% theological, historical, and biblical. They must only ask about the Holy Bible (Old and New Testaments).\n"
            "Under no circumstances should you generate questions about the MindPilot app, technology, software, or other non-biblical topics.\n";
        systemInstruction = "You are a precise Bible quiz generator. You generate high-quality Bible trivia questions. Under no circumstances do you generate questions about any other topic, including the MindPilot application or technology. Only biblical facts are allowed.";
      } else if (_scopeType == 'tech') {
        prompt = "You are an expert technology and computer science trivia generator. Generate exactly $questionCount multiple-choice questions about software engineering, programming languages, computer science, and digital technology.\n"
            "CRITICAL: Ensure the questions are highly educational, accurate, and completely free of inappropriate or offensive content.\n";
        systemInstruction = "You are a precise technology and coding quiz generator. You generate educational, accurate multiple-choice questions about tech and coding. Do not include any inappropriate, mature, or irrelevant content.";
      } else if (_scopeType == 'science') {
        prompt = "You are a science and physics trivia generator. Generate exactly $questionCount multiple-choice questions about physical sciences, key physics principles, chemistry, astronomy, and scientific breakthroughs.\n"
            "CRITICAL: Ensure the questions are highly educational, accurate, and completely free of inappropriate or offensive content.\n";
        systemInstruction = "You are a precise science quiz generator. You generate educational, accurate multiple-choice questions about science and physics. Do not include any inappropriate, mature, or irrelevant content.";
      } else if (_scopeType == 'english') {
        prompt = "You are an English language and literature trivia generator. Generate exactly $questionCount multiple-choice questions about grammar, vocabulary, classic literature, famous authors, and literary devices.\n"
            "CRITICAL: Ensure the questions are highly educational, accurate, and completely free of inappropriate or offensive content.\n";
        systemInstruction = "You are a precise English and literature quiz generator. You generate educational, accurate multiple-choice questions. Do not include any inappropriate, mature, or irrelevant content.";
      } else if (_scopeType == 'economics') {
        prompt = "You are an economics and finance trivia generator. Generate exactly $questionCount multiple-choice questions about microeconomics, macroeconomics, financial literacy, investment principles, and economic history.\n"
            "CRITICAL: Ensure the questions are highly educational, accurate, and completely free of inappropriate or offensive content.\n";
        systemInstruction = "You are a precise economics and finance quiz generator. You generate educational, accurate multiple-choice questions. Do not include any inappropriate, mature, or irrelevant content.";
      } else if (_scopeType == 'mindfulness') {
        prompt = "You are a personality development, emotional intelligence, and mindfulness trivia generator. Generate exactly $questionCount multiple-choice questions about mindfulness practices, self-improvement, emotional intelligence, relationship building, and positive psychology.\n"
            "CRITICAL: Ensure the questions are constructive, inspiring, and completely free of inappropriate or offensive content. Focus on building self-awareness and positive character traits.\n";
        systemInstruction = "You are a precise mindfulness and personality development quiz generator. You generate educational, constructive multiple-choice questions that help players build self-awareness and positive traits. Do not include any inappropriate, mature, or irrelevant content.";
      } else {
        prompt = "You are an expert trivia generator. Generate exactly $questionCount multiple-choice questions about the topic: '$_scopeValue'.\n"
            "CRITICAL: Ensure the questions are highly educational, accurate, and completely free of inappropriate or offensive content. Under no circumstances should you output any inappropriate, political, offensive, or adult topics.\n";
        systemInstruction = "You are a precise quiz generator. You generate educational, accurate multiple-choice questions about the specified topic: '$_scopeValue'. You must ensure there is absolutely no inappropriate, offensive, or mature content. Ensure the quiz remains clean and educational.";
      }

      if (askedQuestions.isNotEmpty) {
        prompt += "\nCRITICAL: Do NOT generate any of the following questions, as they have already been played in this group:\n";
        for (var qText in askedQuestions) {
          prompt += "- $qText\n";
        }
        prompt += "\n";
      }

      prompt += "Ensure the questions are balanced, informative, and engaging.\n"
          "You MUST format the output ONLY as a valid JSON array of objects. Do not wrap it in markdown block formatting like ```json ... ```, just return the raw JSON text.\n"
          "Each object in the array must look exactly like this:\n"
          "{\n"
          "  \"questionText\": \"What was the first thing God created?\",\n"
          "  \"options\": [\"Light\", \"Water\", \"Land\", \"Humans\"],\n"
          "  \"correctAnswerIndex\": 0\n"
          "}\n"
          "Ensure the array contains exactly $questionCount objects.\n"
          "CRITICAL ACCURACY REQUIREMENT:\n"
          "- You MUST double check the correctness of the generated correctAnswerIndex.\n"
          "- The correctAnswerIndex MUST correspond exactly to the index (0 to 3) of the correct answer in the options array.\n"
          "- For example, if 'Noah' is the correct option and is placed at index 2 of the options list, correctAnswerIndex MUST be 2. Do not mismatch them.\n"
          "- Ensure the question details are theologically and historically accurate, using undisputed facts.";

      // 2. Initialize Gemini Service if needed
      if (!_geminiService.isInitialized) {
        final apiKey = dotenv.env['OPEN_ROUTER_API_KEY'] ?? '';
        _geminiService.init(apiKey);
      }

      if (_activeGenerationToken != currentToken) {
        await _setGeneratingGame(false);
        return "Generation cancelled.";
      }

      // 3. Call AI
      final response = await _geminiService.sendMessageOneShot(
        prompt,
        systemInstruction: systemInstruction,
      );

      if (_activeGenerationToken != currentToken) {
        await _setGeneratingGame(false);
        return "Generation cancelled.";
      }

      if (response == null || response.isEmpty) {
        if (_activeGenerationToken == currentToken) {
          setLoading(false);
        }
        await _setGeneratingGame(false);
        return "Could not generate questions. AI connection failed.";
      }

      // 4. Parse AI JSON response
      List<dynamic> parsedQuestions;
      try {
        // Strip markdown backticks if Gemini ignored instructions and appended them
        String cleanJson = response.trim();
        if (cleanJson.startsWith("```")) {
          final lines = cleanJson.split("\n");
          if (lines.first.startsWith("```")) {
            lines.removeAt(0);
          }
          if (lines.last.startsWith("```")) {
            lines.removeLast();
          }
          cleanJson = lines.join("\n").trim();
        }
        parsedQuestions = jsonDecode(cleanJson) as List<dynamic>;
      } catch (e) {
        safePrint("Failed to parse JSON response: $e. Response was: $response");
        if (_activeGenerationToken == currentToken) {
          setLoading(false);
        }
        await _setGeneratingGame(false);
        return "AI generated an invalid format. Please try again.";
      }

      if (_activeGenerationToken != currentToken) {
        await _setGeneratingGame(false);
        return "Generation cancelled.";
      }

      // Validate parsed format
      if (parsedQuestions.isEmpty) {
        if (_activeGenerationToken == currentToken) {
          setLoading(false);
        }
        await _setGeneratingGame(false);
        return "AI returned zero questions. Please try again.";
      }

      // 5. Setup players list (only active accepted members)
      final List<String> turnOrder = [];
      membersMap.forEach((uid, val) {
        if (val['status'] == 'accepted') {
          turnOrder.add(uid);
        }
      });

      if (turnOrder.isEmpty) {
        if (_activeGenerationToken == currentToken) {
          setLoading(false);
        }
        await _setGeneratingGame(false);
        return "No accepted players in the group.";
      }

      if (_activeGenerationToken != currentToken) {
        await _setGeneratingGame(false);
        return "Generation cancelled.";
      }

      // Shuffle turn order to make it random and fun
      turnOrder.shuffle();

      String targetScopeValue = _scopeValue;
      if (_scopeType == 'general') {
        targetScopeValue = 'General Bible Knowledge';
      } else if (_scopeType == 'tech') {
        targetScopeValue = 'Technology & Coding';
      } else if (_scopeType == 'science') {
        targetScopeValue = 'Science & Physics';
      } else if (_scopeType == 'english') {
        targetScopeValue = 'English & Literature';
      } else if (_scopeType == 'economics') {
        targetScopeValue = 'Economics & Finance';
      } else if (_scopeType == 'mindfulness') {
        targetScopeValue = 'Personality & Mindfulness';
      }

      // 6. Create active game document in Firestore
      final gameDocRef = await _firestore.collection('games').add({
        'groupId': _activeGroupId,
        'status': 'playing',
        'scopeType': _scopeType,
        'scopeValue': targetScopeValue,
        'questionCount': questionCount,
        'questionsPerPlayer': _questionsPerParticipant,
        'timerSeconds': _timerSeconds,
        'currentQuestionIndex': 0,
        'currentTurnPlayerUid': turnOrder.first,
        'turnOrder': turnOrder,
        'turnStartTime': FieldValue.serverTimestamp(),
        'timerEndsAt': DateTime.now().add(Duration(seconds: _timerSeconds)).toIso8601String(),
        'questions': parsedQuestions,
        'playerAnswers': {for (var uid in turnOrder) uid: []},
        'scores': {for (var uid in turnOrder) uid: 0},
      });

      if (_activeGenerationToken != currentToken) {
        // Clean up orphaned document
        try {
          await _firestore.collection('games').doc(gameDocRef.id).delete();
        } catch (e) {
          safePrint("Error deleting orphaned game: $e");
        }
        await _setGeneratingGame(false);
        return "Generation cancelled.";
      }

      // Extract new question texts to record them
      final List<String> newQuestionTexts = parsedQuestions
          .map((q) => (q['questionText'] ?? q['question'] ?? '').toString())
          .where((text) => text.isNotEmpty)
          .toList();

      final List<String> updatedAskedQuestions = List<String>.from(askedQuestions)
        ..addAll(newQuestionTexts);

      // Keep askedQuestions list capped at most recent 100 questions to respect document limits
      if (updatedAskedQuestions.length > 100) {
        updatedAskedQuestions.removeRange(0, updatedAskedQuestions.length - 100);
      }

      // 7. Update Group collection to reference this active game, store asked questions, and clear isGeneratingGame
      await _firestore.collection('groups').doc(_activeGroupId!).update({
        'activeGameId': gameDocRef.id,
        'askedQuestions': updatedAskedQuestions,
        'isGeneratingGame': false,
      });

      if (_activeGenerationToken == currentToken) {
        setLoading(false);
      }
      return null; // Success
    } catch (e) {
      safePrint("Error starting game: $e");
      await _setGeneratingGame(false);
      if (_activeGenerationToken == currentToken) {
        setLoading(false);
      }
      return "An error occurred starting the game: $e";
    }
  }

  /// Submit an answer for the current player
  Future<void> submitAnswer(int answerIndex) async {
    if (_gameData == null || _activeGroupId == null) return;

    final gameId = _groupData?['activeGameId'] as String?;
    if (gameId == null) return;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final expectedTurnUid = _gameData!['currentTurnPlayerUid'] as String?;

    // Only allow submission if it matches current player's turn
    if (currentUid == null || expectedTurnUid == null || currentUid != expectedTurnUid) return;
    final myUid = currentUid;

    try {
      final questions = _gameData!['questions'] as List<dynamic>;
      final int currentIndex = _gameData!['currentQuestionIndex'] as int;
      final List<dynamic> turnOrder = _gameData!['turnOrder'] as List<dynamic>;
      final Map<String, dynamic> playerAnswers = Map<String, dynamic>.from(_gameData!['playerAnswers']);
      final Map<String, dynamic> scores = Map<String, dynamic>.from(_gameData!['scores']);

      final currentQuestion = questions[currentIndex] as Map<String, dynamic>;
      final int correctIdx = currentQuestion['correctAnswerIndex'] as int;

      // Log answer
      final list = List<int>.from(playerAnswers[myUid] ?? []);
      list.add(answerIndex);
      playerAnswers[myUid] = list;

      // Update score if correct
      if (answerIndex == correctIdx) {
        scores[myUid] = (scores[myUid] as int? ?? 0) + 1;
      }

      // Check if game is completed
      final nextIndex = currentIndex + 1;
      if (nextIndex >= questions.length) {
        // Completed game!
        await _firestore.collection('games').doc(gameId).update({
          'status': 'completed',
          'currentQuestionIndex': nextIndex,
          'playerAnswers': playerAnswers,
          'scores': scores,
        });

        // Award XP to all participants
        _awardXpToParticipants(turnOrder, scores);
      } else {
        // Rotate turn to next player
        final nextTurnUid = turnOrder[nextIndex % turnOrder.length] as String;

        await _firestore.collection('games').doc(gameId).update({
          'currentQuestionIndex': nextIndex,
          'currentTurnPlayerUid': nextTurnUid,
          'turnStartTime': FieldValue.serverTimestamp(),
          'timerEndsAt': DateTime.now().add(Duration(seconds: _timerSeconds)).toIso8601String(),
          'playerAnswers': playerAnswers,
          'scores': scores,
        });
      }
    } catch (e) {
      safePrint("Error submitting answer: $e");
    }
  }

  /// Award XP to all active players upon game completion
  void _awardXpToParticipants(List<dynamic> uids, Map<String, dynamic> scores) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    for (var uid in uids) {
      try {
        final score = scores[uid] as int? ?? 0;
        final xpGained = 20 + (score * 10); // 20 XP base + 10 XP per correct answer

        if (currentUser != null && uid == currentUser.uid) {
          // For the current user, award XP locally and remote via EngagementService
          await EngagementService().recordAction(
            EngagementAction.bibleQuizComplete,
            bonusAmount: score * 10,
          );

          // Log the group quiz result locally for overall growth and daily hub
          try {
            final totalQuestions = _gameData?['questions']?.length ?? 5;
            final quiz = {
              'date': DateTime.now().toIso8601String(),
              'chapter': 'Group Quiz: ${_groupData?['name'] ?? "Lobby"}',
              'score': score,
              'total_questions': totalQuestions,
              'quiz_type': 'Group Quiz',
              'xp_earned': xpGained,
            };
            await DatabaseHelper().insertQuizResult(quiz);
          } catch (sqliteErr) {
            safePrint("Error logging group quiz result locally: $sqliteErr");
          }
        } else {
          // For other participants, update their Firestore documents directly
          final userRef = _firestore.collection('users').doc(uid);
          await _firestore.runTransaction((transaction) async {
            final snapshot = await transaction.get(userRef);
            if (snapshot.exists) {
              final currentXp = snapshot.data()?['xp'] as int? ?? 0;
              final newXp = currentXp + xpGained;
              final newLevel = EngagementService().levelFromXp(newXp);

              transaction.update(userRef, {
                'xp': newXp,
                'level': newLevel,
              });
            }
          });
        }
      } catch (e) {
        safePrint("Error awarding XP to $uid: $e");
      }
    }
  }

  /// Terminate/reset active game (Creator only)
  Future<void> endAndResetGame() async {
    if (_activeGroupId == null) return;
    final gameId = _groupData?['activeGameId'] as String?;
    try {
      await _firestore.collection('groups').doc(_activeGroupId).update({
        'activeGameId': null,
      });
      if (gameId != null && gameId.isNotEmpty) {
        await _firestore.collection('games').doc(gameId).delete();
      }
      _gameSubscription?.cancel();
      _gameData = null;
      _stopTimer();
      notifyListeners();
    } catch (e) {
      safePrint("Error resetting game: $e");
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 4. Timer Logic
  // ───────────────────────────────────────────────────────────────────────────

  void _syncLocalTimer() {
    _stopTimer();
    if (_gameData == null || _gameData!['status'] != 'playing') return;

    final timerEndsAtStr = _gameData!['timerEndsAt'] as String?;
    if (timerEndsAtStr == null) return;

    final timerEndsAt = DateTime.tryParse(timerEndsAtStr);
    if (timerEndsAt == null) return;

    _secondsRemaining = timerEndsAt.difference(DateTime.now()).inSeconds;
    if (_secondsRemaining < 0) _secondsRemaining = 0;

    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        _secondsRemaining--;
        notifyListeners();
      } else {
        _stopTimer();
        _handleTimeOut();
      }
    });
  }

  void _stopTimer() {
    _gameTimer?.cancel();
    _gameTimer = null;
    _secondsRemaining = 0;
  }

  /// Automatically register a wrong answer/timeout if current user's timer expires
  void _handleTimeOut() {
    final expectedTurnUid = _gameData?['currentTurnPlayerUid'] as String?;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    // Only submit if it's actually the current user's turn
    if (currentUid == expectedTurnUid) {
      submitAnswer(-1); // -1 signifies a skipped/timeout answer
    }
  }

  /// Directly join a group using a room code / clipboard invitation link
  Future<void> directJoinGroup(String groupId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final groupRef = _firestore.collection('groups').doc(groupId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(groupRef);
        if (snapshot.exists) {
          transaction.update(groupRef, {
            'members.${currentUser.uid}': {
              'email': currentUser.email ?? '',
              'displayName': currentUser.displayName ?? currentUser.email ?? 'Member',
              'status': 'accepted',
              'role': 'member',
              'joinedAt': DateTime.now().toIso8601String(),
            }
          });
        }
      });
      safePrint("Successfully joined group directly: $groupId");
    } catch (e) {
      safePrint("Error joining group directly: $e");
      rethrow;
    }
  }

  Future<void> _saveSession(String groupId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_quiz_group_id', groupId);
    } catch (e) {
      safePrint("Error saving session: $e");
    }
  }

  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('active_quiz_group_id');
      _restoredGroupId = null;
    } catch (e) {
      safePrint("Error clearing session: $e");
    }
  }

  Future<void> tryRestoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedGroupId = prefs.getString('active_quiz_group_id');
      if (savedGroupId != null && savedGroupId.isNotEmpty) {
        // Verify group document still exists in Firestore
        final doc = await _firestore.collection('groups').doc(savedGroupId).get();
        if (doc.exists) {
          _restoredGroupId = savedGroupId;
          notifyListeners();
        } else {
          await prefs.remove('active_quiz_group_id');
        }
      }
    } catch (e) {
      safePrint("Error restoring session: $e");
    }
  }

  void clearRestoredSession() {
    _restoredGroupId = null;
    notifyListeners();
  }

  void _checkForNewJoins(Map<String, dynamic> oldData, Map<String, dynamic> newData) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final isCreator = newData['createdBy'] == currentUser.uid;
    if (!isCreator) return;

    final oldMembers = oldData['members'] as Map<String, dynamic>? ?? {};
    final newMembers = newData['members'] as Map<String, dynamic>? ?? {};

    bool shouldPlayBeep = false;

    newMembers.forEach((uid, val) {
      if (uid == currentUser.uid) return;
      final newStatus = val['status'];
      final oldMember = oldMembers[uid];
      final oldStatus = oldMember != null ? oldMember['status'] : null;

      if (newStatus == 'accepted' && oldStatus != 'accepted') {
        shouldPlayBeep = true;
      }
    });

    if (shouldPlayBeep) {
      _playBeepSound();
    }
  }

  Future<void> _playBeepSound() async {
    try {
      await _lobbyAudioPlayer.setSource(AssetSource('audio/beep.wav'));
      await _lobbyAudioPlayer.resume();
    } catch (e) {
      safePrint("Error playing beep sound: $e");
    }
  }

  Future<void> playQuizStartedSoundAndVibrate() async {
    try {
      await _lobbyAudioPlayer.setSource(AssetSource('audio/quiz_started.wav'));
      await _lobbyAudioPlayer.resume();
    } catch (e) {
      safePrint("Error playing quiz started sound: $e");
    }
    try {
      await HapticFeedback.vibrate();
      await HapticFeedback.heavyImpact();
    } catch (e) {
      safePrint("Error triggering haptic: $e");
    }
  }

  @override
  void dispose() {
    _stopTimer();
    _groupSubscription?.cancel();
    _gameSubscription?.cancel();
    _lobbyAudioPlayer.dispose();
    super.dispose();
  }
}
