import 'package:flutter/material.dart';

class CustomContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? color;
  final BoxDecoration? decoration;
  final AlignmentGeometry? alignment;
  final BoxConstraints? constraints;
  final Clip clipBehavior;
  final double? borderRadius;
  final Border? border;
  final VoidCallback? onTap;

  const CustomContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.color,
    this.decoration,
    this.alignment,
    this.constraints,
    this.clipBehavior = Clip.none,
    this.borderRadius,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      width: width,
      height: height,
      margin: margin,
      alignment: alignment,
      constraints: constraints,
      clipBehavior: clipBehavior,
      padding: padding ?? const EdgeInsets.all(24),
      decoration: decoration ??
          BoxDecoration(
            color: color ?? Colors.white,
            borderRadius: BorderRadius.circular(borderRadius ?? 16),
            border: border ??
                Border.all(
                  color: Colors.grey.withOpacity(0.15),
                  width: 1.5,
                ),
          ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}
