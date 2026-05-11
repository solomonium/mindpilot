import 'package:mindpilot/export.dart';

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
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  String get dailyInsight => _dailyInsight;

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
      
      // Update daily insight if it's the latest one
      if (notif.type == 'insight') {
        _dailyInsight = notif.body;
      }
    }
    _unreadCount = await _dbHelper.getUnreadNotificationsCount();
    notifyListeners();
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
}
