// ignore_for_file: must_be_immutable

import 'package:mindpilot/export.dart';

class WalletScreen extends StatefulWidget {
  WalletScreen({super.key, this.titleDestination});

  String? titleDestination;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with FormMixin {
  final List<Map<String, String>> _wallets = [
    {'name': 'Main UGX Wallet', 'balance': 'UGX 1,250,000'},
    {'name': 'Business Wallet', 'balance': 'UGX 450,000'},
    {'name': 'Savings Wallet', 'balance': 'UGX 3,000,000'},
  ];
  late Map<String, String> _selectedWallet;

  @override
  void initState() {
    super.initState();
    _selectedWallet = _wallets[0];
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: theme.background,
      body: Consumer<HomeProvider>(
        builder: (context, home, _) {
          return Form(
            key: formKey,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        // App Bar section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                PrimaryText(
                                  text: R.S.walletOverview,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: theme.primaryText,
                                ),
                                const SizedBox(height: 4),
                                SecondaryText(
                                  text: R.S.manageWallets,
                                  fontSize: 12,
                                  color: theme.secondaryTxt,
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Stack(
                                  children: [
                                    const Icon(Icons.notifications_outlined, color: Color(0xFF1170B2)),
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFE9AD21),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Text(
                                          '5',
                                          style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                                const SizedBox(width: 16),
                                const Icon(Icons.account_balance_wallet, color: Color(0xFF1170B2)),
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Main Wallet Card
                        CustomContainer(
                          padding: const EdgeInsets.all(20),
                          color: const Color(0xFF1170B2),
                          borderRadius: 16,
                          border: Border.all(color: Colors.transparent),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  CustomDropdown<Map<String, String>>(
                                    items: _wallets,
                                    value: _selectedWallet,
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedWallet = val);
                                    },
                                    itemBuilder: (context, item) => Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        PrimaryText(
                                          text: item['name']!,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xff69625A),
                                        ),
                                        const SizedBox(width: 12),
                                        PrimaryText(
                                          text: item['balance']!,
                                          fontSize: 12,
                                          color: const Color(0xFF1170B2),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        PrimaryText(
                                          text: _selectedWallet['name']!,
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
                                      ],
                                    ),
                                  ),
                                  CustomContainer(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    borderRadius: 8,
                                    color: Colors.white,
                                    border: Border.all(color: Colors.transparent),
                                    child: Row(
                                      children: [
                                        PrimaryText(
                                          text: R.S.walletId,
                                          fontSize: 12,
                                          color: const Color(0xFF272624),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.lock, size: 14, color: Color(0xFF272624)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  PrimaryText(
                                    text: _selectedWallet['balance']!,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.visibility_off, color: Colors.white, size: 16),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SecondaryText(
                                text: R.S.thisIsMainWallet,
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildActionButton(
                              text: R.S.addMoney,
                              icon: Icons.add_circle_outline,
                              bgColor: const Color(0xFFEFF6FF),
                              iconColor: const Color(0xFF1170B2),
                            ),
                            _buildActionButton(
                              text: R.S.transact,
                              icon: Icons.send_outlined,
                              bgColor: const Color(0xFFFFF7ED),
                              iconColor: const Color(0xFFE9AD21),
                            ),
                            _buildActionButton(
                              text: R.S.withdraw,
                              icon: Icons.remove_circle_outline,
                              bgColor: const Color(0xFFF0FDF4),
                              iconColor: const Color(0xFF22C55E),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Sub Wallets
                        PrimaryText(
                          text: R.S.yourSubWallets,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: theme.primaryText,
                        ),
                        const SizedBox(height: 16),
                        CustomContainer(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SecondaryText(
                                text: Mock.subWallets()[0]['name'],
                                color: theme.secondaryTxt,
                                fontSize: 14,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  PrimaryText(
                                    text: Mock.subWallets()[0]['ugxBalance'],
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: theme.primaryText,
                                  ),
                                  Container(
                                    width: 1,
                                    height: 30,
                                    color: theme.dividerAndBorderColor,
                                  ),
                                  PrimaryText(
                                    text: Mock.subWallets()[0]['dollarBalance'],
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: theme.primaryText,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              ...List.generate(
                                Mock.subWallets()[0]['funds'].length,
                                (index) {
                                  var fund = Mock.subWallets()[0]['funds'][index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        SecondaryText(
                                          text: fund['name'],
                                          color: theme.secondaryTxt,
                                          fontSize: 14,
                                        ),
                                        PrimaryText(
                                          text: fund['balance'],
                                          color: theme.primaryText,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CustomContainer(
                              width: 24,
                              height: 6,
                              padding: EdgeInsets.zero,
                              borderRadius: 3,
                              color: const Color(0xFF1170B2),
                              border: Border.all(color: Colors.transparent),
                              child: const SizedBox.shrink(),
                            ),
                            const SizedBox(width: 4),
                            CustomContainer(
                              width: 16,
                              height: 6,
                              padding: EdgeInsets.zero,
                              borderRadius: 3,
                              color: Colors.grey.withOpacity(0.3),
                              border: Border.all(color: Colors.transparent),
                              child: const SizedBox.shrink(),
                            ),
                            const SizedBox(width: 4),
                            CustomContainer(
                              width: 16,
                              height: 6,
                              padding: EdgeInsets.zero,
                              borderRadius: 3,
                              color: Colors.grey.withOpacity(0.3),
                              border: Border.all(color: Colors.transparent),
                              child: const SizedBox.shrink(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Transactions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            PrimaryText(
                              text: R.S.transactions,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: theme.primaryText,
                            ),
                            CustomContainer(
                              padding: const EdgeInsets.all(8),
                              borderRadius: 100,
                              color: const Color(0xFFFFF7ED),
                              border: Border.all(color: Colors.transparent),
                              child: const Icon(Icons.cloud_download_outlined, color: Color(0xFFE9AD21), size: 20),
                            )
                          ],
                        ),
                        const SizedBox(height: 100), // Bottom padding
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButton({required String text, required IconData icon, required Color bgColor, required Color iconColor}) {
    return Expanded(
      child: CustomContainer(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        borderRadius: 12,
        color: bgColor,
        border: Border.all(color: Colors.transparent),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 6),
            PrimaryText(
              text: text,
              color: const Color(0xff69625A),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ],
        ),
      ),
    );
  }
}

