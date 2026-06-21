import 'package:mindpilot/export.dart';

class DailyQuestsCard extends StatelessWidget {
  const DailyQuestsCard({super.key});

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    final auth = context.watch<AppAuthProvider>();
    final chat = context.watch<ChatProvider>();
    final isPro = auth.isPro;

    final chatUsed = chat.dailyMessageCount;
    final chatLimit = chat.freemiumLimit;
    final decisionsUsed = 3 - auth.decisionCredits;
    final explanationsUsed = auth.explanationCount;

    final quests = [
      _QuestData(
        label: 'AI Chat',
        icon: Icons.chat_bubble_outline,
        progress: isPro ? 1.0 : (chatUsed / chatLimit).clamp(0.0, 1.0),
        subtitle: isPro ? 'Unlimited' : '$chatUsed / $chatLimit messages',
        complete: isPro || chatUsed >= chatLimit,
      ),
      _QuestData(
        label: 'Decisions',
        icon: Icons.psychology_outlined,
        progress: isPro ? 1.0 : (decisionsUsed / 3).clamp(0.0, 1.0),
        subtitle: isPro ? 'Unlimited' : '$decisionsUsed / 3 analyses',
        complete: isPro || decisionsUsed >= 3,
      ),
      _QuestData(
        label: 'Insight Explain',
        icon: Icons.lightbulb_outline,
        progress: isPro ? 1.0 : (explanationsUsed / 3).clamp(0.0, 1.0),
        subtitle: isPro ? 'Unlimited' : '$explanationsUsed / 3 explains',
        complete: isPro || explanationsUsed >= 3,
      ),
    ];

    final completedCount = quests.where((q) => q.complete).length;
    final allComplete = completedCount == quests.length;

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      gradient: theme.glassGradient,
      border: Border.all(color: theme.primaryBase.withOpacity(0.25)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.flag_outlined, color: theme.primaryBase, size: 20),
                  8.horizontalSpace,
                  PrimaryText(
                    text: 'Daily Clarity Pack',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.accentTxt,
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: allComplete
                      ? theme.successPrimary.withOpacity(0.2)
                      : theme.primaryBase.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SecondaryText(
                  text: '$completedCount/3',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: allComplete ? theme.successPrimary : theme.primaryBase,
                ),
              ),
            ],
          ),
          8.verticalSpace,
          SecondaryText(
            text: allComplete
                ? 'Pack complete! +15 XP earned for finishing strong.'
                : 'Complete your daily pack to earn bonus XP and stay sharp.',
            fontSize: 11,
            color: theme.accentTxt.withOpacity(0.6),
          ),
          16.verticalSpace,
          ...quests.map((q) => _questRow(theme, q)),
          if (!isPro && !allComplete) ...[
            12.verticalSpace,
            SecondaryText(
              text: 'Need more? Watch a short ad for bonus credits.',
              fontSize: 10,
              color: theme.accentTxt.withOpacity(0.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _questRow(AppTheme theme, _QuestData quest) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            quest.complete ? Icons.check_circle : quest.icon,
            color: quest.complete ? theme.successPrimary : theme.accentTxt.withOpacity(0.5),
            size: 18,
          ),
          10.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    PrimaryText(
                      text: quest.label,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.accentTxt.withOpacity(quest.complete ? 0.6 : 1),
                    ),
                    SecondaryText(
                      text: quest.subtitle,
                      fontSize: 10,
                      color: theme.accentTxt.withOpacity(0.5),
                    ),
                  ],
                ),
                6.verticalSpace,
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: quest.progress,
                    minHeight: 4,
                    backgroundColor: theme.accentTxt.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      quest.complete ? theme.successPrimary : theme.primaryBase,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestData {
  final String label;
  final IconData icon;
  final double progress;
  final String subtitle;
  final bool complete;

  _QuestData({
    required this.label,
    required this.icon,
    required this.progress,
    required this.subtitle,
    required this.complete,
  });
}
