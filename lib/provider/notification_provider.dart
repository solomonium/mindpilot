import 'package:mindpilot/export.dart';
import 'dart:async';

class AppNotification {
  final int? id;
  final String title;
  final String body;
  final String date;
  final String type; // 'insight' or 'update'
  final bool isRead;
  final String? author;
  final String? source;

  AppNotification({
    this.id,
    required this.title,
    required this.body,
    required this.date,
    required this.type,
    this.isRead = false,
    this.author,
    this.source,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'date': date,
      'type': type,
      'isRead': isRead ? 1 : 0,
      'author': author,
      'source': source,
    };
  }
}

class NotificationProvider extends ChangeNotifier {
  final List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  String _dailyInsight = "Nothing in the world is ever completely wrong. Even a stopped clock is right twice a day.";
  String? _dailyInsightAuthor = "Paulo Coelho";
  String? _lastInsightSource;
  String? _lastInsightDate;
  String? _insightExplanation;
  bool _isFetchingExplanation = false;
  String? _fetchError;
  final DatabaseHelper _dbHelper = DatabaseHelper();


  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  String get dailyInsight => _dailyInsight;
  String? get dailyInsightAuthor => _dailyInsightAuthor;
  String? get lastInsightSource => _lastInsightSource;
  String? get lastInsightDate => _lastInsightDate;
  String? get insightExplanation => _insightExplanation;
  bool get isFetchingExplanation => _isFetchingExplanation;
  String? get fetchError => _fetchError;

  Future<void> loadNotifications() async {
    final data = await _dbHelper.getNotifications();
    _notifications.clear();
    for (var item in data) {
      final notif = AppNotification(
        id: item['id'],
        title: item['title'],
        body: item['body'],
        date: item['date'],
        type: item['type'],
        isRead: item['isRead'] == 1,
        author: item['author'],
        source: item['source'],
      );
      _notifications.add(notif);
    }

    // Set daily insight to the newest one (first in descending list)
    for (var n in _notifications) {
      if (n.type == 'insight') {
        _dailyInsight = n.body;
        _dailyInsightAuthor = n.author;
        _lastInsightSource = n.source;
        _lastInsightDate = n.date;
        break;
      }
    }

    _unreadCount = await _dbHelper.getUnreadNotificationsCount();
    notifyListeners();

    // Listen to broadcasts from admin
    listenToBroadcasts();
  }

  void listenToBroadcasts() {
    FirebaseFirestore.instance
        .collection('broadcasts')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final id = snapshot.docs.first.id;
        
        final prefs = await SharedPreferences.getInstance();
        final lastBroadcastId = prefs.getString('LAST_BROADCAST_ID');
        final lastBroadcastTime = prefs.getString('LAST_BROADCAST_TIME');
        
        final createdAt = data['createdAt'] as Timestamp?;
        final timeStr = createdAt?.toDate().toIso8601String() ?? '';
        
        if (lastBroadcastId != id || (timeStr.isNotEmpty && lastBroadcastTime != timeStr)) {
          await prefs.setString('LAST_BROADCAST_ID', id);
          if (timeStr.isNotEmpty) {
            await prefs.setString('LAST_BROADCAST_TIME', timeStr);
          }
          
          final title = data['title'] ?? 'MindPilot Update';
          final body = data['body'] ?? '';
          final type = data['type'] ?? 'update';
          final author = data['author'];
          final source = data['source'];

          // Deduplication: Check if we recently received a notification with the same content (last 5 minutes)
          final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
          final isRecentDuplicate = _notifications.any((n) {
            final notifDate = DateTime.tryParse(n.date);
            if (notifDate == null) return false;
            return n.body.trim() == body.trim() &&
                   n.title.trim() == title.trim() &&
                   notifDate.isAfter(fiveMinutesAgo);
          });

          if (isRecentDuplicate) {
            safePrint("Ignoring duplicate broadcast by content received recently: $body");
            return;
          }
          
          await addNotification({
            'title': title,
            'body': body,
            'type': type,
            'author': author,
            'source': source,
          }, broadcastId: id);
          
          NotificationService().showForegroundNotification(title, body, type);
        }
      }
    });
  }






  Future<void> addNotification(Map<String, dynamic> data, {String? broadcastId}) async {
    final title = data['title'] ?? 'New Notification';
    final body = data['body'] ?? '';
    final type = data['type'] ?? 'update';
    final date = DateTime.now().toIso8601String();

    await _dbHelper.insertNotification({
      'title': title,
      'body': body,
      'type': type,
      'date': date,
      'isRead': 0,
      'author': data['author'],
      'source': data['source'],
    });

    if (broadcastId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('LAST_BROADCAST_ID', broadcastId);
    }

    if (type == 'insight') {
      _dailyInsight = body;
      _lastInsightSource = data['source'];
      
      // Self-healing: if author is missing but body contains a dash, try to extract it
      String? incomingAuthor = data['author'];
      if ((incomingAuthor == null || incomingAuthor == "Unknown") && body.contains(" - ")) {
        final parts = body.split(" - ");
        _dailyInsight = parts[0].trim();
        incomingAuthor = parts[1].trim();
      }
      
      _dailyInsightAuthor = (incomingAuthor == null || incomingAuthor.isEmpty) ? "Unknown" : incomingAuthor;
      _insightExplanation = null; // Clear explanation for new insight
    }

    await loadNotifications();
  }

  Future<void> markAsRead(int id) async {
    await _dbHelper.markNotificationAsRead(id);
    await loadNotifications();
  }

  Future<void> deleteNotification(int id) async {
    await _dbHelper.deleteNotification(id);
    await loadNotifications();
  }

  Future<bool> fetchInsightExplanation() async {
    if (_insightExplanation != null) return false;
    _isFetchingExplanation = true;
    _fetchError = null;
    notifyListeners();

    try {
      final gemini = GeminiService();
      
      // Ensure initialized
      if (!gemini.isInitialized) {
        final apiKey = dotenv.env['OPEN_ROUTER_API_KEY'] ?? '';
        final models = await gemini.listModels(apiKey);
        String selectedModel = 'google/gemini-flash-1.5-8b:free';
        if (models.isNotEmpty) selectedModel = models.first;
        gemini.init(apiKey, modelName: selectedModel);
      }

      final author = _dailyInsightAuthor;
      final shortName = (author != null && author != "Unknown") 
          ? author.trim().split(' ').first 
          : null;
      final hasAuthor = shortName != null;
      final authorRef = hasAuthor ? shortName : "the author";
      
      final prompt = "Explain what $authorRef means by this insight: '$_dailyInsight'. Use very simple, 1-2 sentence language suitable for a teenager. ${hasAuthor ? "Refer to the author by their first name only (e.g., '$shortName means...' or 'What $shortName is saying is...')." : "Refer to the insight (e.g., 'This means...' or 'What this is saying is...')."} Then, provide a dynamic section starting with '**Quick Tip:**' that links this specific insight to the most relevant feature in the MindPilot app. If the insight is about productivity or focus, highly recommend using the **Focus Session**. If it is about clarity, choices, or mental clutter, highly recommend using the **Decision Analyzer**. Explain exactly how using that specific tool will help them put the lesson into practice today. Use **bold markers** for the feature names and the 'Quick Tip' label.";
      
      safePrint("Explaining Insight: $_dailyInsight");
      final response = await gemini.sendMessage(prompt);
      
      if (response == null || response.isEmpty) {
        throw Exception("Empty response from AI");
      }

      _insightExplanation = response;
      return true;
    } catch (e) {
      safePrint("Explanation Fetch Error: $e");
      _fetchError = "Trouble connecting. Please tap to retry.";
      GeminiService().resetChat(); // Reset session for fresh retry
      return false;
    } finally {
      _isFetchingExplanation = false;
      notifyListeners();
    }
  }

  String getInsightShareCaption() {
    final lowerInsight = _dailyInsight.toLowerCase();
    
    // Focus & Concentration
    if (RegExp(r'focus|concentrate|distract|attention|deep|busy').hasMatch(lowerInsight)) {
      return "Ready to sharpen your focus? 🎯 Today's wisdom is all about deep work. Have you stayed focused today?";
    } 
    // Decisions & Clarity
    else if (RegExp(r'choice|decide|decision|clarity|clear|path|confuse').hasMatch(lowerInsight)) {
      return "Decisions define our path. 🧭 Feeling clear about your choices today? MindPilot is here to help.";
    } 
    // Productivity & Action
    else if (RegExp(r'productive|action|work|effort|discipline|do|task|goal').hasMatch(lowerInsight)) {
      return "Time to turn intentions into actions! ⚡ How are you making progress on your goals today?";
    } 
    // Growth & Success
    else if (RegExp(r'growth|success|better|improve|level|learn|win').hasMatch(lowerInsight)) {
      return "Leveling up is a journey. 📈 Did you take a step toward your best self today?";
    }
    // Mindset & Courage
    else if (RegExp(r'mind|fear|brave|courage|believe|spirit|peace').hasMatch(lowerInsight)) {
      return "A clear mind is a superpower. 🧠 How are you protecting your mental space today?";
    }
    // Time & Consistency
    else if (RegExp(r'time|day|consistency|habit|routine|moment').hasMatch(lowerInsight)) {
      return "Consistency is the bridge to mastery. ⏳ What small win are you celebrating today?";
    }

    return "Wisdom meets focus on MindPilot! 💡 What's your biggest takeaway from today's insight?";
  }


  void clearExplanation() {
    _insightExplanation = null;
    _fetchError = null;
    notifyListeners();
  }


  @override
  void dispose() {
    super.dispose();
  }
}
