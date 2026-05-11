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

  static List<Map<String, dynamic>> quickActions(BuildContext context) {
    AppTheme theme = context.watch();
    return [
      {
        "icon": R.png.plus.svg,
        "label": R.S.contribute,
        "bgColor": theme.primaryBase.withOpacity(0.1),
        "iconColor": theme.primaryBase,
      },
      {
        "icon": R.png.send.svg,
        "label": R.S.sendMoney,
        "bgColor": theme.purplePrimary.withOpacity(0.1),
        "iconColor": theme.purplePrimary,
      },
      {
        "icon": R.png.claim.svg,
        "label": R.S.fileClaim,
        "bgColor": theme.successPrimary.withOpacity(0.1),
        "iconColor": theme.successPrimary,
      },
      {
        "icon": R.png.heart.svg,
        "label": R.S.startFundraiser,
        "bgColor": theme.warningPrimary.withOpacity(0.1),
        "iconColor": theme.warningPrimary,
      },
    ];
  }
}
