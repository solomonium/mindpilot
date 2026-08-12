import 'package:mindpilot/export.dart';

typedef PageBuilder = Widget Function();

class RouteHelper {
  static const double kDefaultDuration = .35;
  static const Curve kDefaultEaseFwd = Curves.bounceInOut;
  static const Curve kDefaultEaseReverse = Curves.bounceInOut;

  static Route<T> fade<T>(
    PageBuilder pageBuilder, [
    double duration = kDefaultDuration,
  ]) {
    final page = pageBuilder();
    return PageRouteBuilder<T>(
      settings: RouteSettings(name: page.runtimeType.toString()),
      transitionDuration: Duration(milliseconds: (duration * 100).round()),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  static Route<T> fadeThrough<T>(
    PageBuilder pageBuilder, [
    double duration = kDefaultDuration,
  ]) {
    final page = pageBuilder();
    return PageRouteBuilder<T>(
      settings: RouteSettings(name: page.runtimeType.toString()),
      transitionDuration: Duration(milliseconds: (duration * 5000).round()),
      reverseTransitionDuration: Duration(
        milliseconds: (duration * 5000).round(),
      ),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeThroughTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        );
      },
    );
  }

  static Route<T> fadeScale<T>(
    PageBuilder pageBuilder, [
    double duration = kDefaultDuration,
  ]) {
    final page = pageBuilder();
    return PageRouteBuilder<T>(
      settings: RouteSettings(name: page.runtimeType.toString()),
      transitionDuration: Duration(milliseconds: (duration * 100).round()),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeScaleTransition(
            animation: animation,
            child: Overlay(
              initialEntries: [OverlayEntry(builder: (context) => child)],
            ),
          ),
    );
  }

  static Route<T> sharedAxis<T>(
    PageBuilder pageBuilder, [
    SharedAxisTransitionType type = SharedAxisTransitionType.scaled,
    double duration = kDefaultDuration,
  ]) {
    final page = pageBuilder();
    return PageRouteBuilder<T>(
      settings: RouteSettings(name: page.runtimeType.toString()),
      transitionDuration: Duration(milliseconds: (duration * 200).round()),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: type,
          child: child,
        );
      },
    );
  }

  static Route<T> slide<T>(
    PageBuilder pageBuilder, {
    double duration = kDefaultDuration,
    Offset startOffset = const Offset(1, 0),
    Curve easeFwd = kDefaultEaseFwd,
    Curve easeReverse = kDefaultEaseReverse,
  }) {
    final page = pageBuilder();
    return PageRouteBuilder<T>(
      settings: RouteSettings(name: page.runtimeType.toString()),
      transitionDuration: Duration(milliseconds: (duration * 100).round()),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        bool reverse = animation.status == AnimationStatus.reverse;
        return SlideTransition(
          position: Tween<Offset>(begin: startOffset, end: const Offset(0, 0))
              .animate(
                CurvedAnimation(
                  parent: animation,
                  curve: reverse ? easeReverse : easeFwd,
                ),
              ),
          child: child,
        );
      },
    );
  }

  static Route<T> slideFromBottomRight<T>(
    PageBuilder pageBuilder, {
    double duration = kDefaultDuration,
    Curve easeFwd = Curves.easeOutQuart, // Smooth forward animation
    Curve easeReverse = Curves.bounceInOut, // Smooth reverse animation
  }) {
    final page = pageBuilder();
    return PageRouteBuilder<T>(
      settings: RouteSettings(name: page.runtimeType.toString()),
      transitionDuration: Duration(milliseconds: (duration * 2000).round()),
      reverseTransitionDuration: Duration(
        milliseconds: (duration * 5000).round(),
      ),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slideAnimation =
            Tween<Offset>(
              begin: const Offset(1, 1), // Start from the bottom-right corner
              end: Offset
                  .zero, // End at the default position (center of the screen)
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: easeFwd,
                reverseCurve: easeReverse,
              ),
            );

        return SlideTransition(position: slideAnimation, child: child);
      },
    );
  }

  static Route<T> enhancedSlide<T>(
    PageBuilder pageBuilder, {
    double duration = kDefaultDuration,
    Offset startOffset = const Offset(1, 0),
    Curve easeFwd = Curves.slowMiddle,
    Curve easeReverse = Curves.elasticOut,
  }) {
    final page = pageBuilder();
    return PageRouteBuilder<T>(
      settings: RouteSettings(name: page.runtimeType.toString()),
      transitionDuration: Duration(milliseconds: (duration * 3000).round()),
      reverseTransitionDuration: Duration(
        milliseconds: (duration * 3000).round(),
      ),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Add a scale effect to the slide animation
        final slideAnimation =
            Tween<Offset>(
              begin: const Offset(1, 1), // Start from the bottom-right corner
              end: Offset
                  .zero, // End at the default position (center of the screen)
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: easeFwd,
                reverseCurve: easeReverse,
              ),
            );

        final scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: easeFwd,
            reverseCurve: easeReverse,
          ),
        );

        return SlideTransition(
          position: slideAnimation,
          child: ScaleTransition(scale: scaleAnimation, child: child),
        );
      },
    );
  }
}
