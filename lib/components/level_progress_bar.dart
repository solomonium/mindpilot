import 'package:mindpilot/export.dart';

class LevelProgressBar extends StatelessWidget {
  final int xp;
  final int level;

  const LevelProgressBar({
    super.key,
    required this.xp,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    final service = EngagementService();
    final progress = service.xpProgressInLevel(xp);
    final toNext = service.xpToNextLevel(xp);
    final fraction = progress / EngagementService.xpPerLevel;

    return GlassContainer(
      padding: const EdgeInsets.all(14),
      gradient: theme.glassGradient,
      border: Border.all(color: theme.primaryBase.withOpacity(0.2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.stars, color: const Color(0xFFF59E0B), size: 18),
                  8.horizontalSpace,
                  PrimaryText(
                    text: 'Level $level',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.accentTxt,
                  ),
                ],
              ),
              SecondaryText(
                text: '$toNext XP to Level ${level + 1}',
                fontSize: 11,
                color: theme.accentTxt.withOpacity(0.6),
              ),
            ],
          ),
          10.verticalSpace,
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: theme.accentTxt.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryBase),
            ),
          ),
        ],
      ),
    );
  }
}
