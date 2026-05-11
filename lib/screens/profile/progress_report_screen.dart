import 'package:mindpilot/export.dart';

class ProgressReportScreen extends StatelessWidget {
  const ProgressReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    return Consumer2<JournalProvider, TaskProvider>(
      builder: (context, journal, taskStore, _) {
        // Calculate dynamic values
        final taskRate = taskStore.totalCount > 0 ? taskStore.completedCount / taskStore.totalCount : 0.0;
        final focusScore = (journal.totalFocusMinutes / 120).clamp(0.0, 1.0); // Goal: 2 hours
        final overallGrowth = ((taskRate * 0.6) + (focusScore * 0.4)) * 100;
        
        // Focus areas
        final decisionScore = (journal.entries.length / 10).clamp(0.0, 1.0); // Goal: 10 decisions
        final productivityScore = taskRate;
        final wellbeingScore = (journal.entries.where((e) => e.mood.contains('😊')).length / (journal.entries.isEmpty ? 1 : journal.entries.length)).clamp(0.4, 1.0);
        final consistencyScore = (journal.totalFocusMinutes > 0 ? 0.8 : 0.2); // Simple logic for now

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: PrimaryText(
              text: 'Growth Progress',
              color: theme.accentTxt,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            centerTitle: true,
            leading: Icon(
              Icons.arrow_back_ios,
              color: theme.accentTxt,
              size: 20,
            ).rippleClick(() => context.pop()),
          ),
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
              SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: theme.primaryGradient,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: theme.primaryBase.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SecondaryText(text: 'Overall Growth', color: Colors.white70, fontSize: 12),
                          8.verticalSpace,
                          PrimaryText(
                            text: '${overallGrowth.toInt()}%',
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                          16.verticalSpace,
                          SecondaryText(
                            text: overallGrowth > 50 
                                ? "Keep going, you're doing great!" 
                                : "Every small step counts towards clarity.",
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                          20.verticalSpace,
                          SizedBox(
                            height: 60,
                            width: double.infinity,
                            child: CustomPaint(painter: ChartPainter()),
                          ),
                        ],
                      ),
                    ),
                    32.verticalSpace,
                    PrimaryText(text: 'Focus Areas', fontSize: 18, fontWeight: FontWeight.bold, color: theme.accentTxt),
                    20.verticalSpace,
                    _focusArea(context, 'Decision Clarity', decisionScore, '${(decisionScore * 100).toInt()}%'),
                    _focusArea(context, 'Productivity', productivityScore, '${(productivityScore * 100).toInt()}%'),
                    _focusArea(context, 'Mindfulness', wellbeingScore, '${(wellbeingScore * 100).toInt()}%'),
                    _focusArea(context, 'Consistency', consistencyScore, '${(consistencyScore * 100).toInt()}%'),
                    32.verticalSpace,
                    PrimaryText(text: 'Insights', fontSize: 18, fontWeight: FontWeight.bold, color: theme.accentTxt),
                    16.verticalSpace,
                    _insightItem(
                      context,
                      Icons.lightbulb_outline,
                      taskStore.completedCount > 0 
                          ? 'You\'ve finished ${taskStore.completedCount} tasks today!' 
                          : 'Start a task to boost your productivity score.',
                      const Color(0xFFF59E0B),
                    ),
                    _insightItem(
                      context,
                      Icons.timer_outlined,
                      journal.totalFocusMinutes > 0 
                          ? 'Total focus time: ${journal.totalFocusMinutes} minutes.' 
                          : 'Use Focus Session to improve concentration.',
                      const Color(0xFF10B981),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _focusArea(BuildContext context, String label, double value, String percentage) {
    AppTheme theme = context.watch();
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SecondaryText(text: label, fontSize: 13, color: theme.accentTxt.withOpacity(0.8)),
              PrimaryText(text: percentage, color: theme.accentTxt, fontSize: 13, fontWeight: FontWeight.bold),
            ],
          ),
          8.verticalSpace,
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: theme.accentTxt.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryBase),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightItem(BuildContext context, IconData icon, String text, Color color) {
    AppTheme theme = context.watch();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.background.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.accentTxt.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          16.horizontalSpace,
          Expanded(child: SecondaryText(text: text, fontSize: 13, color: theme.accentTxt.withOpacity(0.9))),
        ],
      ),
    );
  }
}

class ChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.3)..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(0, size.height * 0.8)..quadraticBezierTo(size.width * 0.2, size.height * 0.9, size.width * 0.4, size.height * 0.5)..quadraticBezierTo(size.width * 0.6, size.height * 0.2, size.width * 0.8, size.height * 0.4)..lineTo(size.width, 0);
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
