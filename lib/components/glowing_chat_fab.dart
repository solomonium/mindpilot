import 'package:mindpilot/export.dart';

class GlowingChatFab extends StatefulWidget {
  const GlowingChatFab({super.key});

  @override
  State<GlowingChatFab> createState() => _GlowingChatFabState();
}

class _GlowingChatFabState extends State<GlowingChatFab> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
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
              child: const Icon(Icons.psychology, color: Colors.white, size: 30),
            ),
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.star, color: Colors.white, size: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
