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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => context.pushOff(const MainScreen()),
            child: SecondaryText(text: 'Skip', color: theme.primaryBase),
          ),
          20.horizontalSpace,
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PrimaryText(
                text: "Let's Personalize",
                fontSize: 24,
                fontWeight: FontWeight.bold,
                textAlign: TextAlign.center,
              ),
              8.verticalSpace,
              SecondaryText(
                text: "What are your main goals?\nYou can change these later.",
                textAlign: TextAlign.center,
              ),
              32.verticalSpace,
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
                onPressed: selectedGoal != -1 ? () => context.pushOff(const MainScreen()) : null,
                backgroundColor: theme.primaryBase,
              ),
              20.verticalSpace,
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (index) => Container(
                    width: index == 1 ? 12 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: index == 1 ? theme.primaryBase : Colors.grey[300],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  )),
                ),
              ),
              20.verticalSpace,
            ],
          ),
        ),
      ),
    );
  }

  Widget _goalTile(Map<String, dynamic> goal, bool isSelected, VoidCallback onTap) {
    AppTheme theme = context.watch();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected ? theme.primaryBase.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? theme.primaryBase : Colors.grey[200]!,
          width: isSelected ? 2 : 1,
        ),
      ),
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
                PrimaryText(text: goal['title'], fontSize: 16, fontWeight: FontWeight.w600),
                SecondaryText(text: goal['subtitle'], fontSize: 12),
              ],
            ),
          ),
        ],
      ),
    ).rippleClick(onTap);
  }
}
