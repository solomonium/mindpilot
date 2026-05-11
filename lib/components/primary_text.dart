import 'package:mindpilot/export.dart';

class PrimaryText extends StatelessWidget {
  final Color? color;
  final String text;
  final double? fontSize;
  final FontWeight? fontWeight;
  final TextOverflow? textOverflow;
  final TextAlign? textAlign;

  final int? maxLines;
  final double? letterSpacing;
  final double? height;
  final TextDecoration? decoration;

  const PrimaryText({
    super.key,
    this.color,
    required this.text,
    this.fontSize,
    this.fontWeight,
    this.textOverflow,
    this.textAlign,
    this.maxLines,
    this.letterSpacing,
    this.height,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();

    return Text(
      text,
      overflow: textOverflow,
      textAlign: textAlign,
      maxLines: maxLines,
      style: GoogleFonts.inter(
        color: color ?? theme.foundationColor,
        fontSize: fontSize ?? 17.0,
        fontWeight: fontWeight ?? FontWeight.w600,
        letterSpacing: letterSpacing,
        height: height,
        decoration: decoration,
      ),
    );
  }
}
