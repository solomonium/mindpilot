// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

enum ThemeType { light, dark, system }

class AppTheme {
  // static ThemeType defaultTheme = ThemeType.system;
  static ThemeType defaultTheme = ThemeType.light;

  late bool isDark;
  late Color background;
  late Color whiteBackground;
  late Color primaryBase;
  late Color foundationColor;
  late Color foundationColorBlack;
  late Color primaryText;
  late Color secondaryTxt;
  late Color successPrimary;
  late Color successTint;
  late Color successShade;
  late Color errorPrimary;
  late Color purplePrimary;
  late Color errorTint;
  late Color errorShade;
  late Color warningPrimary;
  late Color warningBase;
  late Color warningTint;
  late Color warningShade;
  late Color caption;
  late Color disabled;
  late Color hintText;
  late Color labelText;
  late Color primaryButton;
  late Color txt;
  late Color accentTxt;
  late Color searchFillColor;
  late Color dividerAndBorderColor;
  late Color cardColor;
  late LinearGradient primaryGradient;
  late LinearGradient secondaryGradient;
  late List<BoxShadow> softShadow;
  AppTheme(this.isDark) {
    txt = isDark ? Colors.white : const Color(0xff323B56);
    accentTxt = Colors.white;
  }

  factory AppTheme.fromType(ThemeType t) {
    switch (t) {
      case ThemeType.light:
        return AppTheme(false)
          ..background = const Color(0xFFFFFFFF)
          ..whiteBackground = const Color(0xFFFAFAFA)
          ..primaryBase = const Color(0xFF1170B2)
          ..foundationColor = const Color(0xFF000000)
          ..foundationColorBlack = const Color(0xFF333333)
          ..primaryText = const Color(0xff272624)
          ..secondaryTxt = const Color(0xff808080)
          ..caption = const Color(0xff9E9489)
          ..searchFillColor = const Color(0xffF2F2F2)
          ..disabled = const Color(0xffBAAD9F)
          ..dividerAndBorderColor = const Color(0xffC6C6C9)
          ..successPrimary = const Color(0xff108A00)
          ..successTint = const Color(0xffAFDEC7)
          ..successShade = const Color(0xff05341D)
          ..errorPrimary = const Color(0xffDB4437)
          ..purplePrimary = const Color(0xff6211B2)
          ..errorTint = const Color(0xffF3C1BC)
          ..errorShade = const Color(0xff491712)
          ..warningPrimary = const Color(0xffed8811)
          ..warningBase = const Color(0xffED8811)
          ..warningTint = const Color(0xffF8EFD7)
          ..warningShade = const Color(0xff97541D)
          ..hintText = const Color(0xff8A8A8A)
          ..labelText = const Color(0xff69625A)
          ..primaryButton = const Color(0xFF0061FF)
          ..cardColor = const Color(0xFFFAFAFA)
          ..primaryGradient = const LinearGradient(
            colors: [Color(0xFF0061FF), Color(0xFF00C6FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
          ..secondaryGradient = const LinearGradient(
            colors: [Color(0xffE9AD21), Color(0xffFFD700)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
          ..softShadow = [
            BoxShadow(
              color: const Color(0xFF0061FF).withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ];

      case ThemeType.dark:
        return AppTheme(true)
          ..background = const Color(0xFF1F1F1F)
          ..whiteBackground = const Color(0xFFFFFFFF)
          ..primaryBase = const Color(0xFF1170B2)
          ..foundationColor = const Color(0xFF000000)
          ..primaryText = const Color(0xffEEEEEC)
          ..secondaryTxt = const Color(0xff939489)
          ..caption = const Color(0xffB2B3AD)
          ..disabled = const Color(0xff69625A)
          ..dividerAndBorderColor = const Color(0xff474744)
          ..successPrimary = const Color(0xff0F9D58)
          ..successTint = const Color(0xffAFDEC7)
          ..successShade = const Color(0xff05341D)
          ..errorPrimary = const Color(0xffDB4437)
          ..errorTint = const Color(0xffF3C1BC)
          ..errorShade = const Color(0xff491712)
          ..warningPrimary = const Color(0xffF4B400)
          ..warningBase = const Color(0xffED8811)
          ..warningTint = const Color(0xffF8EFD7)
          ..warningShade = const Color(0xff97541D)
          ..hintText = const Color(0xff9E9489)
          ..labelText = const Color(0xff69625A)
          ..primaryButton = const Color(0xFF0061FF)
          ..cardColor = const Color(0xff181914)
          ..primaryGradient = const LinearGradient(
            colors: [Color(0xFF0061FF), Color(0xFF00A3FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
          ..secondaryGradient = const LinearGradient(
            colors: [Color(0xffE9AD21), Color(0xffCC9900)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
          ..softShadow = [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ];
      case ThemeType.system:
        // Handle system default theme based on the platform
        Brightness platformBrightness =
            WidgetsBinding.instance.window.platformBrightness;
        bool isSystemDark = platformBrightness == Brightness.dark;
        return AppTheme(isSystemDark)
          ..background = isSystemDark
              ? const Color(0xFF1F1F1F)
              : const Color(0xFFF2F2F2)
          ..whiteBackground = isSystemDark
              ? const Color(0xFFFFFFFF)
              : const Color(0xFFFAFAFA)
          ..primaryBase = isSystemDark
              ? const Color(0xff0D99FF)
              : const Color(0xff0D99FF)
          ..foundationColor = isSystemDark
              ? const Color(0xffE9AD21)
              : const Color(0xffE9AD21)
          ..primaryText = isSystemDark
              ? const Color(0xffEEEEEC)
              : const Color(0xff272624)
          ..secondaryTxt = isSystemDark
              ? const Color(0xff939489)
              : const Color(0xff69625A)
          ..caption = isSystemDark
              ? const Color(0xffB2B3AD)
              : const Color(0xff9E9489)
          ..disabled = isSystemDark
              ? const Color(0xff69625A)
              : const Color(0xffBAAD9F)
          ..dividerAndBorderColor = isSystemDark
              ? const Color(0xff474744)
              : const Color(0xffDAD6D2)
          ..successPrimary = const Color(0xff0F9D58)
          ..successTint = const Color(0xffAFDEC7)
          ..successShade = const Color(0xff05341D)
          ..errorPrimary = const Color(0xffDB4437)
          ..errorTint = const Color(0xffF3C1BC)
          ..errorShade = const Color(0xff491712)
          ..warningPrimary = isSystemDark
              ? const Color(0xffF4B400)
              : const Color(0xffed8811)
          ..warningBase = isSystemDark
              ? const Color(0xffED8811)
              : const Color(0xffED8811)
          ..warningTint = const Color(0xffF8EFD7)
          ..warningShade = isSystemDark
              ? const Color(0xff97541D)
              : const Color(0xff97541D)
          ..hintText = const Color(0xff9E9489)
          ..labelText = const Color(0xff69625A)
          ..primaryButton = const Color(0xff0064FF)
          ..cardColor = isSystemDark
              ? const Color(0xff181914)
              : const Color(0xFFFAFAFA)
          ..primaryGradient = isSystemDark
              ? const LinearGradient(
                  colors: [Color(0xFF0061FF), Color(0xFF00A3FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFF0061FF), Color(0xFF00C6FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
          ..secondaryGradient = isSystemDark
              ? const LinearGradient(
                  colors: [Color(0xffE9AD21), Color(0xffCC9900)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xffE9AD21), Color(0xffFFD700)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
          ..softShadow = isSystemDark
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [
                  BoxShadow(
                    color: const Color(0xFF0061FF).withOpacity(0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ];
    }
  }

  ThemeData get themeData {
    ThemeData t = ThemeData.from(
      textTheme: (isDark ? ThemeData.dark() : ThemeData.light()).textTheme,
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: primaryBase,
        primaryContainer: primaryText,
        secondary: successShade,
        // secondaryContainer: ColorHelper.getMaterialColorFromColor(secondaryTxt),
        background: background,
        surface: foundationColor,
        onBackground: txt,
        onSurface: txt,
        onError: txt,
        onPrimary: accentTxt,
        onSecondary: accentTxt,
        error: errorPrimary,
      ),
    );
    return t.copyWith(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: disabled,
        selectionHandleColor: Colors.transparent,
        cursorColor: primaryBase,
      ),
      highlightColor: primaryBase,
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color?>((
          Set<MaterialState> states,
        ) {
          if (states.contains(MaterialState.disabled)) {
            return null;
          }
          if (states.contains(MaterialState.selected)) {
            return primaryBase;
          }
          return null;
        }),
      ),
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color?>((
          Set<MaterialState> states,
        ) {
          if (states.contains(MaterialState.disabled)) {
            return null;
          }
          if (states.contains(MaterialState.selected)) {
            return primaryBase;
          }
          return null;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color?>((
          Set<MaterialState> states,
        ) {
          if (states.contains(MaterialState.disabled)) {
            return null;
          }
          if (states.contains(MaterialState.selected)) {
            return primaryBase;
          }
          return null;
        }),
        trackColor: MaterialStateProperty.resolveWith<Color?>((
          Set<MaterialState> states,
        ) {
          if (states.contains(MaterialState.disabled)) {
            return null;
          }
          if (states.contains(MaterialState.selected)) {
            return primaryBase;
          }
          return null;
        }),
      ),
    );
  }
}
