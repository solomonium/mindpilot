import 'dart:io';

import 'package:flutter/services.dart';
import 'package:mindpilot/export.dart';

extension AssetsExtension on String {
  //Icons
  String get svg => 'assets/icons/$this.svg';
  String get png => 'assets/icons/$this.png';
  //Images
  String get imgPng => 'assets/images/$this.png';
  String get imgJpg => 'assets/images/$this.jpg';
  String get imgSvg => 'assets/images/$this.svg';

  //text file
  String get txt => 'assets/text/$this.txt';

  int toInt() {
    try {
      return int.parse(this);
    } catch (e) {
      return -1;
    }
  }

  double toDouble() {
    try {
      return double.parse(this);
    } catch (e) {
      return -1;
    }
  }

  String getInitials({defaultLength = 2}) {
    try {
      if (isEmpty) return "";
      final names = split(" ");
      if (names.length < defaultLength) {
        return names[0][0].toUpperCase();
      }
      return names.sublist(0, defaultLength).map((name) {
        return name[0].toUpperCase();
      }).join();
    } catch (_) {
      return substring(0, 1).toUpperCase();
    }
  }

  String getFirstName() {
    List<String> names = split(" ");
    List<String> titles = [
      'Mr',
      'Mrs',
      'Chief',
      'Engr',
      'Dr',
      'Miss',
    ]; // Add any other titles you want to include

    if (names.isNotEmpty) {
      if (titles.contains(names[0])) {
        return names.length > 1 ? '${names[0]} ${names[1]}' : names[0];
      } else {
        return names[0];
      }
    }
    return '';
  }

  String thousandSeparator() {
    if (isEmpty) return this;

    // Remove any previous thousand separators
    String text = replaceAll(',', '');

    // Check if the text contains a decimal part
    bool hasDecimalPart = text.contains('.');

    // Split the text into integer and decimal parts
    List<String> parts = text.split('.');
    String integerPart = parts[0];
    String decimalPart = hasDecimalPart ? '.${parts[1]}' : '';

    // Add thousand separators to the integer part
    String formattedInteger = '';
    int count = 0;
    for (int i = integerPart.length - 1; i >= 0; i--) {
      count++;
      formattedInteger = integerPart[i] + formattedInteger;
      if (count == 3 && i > 0) {
        formattedInteger = ',$formattedInteger';
        count = 0;
      }
    }

    return '₦$formattedInteger${decimalPart.isEmpty ? '.00' : decimalPart}';
  }

  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }

  String toFilterDate() {
    return replaceAll("/", "-").split("-").reversed.toList().join("-");
  }

  String toTitleCase() {
    if (length < 2) return this;
    return toLowerCase()
        .split(" ")
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(" ");
  }
}

extension SizedContext on BuildContext {
  /// Returns same as MediaQuery.of(context)
  MediaQueryData get mq => MediaQuery.of(this);

  /// Returns if Orientation is landscape
  bool get isLandscape => mq.orientation == Orientation.landscape;

  /// Returns same as MediaQuery.of(context).size
  Size get sizePx => mq.size;

  /// Returns same as MediaQuery.of(context).size.width
  double get widthPx => sizePx.width;

  /// Returns same as MediaQuery.of(context).height
  double get heightPx => sizePx.height;

  /// Returns diagonal screen pixels

  /// Returns fraction (0-1) of screen width in pixels
  double widthPct(double fraction) => fraction * widthPx;

  /// Returns fraction (0-1) of screen height in pixels
  double heightPct(double fraction) => fraction * heightPx;

  Future<T?> push<T>(Widget page) =>
      Navigator.push<T>(this, RouteHelper.fade(() => page));

  Future<T?> replace<T>(Widget page) =>
      Navigator.pushReplacement(this, RouteHelper.fade(() => page));

  Future<T?> pushOff<T>(Widget page) => Navigator.pushAndRemoveUntil<T>(
    this,
    RouteHelper.fade(() => page),
    (_) => false,
  );

  void popOff([String? routeTag]) => Navigator.popUntil(
    this,
    ModalRoute.withName(routeTag ?? '/AppScaffoldPage'),
  );

  Future<bool> pop<T>([T? result]) => Navigator.maybePop(this, result);

  void showInAppNotification(
    String msg, {
    InAppNotificationType type = InAppNotificationType.error,
    int duration = 3,
  }) {
    late Color color;
    switch (type) {
      case InAppNotificationType.success:
        color = const Color(0xffAFDEC7);
        break;
      case InAppNotificationType.info:
        color = Colors.orange;
        break;
      case InAppNotificationType.error:
        color = const Color(0xffDB4437);
        break;
    }
    late Color textColor;
    switch (type) {
      case InAppNotificationType.success:
        textColor = const Color(0xff0C5C35);
        break;
      case InAppNotificationType.info:
        textColor = const Color(0xffFFFFFF);
        break;
      case InAppNotificationType.error:
        textColor = const Color(0xffF3C1BC);
        break;
    }
    R.N.notifyKey.currentState?.show(
      child: Container(
        decoration: BoxDecoration(color: color),
        padding: EdgeInsets.fromLTRB(16, Platform.isAndroid ? 16 : 50, 16, 16),
        margin: EdgeInsets.zero,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (type == InAppNotificationType.success)
              Icon(Icons.check_circle, color: textColor),
            // Icon(Icons.check_circle, color: textColor),
            8.horizontalSpace,
            Expanded(
              child: SecondaryText(
                text: msg,
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Icon(Icons.close, color: textColor),
          ],
        ),
      ),
      duration: Duration(seconds: duration),
    );
  }
}

extension ClickableExtensions on Widget {
  Widget clickable(void Function()? action, {bool opaque = true}) {
    return GestureDetector(
      behavior: opaque ? HitTestBehavior.opaque : HitTestBehavior.deferToChild,
      onTap: action,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        opaque: opaque,
        child: this,
      ),
    );
  }

  Widget rippleClick(
    void Function()? onTap, {
    EdgeInsetsGeometry? padding,
    BorderRadiusGeometry? clickBorderRadius,
  }) {
    return Stack(
      children: <Widget>[
        Padding(
          padding: padding ?? const EdgeInsets.symmetric(vertical: 3),
          child: this,
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: 0,
          child: TextButton(
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: clickBorderRadius ?? BorderRadius.circular(8),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16),
              foregroundColor: const Color(0xff8CA32B), // Set the splash color
            ),
            onPressed: onTap,
            child: Container(),
          ),
        ),
      ],
    );
  }

  void copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    context.showInAppNotification(
      '$text copied to clipboard',
      type: InAppNotificationType.success,
    );
  }
}
