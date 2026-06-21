import 'package:mindpilot/export.dart';

class Mock {
  String get userName => 'Janet Jackson';
  String get date => '30 Jun 2023';
  String idVerification(bool status) =>
      'ID ${status == true ? 'Verified' : 'Not Verified'}';

  static List<Map<String, dynamic>> navItems() => [
    {"icon": Icons.home_outlined, "label": "Home", 'setIndex': 0},
    {"icon": Icons.timer_outlined, "label": "Focus", 'setIndex': 1},
    {"icon": Icons.menu_book_outlined, "label": "Bible", 'setIndex': 2},
    {"icon": Icons.psychology_outlined, "label": "Decision", 'setIndex': 3},
    {"icon": Icons.person_outline, "label": "Profile", 'setIndex': 4},
  ];
}
