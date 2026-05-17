import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mindpilot/export.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<void> syncTasksFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .get();

      final localTasks = await _dbHelper.getTasks();
      final localRemoteIds = localTasks.map((t) => t['remoteId'] as String?).whereType<String>().toSet();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final remoteId = doc.id;

        if (!localRemoteIds.contains(remoteId)) {
          await _dbHelper.insertTask({
            'title': data['title'],
            'description': data['description'],
            'date': data['date'],
            'isDone': (data['isDone'] == true || data['isDone'] == 1) ? 1 : 0,
            'completionTime': data['completionTime'],
            'startTime': data['startTime'],
            'durationMinutes': data['durationMinutes'],
            'remoteId': remoteId,
          });
        }
      }
    } catch (e) {
      safePrint('Sync Error: $e');
      if (e.toString().contains('network') || e.toString().contains('unavailable')) {
        _notifyOffline();
      }
    }
  }

  Future<void> syncJournalsFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('journals')
          .get();

      final localJournals = await _dbHelper.getEntries();
      final localRemoteIds = localJournals.map((j) => j['remoteId'] as String?).whereType<String>().toSet();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final remoteId = doc.id;

        if (!localRemoteIds.contains(remoteId)) {
          await _dbHelper.insertEntry({
            'date': data['date'],
            'time': data['time'],
            'text': data['text'],
            'mood': data['mood'],
            'title': data['title'],
            'remoteId': remoteId,
          });
        }
      }
    } catch (e) {
      safePrint('Sync Error: $e');
      if (e.toString().contains('network') || e.toString().contains('unavailable')) {
        _notifyOffline();
      }
    }
  }

  Future<void> pushTaskToFirestore(Map<String, dynamic> taskMap) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final remoteId = taskMap['remoteId'];
      if (remoteId != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('tasks')
            .doc(remoteId)
            .set(taskMap, SetOptions(merge: true));
      } else {
        final docRef = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('tasks')
            .add(taskMap);
        
        final localId = taskMap['id'];
        if (localId != null) {
          await _dbHelper.updateTask(localId, {'remoteId': docRef.id});
        }
      }
    } catch (e) {
      safePrint('Push Error: $e');
      if (e.toString().contains('network') || e.toString().contains('unavailable')) {
        _notifyOffline();
      }
    }
  }

  Future<void> pushJournalToFirestore(Map<String, dynamic> journalMap) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final remoteId = journalMap['remoteId'];
      if (remoteId != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('journals')
            .doc(remoteId)
            .set(journalMap, SetOptions(merge: true));
      } else {
        final docRef = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('journals')
            .add(journalMap);
        
        final localId = journalMap['id'];
        if (localId != null) {
          await _dbHelper.updateJournalRemoteId(localId, docRef.id);
        }
      }
    } catch (e) {
      safePrint('Push Error: $e');
    }
  }

  Future<void> deleteTaskFromFirestore(String remoteId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .doc(remoteId)
          .delete();
    } catch (e) {
      safePrint('Delete Error: $e');
    }
  }

  Future<void> deleteJournalFromFirestore(String remoteId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('journals')
          .doc(remoteId)
          .delete();
    } catch (e) {
      safePrint('Delete Error: $e');
    }
  }

  void _notifyOffline() {
    final context = R.N.navKey.currentContext;
    if (context != null && context.mounted) {
      context.showInAppNotification('No network. Changes saved locally.');
    }
  }
}
