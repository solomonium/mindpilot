import 'package:mindpilot/export.dart';

class Mock {
  String get userName => 'Janet Jackson';
  String get date => '30 Jun 2023';
  String idVerification(bool status) =>
      'ID ${status == true ? 'Verified' : 'Not Verified'}';

  static List<Map<String, dynamic>> navItems() => [
    {"icon": R.png.home.svg, "label": "Home", 'setIndex': 0},
    {"icon": R.png.groups.svg, "label": "Groups", 'setIndex': 1},
    {"icon": R.png.wallet.svg, "label": "Wallet", 'setIndex': 2},
    {"icon": R.png.direct.svg, "label": "Direct", 'setIndex': 2},
    {"icon": R.png.profile.svg, "label": "Profile", 'setIndex': 2},
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

  static List<Map<String, dynamic>> urgentActions(BuildContext context) {
    AppTheme theme = context.watch();
    return [
      {
        "title": "AHPC Benevolent Fund",
        "subtitle": "Monthly contribution due today",
        "amount": "UGX 20,000",
        "status": "Due today",
        "statusColor": theme.errorPrimary,
      },
      {
        "title": "Parent Association",
        "subtitle": "Fundraiser needs support",
        "amount": "UGX 50,000",
        "status": "Due in 2 days",
        "statusColor": theme.warningPrimary,
      },
      {
        "title": "Community Savings",
        "subtitle": "Loan repayment",
        "amount": "UGX 150,000",
        "status": "Due today",
        "statusColor": theme.errorPrimary,
      },
    ];
  }

  static List<Map<String, dynamic>> myGroups() => [
    {
      "name": "Amazing Grace Foundation",
      "type": "Savings Group",
      "members": "38 members",
      "balance": "UGX 20,000",
      "count": 4,
    },
    {
      "name": "Beatrice Foundation",
      "type": "Community Association",
      "members": "132 members",
      "balance": "UGX 20,000",
      "count": 2,
    },
  ];

  static List<Map<String, dynamic>> subWallets() => [
    {
      "name": "Benevolent Fund",
      "ugxBalance": "UGX 0.00",
      "dollarBalance": "\$0.00",
      "funds": [
        {"name": "My first fund", "balance": "UGX 0"},
        {"name": "My second fund", "balance": "USD 0"},
      ],
    },
  ];

  static List<Map<String, dynamic>> dms() => [
    {
      "name": "Jenny Lodie",
      "message": "You: Hello Jenny",
      "time": "Yesterday",
      "online": true,
      "unread": 0,
    },
    {
      "name": "Fernando M.",
      "message": "Hello Beatrice. Welcome to the winning team.",
      "time": "10:10AM",
      "online": true,
      "unread": 0,
    },
    {
      "name": "James Mark",
      "message": "Hello Beatrice. Welcome to the winning team.",
      "time": "Yesterday",
      "online": true,
      "unread": 1,
    },
    {
      "name": "Sule Yahaya",
      "message": "How do i join the bereavement fund?",
      "time": "Yesterday",
      "online": true,
      "unread": 2,
    },
    {
      "name": "Albert Hassan",
      "message":
          "I sent you a message since last week and you still haven't res...",
      "time": "Sunday",
      "online": false,
      "unread": 0,
    },
    {
      "name": "Nicki Minaj",
      "message": "You: Hello Nicki, welcome to the group",
      "time": "July 6th",
      "online": true,
      "unread": 0,
    },
    {
      "name": "Chris Brown",
      "message": "Hello Beatrice. Welcome to the winning team.",
      "time": "Yesterday",
      "online": true,
      "unread": 0,
    },
  ];

  static List<String> groupCategories() => [
    "All",
    "Education",
    "Social",
    "Professional",
    "Healthcare",
    "Others",
  ];

  static List<Map<String, dynamic>> recommendedGroups() => [
    {
      "name": "Fernando's Group",
      "description":
          "A cooperative savings group committed to pooling resources to provide members ...",
      "online": 223,
      "members": 223,
      "image": "https://picsum.photos/400/200?random=1",
    },
    {
      "name": "Fernando's Group",
      "description":
          "A cooperative savings group committed to pooling resources to provide members ...",
      "online": 223,
      "members": 223,
      "image": "https://picsum.photos/400/200?random=2",
    },
    {
      "name": "Fernando's Group",
      "description":
          "A cooperative savings group committed to pooling resources to provide members ...",
      "online": 223,
      "members": 223,
      "image": "https://picsum.photos/400/200?random=3",
    },
    {
      "name": "Fernando's Group",
      "description":
          "A cooperative savings group committed to pooling resources to provide members ...",
      "online": 223,
      "members": 223,
      "image": "https://picsum.photos/400/200?random=4",
    },
  ];
}
