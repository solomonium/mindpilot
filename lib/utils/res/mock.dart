import 'package:mindpilot/export.dart';

class Mock {
  String get userName => 'Janet Jackson';
  String get date => '30 Jun 2023';
  String idVerification(bool status) =>
      'ID ${status == true ? 'Verified' : 'Not Verified'}';

  static List<Map<String, dynamic>> navItems() => [
    {"icon": Icons.home_outlined, "label": "Home", 'setIndex': 0},
    {"icon": Icons.timer_outlined, "label": "Focus", 'setIndex': 1},
    {"icon": Icons.psychology, "label": "Decision", 'setIndex': 2},
    {"icon": Icons.book_outlined, "label": "Journal", 'setIndex': 3},
    {"icon": Icons.person_outline, "label": "Profile", 'setIndex': 4},
  ];
}
