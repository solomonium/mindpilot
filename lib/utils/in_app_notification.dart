import 'dart:async';

import 'package:flutter/material.dart';

enum InAppNotificationType { error, info, success }

@visibleForTesting
const notificationShowingDuration = Duration(milliseconds: 350);

/// A views for display foreground notification.
///
/// It is mainly intended to be inserted in the `builder` of [WidgetsApp].
///
/// {@tool snippet}
/// Usage example:
///
/// ```dart
/// return MaterialApp(
///   home: Home(),
///   builder: (context, child) => InAppNotification(
///     safeAreaPadding: MediaQuery.of(context).viewPadding,
///     child: child,
///   ),
/// );
/// ```
/// {@end-tool}
class InAppNotification extends StatefulWidget {
  /// Creates an in-app notification system.
  ///
  /// The [safeAreaPadding] must not be null.
  const InAppNotification({
    required this.safeAreaPadding,
    this.child,
    this.minAlertHeight = 120.0,
    super.key,
  });

  final Widget? child;

  /// The value of padding for something that narrows the view port,
  /// like The Notch on the iPhone X family.
  ///
  /// Usually, this would be `viewPadding` of `MediaQueryData`.
  final EdgeInsets safeAreaPadding;

  /// The value at minimal height of notification.
  ///
  /// The default value is 120.0.
  final double minAlertHeight;

  static InAppNotificationState? of(BuildContext context) =>
      context.findAncestorStateOfType<InAppNotificationState>();

  @override
  InAppNotificationState createState() => InAppNotificationState();
}

class InAppNotificationState extends State<InAppNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _alertAnimation;

  Timer? _timer;
  Widget? _body;
  VoidCallback? _onTap;
  double _initialPosition = 0.0;
  double _dragDistance = 0.0;

  double get _currentPosition => _alertAnimation.value + _dragDistance;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
      reverseDuration: const Duration(milliseconds: 280),
    );

    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
      reverseCurve: Curves.easeInCubic,
    );

    _initialPosition =
        -(widget.minAlertHeight + widget.safeAreaPadding.top + 30);

    _alertAnimation = Tween<double>(
      begin: _initialPosition,
      end: 0.0,
    ).animate(curve);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Shows specified Widget as notification.
  ///
  /// [child] is required, this will be displayed as notification body.
  ///
  /// Showing and hiding notifications is managed by animation,
  /// and the process is as follows.
  ///
  /// 1. Execute this method, start animation.
  /// 2. Then the notification appear, it will stay at specified [duration].
  /// 3. After the [duration] has elapsed,
  ///    play the animation in reverse and dispose the notification.
  Future<void> show({
    required Widget child,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 10),
  }) async {
    _timer?.cancel();

    if (_controller.isCompleted) {
      await dismiss();
    }

    setState(() {
      _dragDistance = 0.0;
      _body = child;
      _onTap = onTap;
    });
    _controller.forward(from: 0.0);
    if (duration.inMicroseconds == 0) return;
    _timer = Timer(duration, () => dismiss());
  }

  Future dismiss({double? from}) async {
    _timer?.cancel();
    await _controller.reverse(from: from ?? 1.0);
    setState(() => _body = null);
  }

  void _onTapNotification() {
    if (_onTap == null) return;
    dismiss();
    _onTap?.call();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragDistance = (_dragDistance + details.delta.dy).clamp(
        _initialPosition,
        0.0,
      );
    });
  }

  void _onVerticalDragEnd() {
    final percentage = 1.0 - _currentPosition.abs() / _initialPosition.abs();
    if (percentage >= 0.4) {
      if (_dragDistance == 0.0) return;
      setState(() {
        _dragDistance = 0.0;
      });
      _controller.forward(from: percentage);
    } else {
      dismiss(from: percentage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child ?? const SizedBox(),
        AnimatedBuilder(
          animation: _alertAnimation,
          builder: (context, _) {
            return Positioned(
              top: _currentPosition,
              left: 0,
              right: 0,
              child: GestureDetector(
                onVerticalDragUpdate: _onVerticalDragUpdate,
                onVerticalDragEnd: (detail) => _onVerticalDragEnd(),
                onTapUp: (_) => _onTapNotification(),
                child: Padding(
                  padding: EdgeInsets.only(
                    top: widget.safeAreaPadding.top,
                    left: 12,
                    right: 12,
                  ),
                  child: Center(
                    child: Material(
                      elevation: 10,
                      borderRadius: BorderRadius.circular(20),
                      clipBehavior: Clip.antiAlias,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          // minHeight: widget.minAlertHeight,
                        ),
                        child: _body ?? const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
