import 'package:mindpilot/export.dart';

class NoInternetDialog extends StatefulWidget {
  final Future<void> Function() onRetry;

  const NoInternetDialog({
    super.key,
    required this.onRetry,
  });

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function() onRetry,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => NoInternetDialog(onRetry: onRetry),
    );
  }

  @override
  State<NoInternetDialog> createState() => _NoInternetDialogState();
}

class _NoInternetDialogState extends State<NoInternetDialog> {
  bool _isChecking = false;

  Future<void> _handleRetry() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    final hasNet = await AppHelper.isOnline();
    if (hasNet) {
      if (mounted) {
        Navigator.of(context).pop();
        await widget.onRetry();
      }
    } else {
      if (mounted) {
        setState(() => _isChecking = false);
        context.showInAppNotification(
          "Still no internet connection. Please try again.",
          type: InAppNotificationType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: theme.brandDark,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 48,
                  color: Colors.orange,
                ),
              ),
              20.verticalSpace,
              PrimaryText(
                text: "No Internet Connection",
                fontSize: 18,
                fontWeight: FontWeight.bold,
                textAlign: TextAlign.center,
                color: Colors.white,
              ),
              12.verticalSpace,
              SecondaryText(
                text:
                    "Please check your network settings and try again to continue using MindPilot.",
                fontSize: 14,
                textAlign: TextAlign.center,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              24.verticalSpace,
              CustomButton(
                label: "Try Again",
                loading: _isChecking,
                fullWidth: true,
                onPressed: _handleRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
