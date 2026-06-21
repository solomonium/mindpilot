import 'package:mindpilot/export.dart';

class GuidedFirstSessionBanner extends StatelessWidget {
  final List<String> personalization;

  const GuidedFirstSessionBanner({
    super.key,
    required this.personalization,
  });

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    final action = EngagementService().primaryGoalAction(personalization);

    final config = _configForAction(action);

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      gradient: LinearGradient(
        colors: [
          config.color.withOpacity(0.25),
          theme.primaryBase.withOpacity(0.1),
        ],
      ),
      border: Border.all(color: config.color.withOpacity(0.4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: config.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(config.icon, color: config.color, size: 22),
              ),
              12.horizontalSpace,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PrimaryText(
                      text: 'Your first win',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.accentTxt,
                    ),
                    4.verticalSpace,
                    SecondaryText(
                      text: config.subtitle,
                      fontSize: 12,
                      color: theme.accentTxt.withOpacity(0.7),
                    ),
                  ],
                ),
              ),
            ],
          ),
          16.verticalSpace,
          CustomButton(
            label: config.buttonLabel,
            onPressed: () => _startSession(context, action),
            backgroundColor: config.color,
          ),
        ],
      ),
    );
  }

  void _startSession(BuildContext context, String action) {
    switch (action) {
      case 'decision':
        context.read<HomeProvider>().navIndex = 3;
        break;
      case 'journal':
        context.push(const JournalEntriesScreen());
        break;
      case 'focus':
      default:
        context.read<HomeProvider>().navIndex = 1;
        final focus = context.read<FocusProvider>();
        if (!focus.isRunning) {
          focus.selectedMinutes = 5;
        }
        break;
    }
  }

  _BannerConfig _configForAction(String action) {
    switch (action) {
      case 'decision':
        return _BannerConfig(
          icon: Icons.lightbulb_outline,
          color: const Color(0xFF6366F1),
          subtitle: 'Analyze one small decision to unlock your clarity journey.',
          buttonLabel: 'Analyze a Decision',
        );
      case 'journal':
        return _BannerConfig(
          icon: Icons.edit_note,
          color: const Color(0xFFEF4444),
          subtitle: 'Write a quick journal line about how you feel today.',
          buttonLabel: 'Write First Entry',
        );
      case 'focus':
      default:
        return _BannerConfig(
          icon: Icons.timer_outlined,
          color: const Color(0xFF10B981),
          subtitle: 'Start a 5-minute focus session and build momentum.',
          buttonLabel: 'Start 5-Min Focus',
        );
    }
  }
}

class _BannerConfig {
  final IconData icon;
  final Color color;
  final String subtitle;
  final String buttonLabel;

  _BannerConfig({
    required this.icon,
    required this.color,
    required this.subtitle,
    required this.buttonLabel,
  });
}
