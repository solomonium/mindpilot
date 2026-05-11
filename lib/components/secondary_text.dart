import 'package:mindpilot/export.dart';

class SecondaryText extends StatelessWidget {
  final Color? color;
  final String text;
  final double? fontSize;
  final FontWeight? fontWeight;
  final TextOverflow? textOverflow;
  final TextAlign? textAlign;

  final int? maxLines;
  final double? letterSpacing;

  const SecondaryText({
    super.key,
    this.color,
    required this.text,
    this.fontSize,
    this.fontWeight,
    this.textOverflow,
    this.textAlign,
    this.maxLines,
    this.letterSpacing,
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
        color: color ?? theme.secondaryTxt,
        fontSize: fontSize ?? 14.0,
        fontWeight: fontWeight ?? FontWeight.w400,
        letterSpacing: letterSpacing,
      ),
    );
  }
}
