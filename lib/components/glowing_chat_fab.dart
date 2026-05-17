import 'package:mindpilot/export.dart';

class GlowingChatFab extends StatefulWidget {
  const GlowingChatFab({super.key});

  @override
  State<GlowingChatFab> createState() => _GlowingChatFabState();
}

class _GlowingChatFabState extends State<GlowingChatFab>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _textController;
  late Animation<double> _animation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _textController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _rotationAnimation = Tween<double>(begin: -0.1, end: 0.1).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeInOutSine),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _textController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    return ScaleTransition(
      scale: _animation,
      child: GestureDetector(
        onTap: () => context.push(const AiChatScreen()),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: theme.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryBase.withOpacity(0.5),
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: RotationTransition(
                  turns: _rotationAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: const [
                          Color(0xFFBF953F), // Deep Gold
                          Color(0xFFFCF6BA), // Shimmer White
                          Color(0xFFB38728), // Goldenrod
                          Color(0xFFFBF5B7), // Bright Gold
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: PrimaryText(
                        text: 'ASK',
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Consumer2<NotificationProvider, AppAuthProvider>(
              builder: (context, notifStore, authStore, _) {
                final isPro = authStore.isPro;

                // Don't show the badge if it's already expanded or if there's no insight
                if (notifStore.dailyInsight.isEmpty ||
                    notifStore.dailyInsight == '...')
                  return const SizedBox();

                return Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () async {
                      if (notifStore.isFetchingExplanation) return;

                      if (!isPro && authStore.explanationCount >= 3) {
                        AppHelper.showPaywall(
                          context,
                          feature: 'Daily Explanation',
                        );
                        return;
                      }

                      await notifStore.fetchInsightExplanation();

                      if (context.mounted &&
                          notifStore.fetchError == null &&
                          notifStore.insightExplanation != null &&
                          !isPro) {
                        await authStore.incrementExplanationCount();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.brandDark, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(1, 1),
                          ),
                        ],
                      ),
                      child: notifStore.isFetchingExplanation
                          ? const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.psychology,
                              color: Colors.white,
                              size: 12,
                            ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
