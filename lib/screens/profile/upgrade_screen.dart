import 'package:mindpilot/export.dart';
import 'package:url_launcher/url_launcher.dart';

class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  int _selectedPlan = 1; // 0 for Monthly, 1 for Yearly

  final List<Map<String, dynamic>> _plans = [
    {
      'title': 'Monthly Plan',
      'price': r'$9.99',
      'period': '/ month',
      'description': 'Perfect for short-term clarity',
    },
    {
      'title': 'Yearly Plan',
      'price': r'$79.99',
      'period': '/ year',
      'description': 'Best value for long-term growth',
      'save': 'Save 33%',
    },
  ];

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.6,
              child: Image.asset(R.png.loginBg.png, fit: BoxFit.cover),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.brandDark.withOpacity(0.4),
                    theme.brandDark.withOpacity(0.8),
                    theme.brandDark,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _appBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.stars,
                          color: Color(0xFFF59E0B),
                          size: 64,
                        ),
                        24.verticalSpace,
                        PrimaryText(
                          text: 'Elevate Your Mind',
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: theme.accentTxt,
                        ),
                        8.verticalSpace,
                        SecondaryText(
                          text:
                              'Unlock premium features to master your thoughts and achieve peak clarity.',
                          textAlign: TextAlign.center,
                          color: theme.accentTxt.withOpacity(0.7),
                        ),
                        40.verticalSpace,
                        ...List.generate(
                          _plans.length,
                          (index) => _planCard(index),
                        ),
                        40.verticalSpace,
                        _featuresList(theme),
                        40.verticalSpace,
                        GlassContainer(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          width: double.infinity,
                          gradient: theme.glassGradient,
                          child: Center(
                            child: PrimaryText(
                              text: 'Start Pro Journey',
                              color: theme.accentTxt,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ).rippleClick(() {
                          context.showInAppNotification(
                            'In-app purchases are coming soon!',
                            type: InAppNotificationType.info,
                          );
                        }),
                        24.verticalSpace,
                        SecondaryText(
                          text: 'Restore Subscription',
                          color: theme.accentTxt.withOpacity(0.5),
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                        ).rippleClick(() {
                          context.showInAppNotification(
                            'Subscription restoration is coming soon!',
                            type: InAppNotificationType.info,
                          );
                        }),
                        16.verticalSpace,
                        SecondaryText(
                          text: 'Request Pro Access via WhatsApp',
                          color: theme.primaryBase,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ).rippleClick(() => _launchWhatsApp()),
                        40.verticalSpace,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _appBar(BuildContext context) {
    AppTheme theme = context.watch();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.close,
            color: theme.accentTxt,
          ).rippleClick(() => context.pop()),
          const Spacer(),
          PrimaryText(
            text: 'MindPilot Pro',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.accentTxt,
          ),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _planCard(int index) {
    AppTheme theme = context.watch();
    final plan = _plans[index];
    bool isSelected = _selectedPlan == index;

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      gradient: isSelected ? null : theme.glassGradient,
      color: isSelected ? theme.primaryBase.withOpacity(0.2) : null,
      border: isSelected
          ? Border.all(color: theme.primaryBase, width: 2)
          : Border.all(color: theme.accentTxt.withOpacity(0.1)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PrimaryText(
                      text: plan['title'],
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.accentTxt,
                    ),
                    if (plan['save'] != null) ...[
                      12.horizontalSpace,
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.successPrimary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: PrimaryText(
                          text: plan['save'],
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
                4.verticalSpace,
                SecondaryText(
                  text: plan['description'],
                  fontSize: 12,
                  color: theme.accentTxt.withOpacity(0.6),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PrimaryText(
                text: plan['price'],
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.accentTxt,
              ),
              SecondaryText(
                text: plan['period'],
                fontSize: 12,
                color: theme.accentTxt.withOpacity(0.5),
              ),
            ],
          ),
        ],
      ),
    ).rippleClick(() => setState(() => _selectedPlan = index));
  }

  Widget _featuresList(AppTheme theme) {
    return Column(
      children: [
        _featureItem(Icons.psychology, 'Unlimited AI Decision Analysis'),
        16.verticalSpace,
        _featureItem(Icons.trending_up, 'Advanced Personal Growth Analytics'),
        16.verticalSpace,
        _featureItem(Icons.share, 'One-Tap Viral Journal Sharing'),
        16.verticalSpace,
        _featureItem(Icons.timer, 'Exclusive Focus Session Music & Themes'),
        16.verticalSpace,
        _featureItem(
          Icons.notifications_active,
          'Early Access to Pro Insights',
        ),
      ],
    );
  }

  Widget _featureItem(IconData icon, String label) {
    AppTheme theme = context.watch();
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.primaryBase.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: theme.primaryBase, size: 16),
        ),
        16.horizontalSpace,
        Expanded(
          child: SecondaryText(
            text: label,
            color: theme.accentTxt,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Future<void> _launchWhatsApp() async {
    final phoneNumber = "2349043230179";
    final userEmail = context.read<AuthProvider>().user?.email ?? "Unknown Email";
    final message = Uri.encodeComponent(
        "Hello MindPilot Team, I would like to upgrade my account to MindPilot Pro. Here is my email: $userEmail");
    final url = "https://wa.me/$phoneNumber?text=$message";


    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        context.showInAppNotification(
            'Could not launch WhatsApp. Please contact 09043230179.');
      }
    }
  }

  Future<void> _processPurchase() async {
    // Legacy method - no longer used but kept for reference or future use
    context.showInAppNotification(
      'In-app purchases are coming soon!',
      type: InAppNotificationType.info,
    );
  }
}
