class CalendarEvent {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final String? meetingLink;
  final String? description;

  const CalendarEvent({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.location,
    this.meetingLink,
    this.description,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    final start = json['start'] as Map<String, dynamic>? ?? {};
    final end = json['end'] as Map<String, dynamic>? ?? {};

    DateTime parseTime(Map<String, dynamic> timeObj) {
      final dateTimeStr = timeObj['dateTime'] as String?;
      final dateStr = timeObj['date'] as String?;
      if (dateTimeStr != null) return DateTime.parse(dateTimeStr).toLocal();
      if (dateStr != null) return DateTime.parse(dateStr);
      return DateTime.now();
    }

    // Extract meeting link from conferenceData or description
    String? meetingLink;
    final conferenceData = json['conferenceData'] as Map<String, dynamic>?;
    if (conferenceData != null) {
      final entryPoints =
          conferenceData['entryPoints'] as List<dynamic>? ?? [];
      for (final ep in entryPoints) {
        final epMap = ep as Map<String, dynamic>;
        if (epMap['entryPointType'] == 'video') {
          meetingLink = epMap['uri'] as String?;
          break;
        }
      }
    }

    // Fallback: scan description for known meeting links
    if (meetingLink == null) {
      final desc = json['description'] as String? ?? '';
      final patterns = [
        RegExp(r'https://meet\.google\.com/\S+'),
        RegExp(r'https://zoom\.us/\S+'),
        RegExp(r'https://teams\.microsoft\.com/\S+'),
      ];
      for (final p in patterns) {
        final match = p.firstMatch(desc);
        if (match != null) {
          meetingLink = match.group(0);
          break;
        }
      }
    }

    return CalendarEvent(
      id: json['id'] as String? ?? '',
      title: json['summary'] as String? ?? '(No title)',
      startTime: parseTime(start),
      endTime: parseTime(end),
      location: json['location'] as String?,
      meetingLink: meetingLink,
      description: json['description'] as String?,
    );
  }

  bool get isAllDay =>
      startTime.hour == 0 && startTime.minute == 0 && endTime.hour == 0;

  bool get isUpcoming => startTime.isAfter(DateTime.now());

  bool get isOngoing =>
      DateTime.now().isAfter(startTime) && DateTime.now().isBefore(endTime);

  bool get hasMeetingLink => meetingLink != null && meetingLink!.isNotEmpty;

  Duration get duration => endTime.difference(startTime);
}
