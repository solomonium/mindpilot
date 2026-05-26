import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:mindpilot/export.dart';

class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  int _selectedPlan = 1; // 0 for Monthly, 1 for Yearly
  bool _isPurchasing = false;
  List<Package> _packages = [];
  List<StoreProduct> _directProducts = [];

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
  void initState() {
    super.initState();
    _loadOfferings();
    PaymentService.isPurchasing.addListener(_onPurchasingChanged);
    PaymentService.purchasedOrRestored.addListener(
      _onPurchasedOrRestoredChanged,
    );
  }

  @override
  void dispose() {
    PaymentService.isPurchasing.removeListener(_onPurchasingChanged);
    PaymentService.purchasedOrRestored.removeListener(
      _onPurchasedOrRestoredChanged,
    );
    super.dispose();
  }

  void _onPurchasingChanged() {
    if (mounted) {
      setState(() {
        _isPurchasing = PaymentService.isPurchasing.value;
      });
    }
  }

  void _onPurchasedOrRestoredChanged() {
    final status = PaymentService.purchasedOrRestored.value;
    if (status == null) return;

    if (status) {
      if (mounted) {
        context.showInAppNotification(
          'Welcome to MindPilot Pro!',
          type: InAppNotificationType.success,
        );
        context.pop();
      }
    } else {
      if (mounted) {
        context.showInAppNotification(
          'Purchase failed or could not be verified. Please try again.',
          type: InAppNotificationType.error,
        );
      }
    }
  }

  Future<void> _loadOfferings() async {
    // 1. Direct Store Product Fetch Debug Block (Bypassing RevenueCat Offerings)
    try {
      safePrint(
        'DEBUG: Fetching products directly from Google Play / App Store...',
      );

      // Enter your EXACT product IDs here to check if they are returned by Google Play / App Store
      final List<String> directProductIds = [
        // 'monthly_pro',
        // 'yearly_pro',
        'mindpilot_pro_monthly',
        'mindpilot_pro_yearly',
      ];

      final directProducts = await Purchases.getProducts(directProductIds);
      if (directProducts.isNotEmpty) {
        safePrint(
          'DEBUG DIRECT FETCH: Found ${directProducts.length} products directly from store:',
        );
        for (var product in directProducts) {
          safePrint(
            '  - ID: ${product.identifier} | Price: ${product.priceString} | Title: ${product.title}',
          );
        }
        if (mounted) {
          setState(() {
            _directProducts = directProducts;
            for (var product in _directProducts) {
              final isMonthly = product.identifier.contains('monthly');
              final planIndex = isMonthly ? 0 : 1;
              _plans[planIndex]['price'] = product.priceString;
            }
          });
        }
      } else {
        safePrint(
          'DEBUG DIRECT FETCH: No direct products returned for IDs: $directProductIds. Please verify your Product IDs match Google Play.',
        );
      }
    } catch (e) {
      safePrint('DEBUG DIRECT FETCH ERROR: $e');
    }

    // 2. Standard RevenueCat Offerings Fetch
    final packages = await PaymentService.fetchOfferings();
    if (packages.isNotEmpty && mounted) {
      setState(() {
        _packages = packages;
        for (var package in _packages) {
          final isMonthly = package.packageType == PackageType.monthly;
          final planIndex = isMonthly ? 0 : 1;
          _plans[planIndex]['price'] = package.storeProduct.priceString;
        }
      });
    }
  }

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
                          (index) => Column(
                            children: [_planCard(index), 16.verticalSpace],
                          ),
                        ),
                        40.verticalSpace,
                        _featuresList(theme),
                        40.verticalSpace,
                        GlassContainer(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          width: double.infinity,
                          gradient: theme.glassGradient,
                          child: Center(
                            child: _isPurchasing
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : PrimaryText(
                                    text: 'Start Pro Journey',
                                    color: theme.accentTxt,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                          ),
                        ).rippleClick(() {
                          if (_isPurchasing) return;

                          // Standard flow: if RevenueCat offerings are fetched successfully, purchase using the package
                          if (_packages.isNotEmpty) {
                            final targetType = _selectedPlan == 0
                                ? PackageType.monthly
                                : PackageType.annual;
                            Package? packageToBuy;
                            try {
                              packageToBuy = _packages.firstWhere(
                                (p) => p.packageType == targetType,
                              );
                            } catch (_) {
                              try {
                                packageToBuy = _packages.firstWhere(
                                  (p) => _selectedPlan == 0
                                      ? p.packageType == PackageType.monthly
                                      : (p.packageType == PackageType.annual ||
                                            p.packageType ==
                                                PackageType.lifetime),
                                );
                              } catch (_) {
                                packageToBuy = _packages.first;
                              }
                            }
                            PaymentService.buyPackage(packageToBuy);
                            return;
                          }

                          // Fallback flow: if offerings are empty but direct products are fetched, purchase directly from Google Play / App Store
                          if (_directProducts.isNotEmpty) {
                            final isMonthly = _selectedPlan == 0;
                            StoreProduct? productToBuy;
                            try {
                              productToBuy = _directProducts.firstWhere(
                                (p) => isMonthly
                                    ? p.identifier.contains('monthly')
                                    : p.identifier.contains('yearly'),
                              );
                            } catch (_) {
                              productToBuy = _directProducts.first;
                            }
                            PaymentService.buyProduct(productToBuy);
                            return;
                          }

                          // Fallback: If both are unavailable, notify user
                          context.showInAppNotification(
                            'Subscription plans are currently unavailable. Please check your internet connection and try again.',
                            type: InAppNotificationType.error,
                          );
                        }),
                        24.verticalSpace,
                        SecondaryText(
                          text: 'Restore Subscription',
                          color: theme.accentTxt.withOpacity(0.5),
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                        ).rippleClick(() {
                          if (_isPurchasing) return;
                          PaymentService.restorePurchases();
                        }),
                        20.verticalSpace,
                        // 📜 Apple EULA and Privacy Policy links (Mandatory for App Store auto-renewable subscriptions!)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SecondaryText(
                              text: 'Privacy Policy',
                              color: theme.accentTxt.withOpacity(0.4),
                              fontSize: 11,
                              decoration: TextDecoration.underline,
                            ).rippleClick(() async {
                              final url = Uri.parse('https://mindpilot-131f1.web.app/privacy');
                              try {
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url, mode: LaunchMode.externalApplication);
                                }
                              } catch (e) {
                                safePrint('Error launching privacy policy: $e');
                              }
                            }),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: SecondaryText(
                                text: '•',
                                color: theme.accentTxt.withOpacity(0.3),
                                fontSize: 11,
                              ),
                            ),
                            SecondaryText(
                              text: 'Terms of Use (EULA)',
                              color: theme.accentTxt.withOpacity(0.4),
                              fontSize: 11,
                              decoration: TextDecoration.underline,
                            ).rippleClick(() async {
                              final url = Uri.parse('https://mindpilot-131f1.web.app/terms');
                              try {
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url, mode: LaunchMode.externalApplication);
                                }
                              } catch (e) {
                                safePrint('Error launching terms of use: $e');
                              }
                            }),
                          ],
                        ),
                        40.verticalSpace,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isPurchasing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      16.verticalSpace,
                      PrimaryText(
                        text: 'Processing secure payment...',
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ],
                  ),
                ),
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
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    PrimaryText(
                      text: plan['title'],
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.accentTxt,
                    ),
                    if (plan['save'] != null)
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
        16.verticalSpace,
        _featureItem(
          Icons.auto_awesome,
          'Share AI Chat Highlights with Branded Cards',
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
}
