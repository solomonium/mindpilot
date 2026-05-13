import 'package:mindpilot/export.dart';

class PersonalizationScreen extends StatefulWidget {
  const PersonalizationScreen({super.key});

  @override
  State<PersonalizationScreen> createState() => _PersonalizationScreenState();
}

class _PersonalizationScreenState extends State<PersonalizationScreen> {
  final List<Map<String, dynamic>> goals = [
    {
      "title": "Make Better Decisions",
      "subtitle": "Get clarity on important life choices",
      "icon": Icons.lightbulb_outline,
      "color": const Color(0xFF6366F1),
    },
    {
      "title": "Be More Productive",
      "subtitle": "Build habits and improve focus",
      "icon": Icons.bolt_outlined,
      "color": const Color(0xFF3B82F6),
    },
    {
      "title": "Improve Mental Wellbeing",
      "subtitle": "Reduce stress and anxiety",
      "icon": Icons.favorite_border,
      "color": const Color(0xFFEF4444),
    },
    {
      "title": "Personal Growth",
      "subtitle": "Learn, grow and become better",
      "icon": Icons.trending_up,
      "color": const Color(0xFF10B981),
    },
    {
      "title": "Financial Clarity",
      "subtitle": "Manage money and plan better",
      "icon": Icons.account_balance_wallet_outlined,
      "color": const Color(0xFFF59E0B),
    },
  ];

  int selectedGoal = -1;

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    return Scaffold(
      backgroundColor: theme.brandDark,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.6,
              child: Image.asset(R.png.loginBg.png, fit: BoxFit.cover),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.brandDark.withOpacity(0.4),
                    theme.brandDark.withOpacity(0.8),
                    theme.brandDark,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  20.verticalSpace,
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _finishPersonalization(),
                      child: SecondaryText(text: 'Skip', color: theme.accentTxt.withOpacity(0.6)),
                    ),
                  ),
                  20.verticalSpace,
                  PrimaryText(
                    text: "Let's Personalize",
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    textAlign: TextAlign.center,
                    color: theme.accentTxt,
                  ),
                  8.verticalSpace,
                  SecondaryText(
                    text: "What are your main goals?\nYou can change these later.",
                    textAlign: TextAlign.center,
                    color: theme.accentTxt.withOpacity(0.7),
                  ),
                  40.verticalSpace,
                  Expanded(
                    child: ListView.separated(
                      itemCount: goals.length,
                      separatorBuilder: (context, index) => 16.verticalSpace,
                      itemBuilder: (context, index) {
                        final goal = goals[index];
                        final isSelected = selectedGoal == index;
                        return _goalTile(goal, isSelected, () {
                          setState(() => selectedGoal = index);
                        });
                      },
                    ),
                  ),
                  24.verticalSpace,
                  CustomButton(
                    label: 'Continue',
                    onPressed: selectedGoal != -1 ? () => _finishPersonalization() : null,
                    backgroundColor: theme.primaryBase,
                  ),
                  40.verticalSpace,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _finishPersonalization() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('HAS_SEEN_PERSONALIZATION', true);
    if (mounted) {
      context.pushOff(const LoginScreen());
    }
  }

  Widget _goalTile(Map<String, dynamic> goal, bool isSelected, VoidCallback onTap) {
    AppTheme theme = context.watch();
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      gradient: isSelected ? null : theme.glassGradient,
      color: isSelected ? theme.primaryBase.withOpacity(0.2) : null,
      border: isSelected ? Border.all(color: theme.primaryBase, width: 2) : null,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: goal['color'].withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(goal['icon'], color: goal['color']),
          ),
          16.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PrimaryText(
                  text: goal['title'], 
                  fontSize: 16, 
                  fontWeight: FontWeight.w600,
                  color: theme.accentTxt,
                ),
                SecondaryText(
                  text: goal['subtitle'], 
                  fontSize: 12,
                  color: theme.accentTxt.withOpacity(0.6),
                ),
              ],
            ),
          ),
          if (isSelected)
            Icon(Icons.check_circle, color: theme.primaryBase, size: 24),
        ],
      ),
    ).rippleClick(onTap);
  }
}
