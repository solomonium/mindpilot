import 'package:mindpilot/export.dart';
import 'package:mindpilot/models/calendar_event.dart';

class GoogleCalendarService {
  static final GoogleCalendarService _instance =
      GoogleCalendarService._internal();
  factory GoogleCalendarService() => _instance;
  GoogleCalendarService._internal();

  static const String _calendarScope =
      'https://www.googleapis.com/auth/calendar.readonly';
  static const String _baseUrl =
      'https://www.googleapis.com/calendar/v3/calendars/primary/events';

  String? _accessToken;

  /// Request calendar scope and return an access token, or null if denied / not a Google user.
  Future<String?> authorizeCalendar() async {
    try {
      final authorization = await GoogleSignIn.instance.authorizationClient
          .authorizeScopes([_calendarScope]);
      _accessToken = authorization.accessToken;

      // Save connection state in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('GOOGLE_CALENDAR_CONNECTED', true);

      return _accessToken;
    } catch (e) {
      safePrint('GoogleCalendarService: authorizeCalendar error: $e');
      return null;
    }
  }

  /// Returns true if the user is signed in with Google (Calendar is available).
  bool get isGoogleUser {
    // Temporarily disabled Google Calendar feature
    return false;

    // final user = FirebaseAuth.instance.currentUser;
    // if (user == null) return false;
    // return user.providerData.any((p) => p.providerId == 'google.com');
  }

  /// Check if the user has opted-in to connect Google Calendar.
  Future<bool> get isCalendarConnected async {
    if (!isGoogleUser) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('GOOGLE_CALENDAR_CONNECTED') ?? false;
  }

  /// Check if calendar access has already been granted (access token cached).
  bool get hasCalendarAccess => _accessToken != null;

  /// Fetch today's calendar events. If [requestPermission] is false, it won't prompt the user if not already connected.
  Future<List<CalendarEvent>> fetchTodayEvents({bool requestPermission = true}) async {
    if (!isGoogleUser) return [];

    try {
      if (_accessToken == null) {
        if (!requestPermission) {
          final isConnected = await isCalendarConnected;
          if (!isConnected) return [];
        }
        final token = await authorizeCalendar();
        if (token == null) return [];
      }

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final dio = Dio();
      final response = await dio.get(
        _baseUrl,
        queryParameters: {
          'timeMin': startOfDay.toUtc().toIso8601String(),
          'timeMax': endOfDay.toUtc().toIso8601String(),
          'singleEvents': true,
          'orderBy': 'startTime',
          'maxResults': 20,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $_accessToken'},
        ),
      );

      if (response.statusCode == 401) {
        // Token expired – refresh
        _accessToken = null;
        final token = await authorizeCalendar();
        if (token == null) return [];
        return fetchTodayEvents(requestPermission: requestPermission);
      }

      final items = (response.data['items'] as List<dynamic>? ?? []);
      final events = items
          .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
          .where((e) => !e.isAllDay)
          .toList();

      return events;
    } catch (e) {
      safePrint('GoogleCalendarService: fetchTodayEvents error: $e');
      return [];
    }
  }

  /// Fetch only upcoming events for today (start time > now).
  Future<List<CalendarEvent>> fetchUpcomingEvents({bool requestPermission = true}) async {
    final events = await fetchTodayEvents(requestPermission: requestPermission);
    final now = DateTime.now();
    return events
        .where((e) => e.endTime.isAfter(now))
        .take(5)
        .toList();
  }
}
