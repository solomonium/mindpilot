import 'package:mindpilot/export.dart';
import 'dart:async';

class AppNotification {
  final int? id;
  final String title;
  final String body;
  final String date;
  final String type; // 'insight' or 'update'
  final bool isRead;

  AppNotification({
    this.id,
    required this.title,
    required this.body,
    required this.date,
    required this.type,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'date': date,
      'type': type,
      'isRead': isRead ? 1 : 0,
    };
  }
}

class NotificationProvider extends ChangeNotifier {
  final List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  String _dailyInsight = "Clarity comes when you stop seeking answers outside and start listening within.";
  String? _insightExplanation;
  bool _isFetchingExplanation = false;
  String? _fetchError;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  Timer? _backgroundQuoteTimer;


  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  String get dailyInsight => _dailyInsight;
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
      );
      _notifications.add(notif);
    }

    // Set daily insight to the newest one (first in descending list)
    for (var n in _notifications) {
      if (n.type == 'insight') {
        _dailyInsight = n.body;
        break;
      }
    }

    _unreadCount = await _dbHelper.getUnreadNotificationsCount();
    notifyListeners();

    // Start the background timer if it's not already running
    startBackgroundQuoteTimer();
  }

  void startBackgroundQuoteTimer() {
    if (_backgroundQuoteTimer != null) return;
    
    _backgroundQuoteTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      checkAndFetchNewQuote();
    });
  }

  Future<void> checkAndFetchNewQuote() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastFetch = prefs.getInt('LAST_QUOTE_FETCH') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      final int fetchInterval = ConfigService().quoteIntervalMs; 

      final timeSinceLastFetch = now - lastFetch;

      if (timeSinceLastFetch > fetchInterval) {
        // Update the timestamp immediately to prevent double-fetching
        await prefs.setInt('LAST_QUOTE_FETCH', now);
        
        final quoteData = await QuoteService().fetchRandomQuote();
        
        if (quoteData != null) {
          final body = "${quoteData['quote']} — ${quoteData['author']}";
          
          await addNotification({
            'title': 'New Insight',
            'body': body,
            'type': 'insight',
          });

          NotificationService().showForegroundNotification(
            'New Wisdom Available',
            'A new insight has arrived to keep you focused.',
            'update', 
          );
        } else {
          // Reset timer so it retries on next check if it failed
          await prefs.setInt('LAST_QUOTE_FETCH', lastFetch);
        }
      }
    } catch (e) {
      // Keep only critical error logs
      safePrint('Error in background check: $e');
    }
  }




  Future<void> addNotification(Map<String, dynamic> data) async {
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
    });

    if (type == 'insight') {
      _dailyInsight = body;
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

  Future<void> fetchInsightExplanation() async {
    if (_insightExplanation != null) return;
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

      final prompt = "Give a very simple, 1-2 sentence explanation of this insight for a teenager: '$_dailyInsight'. Use basic words. Then, add a section starting with '**Quick Tip:**' followed by one practical action. In your tip, highly recommend using the **Decision Analyzer** or **Focus Session** in the MindPilot app, explaining that these tools will help them organize their thoughts and gain massive mental clarity. Use **bold markers** for these feature names and the 'Quick Tip' label.";
      
      safePrint("Explaining Insight: $_dailyInsight");
      final response = await gemini.sendMessage(prompt);
      
      if (response == null || response.isEmpty) {
        throw Exception("Empty response from AI");
      }

      _insightExplanation = response;
    } catch (e) {
      safePrint("Explanation Fetch Error: $e");
      _fetchError = "Trouble connecting. Please tap to retry.";
      GeminiService().resetChat(); // Reset session for fresh retry
    } finally {
      _isFetchingExplanation = false;
      notifyListeners();
    }
  }


  void clearExplanation() {
    _insightExplanation = null;
    _fetchError = null;
    notifyListeners();
  }
}
