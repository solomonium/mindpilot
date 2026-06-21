import 'dart:ui';
import 'package:mindpilot/export.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final double borderRadius;
  final BorderRadius? customBorderRadius;
  final double blur;
  final double opacity;
  final LinearGradient? gradient;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Border? border;
  final Color? color;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.blur = 10,
    this.opacity = 0.1,
    this.gradient,
    this.padding,
    this.margin,
    this.border,
    this.width,
    this.height,
    this.customBorderRadius,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    final effectiveRadius =
        customBorderRadius ?? BorderRadius.circular(borderRadius);

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: effectiveRadius,
              border:
                  border ??
                  Border.all(
                    color: theme.accentTxt.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
              color: color,
              gradient: color != null
                  ? null
                  : (gradient ??
                        LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.accentTxt.withValues(alpha: opacity * 2),
                            theme.accentTxt.withValues(alpha: opacity),
                          ],
                        )),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
