import 'package:mindpilot/export.dart';

enum ShareableCardMode { streak, progress, insight, tasks, chat }

class ShareableCard extends StatelessWidget {
  final ShareableCardMode mode;
  final String? userName;
  final int? streak;
  final String? focusTime;
  final String? tasksDone;
  final String? achievement;
  final String? insightTitle;
  final String? insightContent;
  final String? insightExplanation;
  final List<String>? tasks;
  final String? chatUserMessage;
  final String? chatAiResponse;
  final String? author;

  const ShareableCard({
    super.key,
    required this.mode,
    this.userName,
    this.streak,
    this.focusTime,
    this.tasksDone,
    this.achievement,
    this.insightTitle,
    this.insightContent,
    this.insightExplanation,
    this.tasks,
    this.chatUserMessage,
    this.chatAiResponse,
    this.author,
  });

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    
    return Container(
      width: 400,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.brandDark,
        image: DecorationImage(
          image: AssetImage(R.png.loginBg.png),
          fit: BoxFit.cover,
          opacity: 0.4,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.15),
              Colors.white.withOpacity(0.05),
            ],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ColorFilter.mode(
              Colors.black.withOpacity(0.2),
              BlendMode.darken,
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App Branding
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        R.png.mindpilotApp.png,
                        height: 40,
                        width: 40,
                      ),
                      12.horizontalSpace,
                      PrimaryText(
                        text: 'MINDPILOT',
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ],
                  ),
                  40.verticalSpace,
                  
                  // Main Content
                  if (mode == ShareableCardMode.streak) _buildStreakView(),
                  if (mode == ShareableCardMode.progress) _buildProgressView(theme),
                  if (mode == ShareableCardMode.insight) _buildInsightView(theme),
                  if (mode == ShareableCardMode.tasks) _buildTasksView(theme),
                  if (mode == ShareableCardMode.chat) _buildChatView(theme),
                  
                  40.verticalSpace,
                  
                  // Footer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome, color: Color(0xFFADFF2F), size: 16),
                          8.horizontalSpace,
                          SecondaryText(
                            text: 'Level up your mind with MindPilot',
                            fontSize: 12,
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ],
                      ),
                    ),
                  ),
                  20.verticalSpace,
                  SecondaryText(
                    text: 'mindpilot.app',
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.4),
                    fontWeight: FontWeight.bold,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStreakView() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.local_fire_department,
              size: 150,
              color: Colors.orange.withOpacity(0.2),
            ),
            Column(
              children: [
                PrimaryText(
                  text: '${streak ?? 0}',
                  fontSize: 80,
                  fontWeight: FontWeight.w900,
                  color: Colors.orange,
                ),
                SecondaryText(
                  text: 'DAYS STREAK',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ],
            ),
          ],
        ),
        24.verticalSpace,
        PrimaryText(
          text: 'Consistency is Key! 🔥',
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ],
    );
  }

  Widget _buildProgressView(AppTheme theme) {
    return Column(
      children: [
        PrimaryText(
          text: "Today's Growth",
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        24.verticalSpace,
        _statRow(Icons.access_time, 'Focus Time', focusTime ?? '0m', const Color(0xFF3B82F6)),
        16.verticalSpace,
        _statRow(Icons.check_circle_outline, 'Tasks Done', tasksDone ?? '0/0', const Color(0xFF10B981)),
        16.verticalSpace,
        _statRow(Icons.stars, 'Achievement', achievement ?? 'Level 1', const Color(0xFFF59E0B)),
      ],
    );
  }

  Widget _buildInsightView(AppTheme theme) {
    return Column(
      children: [
        PrimaryText(
          text: insightTitle ?? 'Daily Insight',
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFADFF2F),
          textAlign: TextAlign.center,
        ),
        20.verticalSpace,
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              SecondaryText(
                text: insightContent ?? '',
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
                textAlign: TextAlign.center,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
              8.verticalSpace,
              Align(
                alignment: Alignment.centerRight,
                child: SecondaryText(
                  text: "- ${author ?? "Unknown"}",
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
              if (insightExplanation != null) ...[
                16.verticalSpace,
                _buildHighlightedText(
                  insightExplanation!,
                  const Color(0xFFADFF2F),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightedText(String text, Color baseColor) {
    List<TextSpan> spans = [];
    final RegExp regExp = RegExp(r'\*\*(.*?)\*\*|\*(.*?)\*');
    int lastMatchEnd = 0;

    for (final Match match in regExp.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        );
      }

      String matchedText = match.group(1) ?? match.group(2) ?? '';
      spans.add(
        TextSpan(
          text: matchedText,
          style: GoogleFonts.inter(
            color: baseColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
      );

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastMatchEnd),
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
            height: 1.5,
          ),
        ),
      );
    }

    return RichText(
      text: TextSpan(children: spans),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildTasksView(AppTheme theme) {
    return Column(
      children: [
        PrimaryText(
          text: "Today's Agenda",
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        24.verticalSpace,
        if (tasks != null)
          ...tasks!.take(5).map((task) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Color(0xFFADFF2F), size: 18),
                    12.horizontalSpace,
                    Expanded(
                      child: SecondaryText(
                        text: task,
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  Widget _buildChatView(AppTheme theme) {
    return Column(
      children: [
        PrimaryText(
          text: "Chat Highlight",
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFADFF2F),
        ),
        32.verticalSpace,
        if (chatUserMessage != null) ...[
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(left: 40),
              decoration: BoxDecoration(
                color: theme.primaryBase,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
              child: SecondaryText(
                text: chatUserMessage!,
                fontSize: 14,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ),
          16.verticalSpace,
        ],
        if (chatAiResponse != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(right: 40),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: MarkdownBody(
                data: chatAiResponse!,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                  strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _statRow(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          16.horizontalSpace,
          Expanded(
            child: SecondaryText(
              text: label,
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          PrimaryText(
            text: value,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}
