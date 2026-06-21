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
    try {
      double value = double.parse(replaceAll(',', '').replaceAll('₦', ''));
      return NumberFormat.simpleCurrency(name: '').format(value);
    } catch (e) {
      return this;
    }
  }

  String formatToLocalCurrency() {
    if (isEmpty) return this;
    try {
      double value = double.parse(replaceAll(',', '').replaceAll('₦', ''));
      return NumberFormat.simpleCurrency().format(value);
    } catch (e) {
      return this;
    }
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
    String? title,
    InAppNotificationType type = InAppNotificationType.error,
    int duration = 3,
  }) {
    late Color color;
    late Color textColor;
    late IconData icon;

    switch (type) {
      case InAppNotificationType.success:
        color = const Color(0xff10B981);
        textColor = Colors.white;
        icon = Icons.check_circle_outline;
        break;
      case InAppNotificationType.info:
        color = const Color(0xff3B82F6);
        textColor = Colors.white;
        icon = Icons.info_outline;
        break;
      case InAppNotificationType.error:
        color = const Color(0xffEF4444);
        textColor = Colors.white;
        icon = Icons.error_outline;
        break;
    }

    R.N.notifyKey.currentState?.show(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: textColor, size: 24),
            12.horizontalSpace,
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    PrimaryText(
                      text: title,
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    2.verticalSpace,
                  ],
                  SecondaryText(
                    text: msg,
                    color: textColor.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.close,
              color: textColor.withValues(alpha: 0.5),
              size: 18,
            ).rippleClick(() {
              R.N.notifyKey.currentState?.dismiss();
            }),
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
