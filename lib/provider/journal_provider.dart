import 'package:mindpilot/export.dart';

class JournalEntry {
  final int? id;
  final String date;
  final String time;
  final String text;
  final String mood;
  final String? title;
  final String? remoteId;

  JournalEntry({
    this.id,
    required this.date,
    required this.time,
    required this.text,
    required this.mood,
    this.title,
    this.remoteId,
  });
}

class JournalProvider extends ChangeNotifier {
  final List<JournalEntry> _entries = [];
  int _totalFocusMinutes = 0;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<JournalEntry> get entries => _entries;
  int get totalFocusMinutes => _totalFocusMinutes;

  Future<void> loadEntries() async {
    final data = await _dbHelper.getEntries();
    _entries.clear();
    for (var item in data) {
      _entries.add(JournalEntry(
        id: item['id'],
        date: item['date'],
        time: item['time'],
        text: item['text'],
        mood: item['mood'],
        title: item['title'],
        remoteId: item['remoteId'],
      ));
    }
    notifyListeners();
  }

  Future<void> loadFocusTime() async {
    _totalFocusMinutes = await _dbHelper.getTotalFocusMinutes();
    notifyListeners();
  }

  Future<void> deleteJournalEntry(int id) async {
    final entry = _entries.firstWhere((e) => e.id == id);
    if (entry.remoteId != null) {
      SyncService().deleteJournalFromFirestore(entry.remoteId!);
    }
    await _dbHelper.deleteEntry(id);
    _entries.removeWhere((element) => element.id == id);
    notifyListeners();
  }

  Future<void> addEntry({required String text, String? mood, String? title}) async {
    final now = DateTime.now();
    final date = DateFormat('MMM dd, yyyy').format(now);
    final time = DateFormat('hh:mm a').format(now);

    final Map<String, dynamic> entryMap = {
      'date': date,
      'time': time,
      'text': text,
      'mood': mood ?? 'Neutral 😐',
      'title': title,
    };
    
    final id = await _dbHelper.insertEntry(entryMap);
    entryMap['id'] = id;

    final online = await AppHelper.isOnline();
    if (online) {
      await SyncService().pushJournalToFirestore(entryMap);
    }
    
    _entries.insert(0, JournalEntry(
      id: id,
      date: date,
      time: time,
      text: text,
      mood: mood ?? 'Neutral 😐',
      title: title,
    ));

    await EngagementService().recordAction(EngagementAction.journalEntry);
    if (!await EngagementService().hasCompletedFirstSession()) {
      await EngagementService().markFirstSessionComplete('journal');
      final ctx = R.N.navKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ctx.read<AppAuthProvider>().markFirstSessionComplete();
      }
    }
    
    notifyListeners();
  }

  Future<void> saveFocusSession(int minutes) async {
    await _dbHelper.insertFocusSession(minutes);
    await loadFocusTime();
  }

  Future<void> loadInitialData() async {
    if (await AppHelper.isOnline()) {
      await SyncService().syncJournalsFromFirestore();
      await SyncService().syncPendingJournals();
    }
    await loadEntries();
    await loadFocusTime();
  }
}
