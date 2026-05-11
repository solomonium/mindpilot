import 'dart:async';

import '../export.dart';

class CustomButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final bool isOutline;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final double? width;
  final bool fullWidth;
  final bool loading;

  const CustomButton({
    super.key,
    required this.label,
    this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.isOutline = false,
    this.fontSize,
    this.padding,
    this.height = 48,
    this.width,
    this.fullWidth = false,
    this.loading = false,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  bool _isDebouncing = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus != _isFocused) {
        setState(() => _isFocused = _focusNode.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleOnPressed() {
    if (!_isDebouncing) {
      _isDebouncing = true;
      widget.onPressed?.call();

      Timer(const Duration(seconds: 5), () {
        if (mounted) {
          _isDebouncing = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    final defaultPrimaryColor = theme.primaryBase;
    final finalWidth = widget.fullWidth ? double.infinity : widget.width;

    if (widget.isOutline) {
      final borderCol =
          widget.borderColor ?? widget.backgroundColor ?? defaultPrimaryColor;
      final textCol = widget.textColor ?? borderCol;

      return SizedBox(
        height: widget.height,
        width: finalWidth,
        child: OutlinedButton(
          focusNode: _focusNode,
          onPressed: widget.loading
              ? null
              : (widget.onPressed != null ? _handleOnPressed : null),
          style: OutlinedButton.styleFrom(
            foregroundColor: borderCol,
            side: BorderSide(color: borderCol, width: 1.5),
            padding:
                widget.padding ?? const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: widget.loading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: borderCol,
                  ),
                )
              : PrimaryText(
                  text: widget.label,
                  fontSize: widget.fontSize ?? 18,
                  fontWeight: FontWeight.bold,
                  color: textCol,
                ),
        ),
      );
    }

    final bgCol = widget.backgroundColor ?? defaultPrimaryColor;
    final textCol = widget.textColor ?? theme.whiteBackground;

    return SizedBox(
      height: widget.height,
      width: finalWidth,
      child: ElevatedButton(
        focusNode: _focusNode,
        onPressed: widget.loading
            ? null
            : (widget.onPressed != null ? _handleOnPressed : null),
        style: ElevatedButton.styleFrom(
          backgroundColor: bgCol,
          foregroundColor: textCol,
          padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: widget.borderColor != null
                ? BorderSide(color: widget.borderColor!, width: 1.5)
                : BorderSide.none,
          ),
          elevation: 0,
        ),
        child: widget.loading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: textCol,
                ),
              )
            : SecondaryText(
                text: widget.label,
                fontSize: widget.fontSize ?? 18,
                color: textCol,
              ),
      ),
    );
  }
}
