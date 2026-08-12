import 'package:flutter/services.dart';
import 'package:mindpilot/export.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final _codeController = TextEditingController();
  bool _applying = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    final auth = context.watch<AppAuthProvider>();
    final myCode =
        auth.referralCode ??
        (auth.user != null
            ? EngagementService().generateReferralCode(auth.user!.uid)
            : 'MPXXXXXX');
    final downloadUrl = ConfigService().updateUrl;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: PrimaryText(
          text: 'Invite Friends',
          color: theme.accentTxt,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Icon(
            Icons.arrow_back_ios,
            color: theme.accentTxt,
            size: 20,
          ).rippleClick(() => context.pop()),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassContainer(
              padding: const EdgeInsets.all(20),
              gradient: theme.glassGradient,
              border: Border.all(
                color: theme.primaryBase.withValues(alpha: 0.3),
              ),
              child: Column(
                children: [
                  Icon(Icons.card_giftcard, color: theme.primaryBase, size: 40),
                  12.verticalSpace,
                  PrimaryText(
                    text: 'Share clarity, earn rewards',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.accentTxt,
                    textAlign: TextAlign.center,
                  ),
                  8.verticalSpace,
                  SecondaryText(
                    text:
                        'Get 3 days of Premium direct Gemini API access and +1 decision credit for every friend who joins with your code!',
                    fontSize: 13,
                    color: theme.accentTxt.withValues(alpha: 0.7),
                    textAlign: TextAlign.center,
                  ),
                  20.verticalSpace,
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: theme.primaryBase.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.primaryBase.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PrimaryText(
                          text: myCode,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryBase,
                        ),
                        12.horizontalSpace,
                        Icon(
                          Icons.copy,
                          color: theme.primaryBase,
                          size: 20,
                        ).rippleClick(() {
                          Clipboard.setData(ClipboardData(text: myCode));
                          context.showInAppNotification(
                            'Referral code copied!',
                            type: InAppNotificationType.success,
                          );
                        }),
                      ],
                    ),
                  ),
                  16.verticalSpace,
                  SecondaryText(
                    text: '${auth.referralCount} friends invited',
                    fontSize: 12,
                    color: theme.accentTxt.withValues(alpha: 0.6),
                  ),
                  20.verticalSpace,
                  CustomButton(
                    label: 'Share / QR Invite',
                    prefixIcon: const Icon(
                      Icons.qr_code_2_rounded,
                      size: 18,
                      color: Colors.black,
                    ),
                    onPressed: () {
                      AppShareSheet.showForReferral(
                        context,
                        referralCode: myCode,
                        downloadUrl: downloadUrl,
                      );
                      AnalyticsService.logShareCard('referral');
                    },
                  ),
                ],
              ),
            ),
            if (auth.isPro && auth.premiumExpiresAt != null) ...[
              16.verticalSpace,
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.primaryBase.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.primaryBase.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.stars, color: theme.primaryBase, size: 24),
                    12.horizontalSpace,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PrimaryText(
                            text: 'Temporary Premium Active! 🚀',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.primaryBase,
                          ),
                          4.verticalSpace,
                          SecondaryText(
                            text: 'Expires on: ${DateFormat('yyyy-MM-dd HH:mm').format(auth.premiumExpiresAt!.toDate())}',
                            fontSize: 12,
                            color: theme.accentTxt.withOpacity(0.8),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            24.verticalSpace,
            if (auth.referredBy == null) ...[
              PrimaryText(
                text: 'Have a referral code?',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.accentTxt,
              ),
              12.verticalSpace,
              CustomTextField(
                textController: _codeController,
                hintText: 'Enter referral code',
                textInputType: TextInputType.text,
                autoFocus: false,
                textInputAction: TextInputAction.done,
              ),
              16.verticalSpace,
              CustomButton(
                label: 'Apply Code',
                loading: _applying,
                onPressed: _applyCode,
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.successPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: theme.successPrimary),
                    12.horizontalSpace,
                    Expanded(
                      child: SecondaryText(
                        text: 'Referral applied: ${auth.referredBy}',
                        color: theme.accentTxt,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _applyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      context.showInAppNotification('Please enter a referral code.');
      return;
    }

    setState(() => _applying = true);
    try {
      await EngagementService().applyReferralCode(code);
      if (mounted) {
        context.read<AppAuthProvider>().refreshReferralData();
        context.showInAppNotification(
          'Referral applied! You earned a bonus decision credit.',
          type: InAppNotificationType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        context.showInAppNotification(
          'Could not apply code. Check and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }
}
