import 'package:mindpilot/export.dart';

class ContributeStepOne extends StatefulWidget {
  const ContributeStepOne({super.key});

  @override
  State<ContributeStepOne> createState() => _ContributeStepOneState();
}

class _ContributeStepOneState extends State<ContributeStepOne> {
  final TextEditingController _amountController = TextEditingController(text: '2000');
  String? _selectedGroup;
  String? _selectedProduct = 'Twezi Flexi';

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group Dropdown
        CustomDropdown<String>(
          labelText: 'Group',
          hint: 'Select group',
          value: _selectedGroup,
          items: const ['Amazing Grace Foundation', 'Global Relief Fund', 'Twezi Savings Group'],
          onChanged: (val) => setState(() => _selectedGroup = val),
        ),
        
        24.verticalSpace,

        // Amount Input
        PrimaryText(text: 'Amount to Deposit', fontSize: 16, fontWeight: FontWeight.w600),
        8.verticalSpace,
        CustomTextField(
          textInputType: TextInputType.number,
          textController: _amountController,
          autoFocus: false,
          hintText: 'UGX 2000',
          prefixText: 'UGX ',
          textInputAction: TextInputAction.done,
        ),
        
        16.verticalSpace,

        // Quick Amount Chips
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: ['1000', '2000', '5000', '10000'].map((amount) {
            return QuickAmountChip(
              amount: 'UGX $amount',
              isSelected: _amountController.text == amount,
              onTap: () => setState(() => _amountController.text = amount),
            );
          }).toList(),
        ),

        24.verticalSpace,

        // Product Selection
        PrimaryText(text: 'Choose a Product to Top Up', fontSize: 14, fontWeight: FontWeight.w600),
        12.verticalSpace,
        Row(
          children: [
            _buildProductCard(theme, 'Twezi Flexi', 'UGX 100K', isSelected: _selectedProduct == 'Twezi Flexi'),
            12.horizontalSpace,
            _buildProductCard(theme, 'Twezi Pride', 'UGX 100K', isSelected: _selectedProduct == 'Twezi Pride'),
          ],
        ),

        32.verticalSpace,

        // Proceed Button
        CustomButton(
          label: 'Proceed',
          fullWidth: true,
          onPressed: () => context.nextBottomSheetPage(),
        ),
      ],
    );
  }

  Widget _buildProductCard(AppTheme theme, String title, String subtitle, {bool isSelected = false}) {
    return Expanded(
      child: CustomContainer(
        onTap: () => setState(() => _selectedProduct = title),
        padding: const EdgeInsets.all(16),
        color: isSelected ? theme.primaryBase.withValues(alpha: 0.1) : theme.dividerAndBorderColor.withValues(alpha: 0.05),
        borderRadius: 12,
        border: Border.all(
          color: isSelected ? theme.primaryBase : theme.dividerAndBorderColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PrimaryText(
              text: title,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? theme.primaryBase : theme.primaryText,
            ),
            4.verticalSpace,
            SecondaryText(text: subtitle, fontSize: 10),
          ],
        ),
      ),
    );
  }
}

class ContributeStepTwo extends StatefulWidget {
  const ContributeStepTwo({super.key});

  @override
  State<ContributeStepTwo> createState() => _ContributeStepTwoState();
}

class _ContributeStepTwoState extends State<ContributeStepTwo> {
  String _selectedSource = 'MTN Momo';
  bool _isLoading = false;

  void _handleProceed() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context, 'Success');
    }
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PrimaryText(text: 'Source', fontSize: 14, color: theme.secondaryTxt),
        12.verticalSpace,
        
        // Payment Sources
        PaymentSourceTile(
          label: 'Global wallet',
          isSelected: _selectedSource == 'Global wallet',
          onTap: () => setState(() => _selectedSource = 'Global wallet'),
        ),
        PaymentSourceTile(
          label: 'MTN Momo',
          isSelected: _selectedSource == 'MTN Momo',
          onTap: () => setState(() => _selectedSource = 'MTN Momo'),
        ),
        PaymentSourceTile(
          label: 'Flutterwave',
          isSelected: _selectedSource == 'Flutterwave',
          onTap: () => setState(() => _selectedSource = 'Flutterwave'),
        ),

        24.verticalSpace,

        // Transaction Breakdown
        CustomContainer(
          padding: const EdgeInsets.all(16),
          color: theme.dividerAndBorderColor.withValues(alpha: 0.05),
          borderRadius: 12,
          border: Border.all(color: Colors.transparent), // Override default border
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SecondaryText(text: 'Transaction Breakdown', fontSize: 12, fontWeight: FontWeight.bold),
              12.verticalSpace,
              _buildBreakdownRow('Amount to Deposit', 'UGX 1,000'),
              8.verticalSpace,
              _buildBreakdownRow('Transaction Fee', 'UGX 420', color: theme.errorPrimary),
              const Divider(height: 24),
              _buildBreakdownRow('Total', 'UGX 1,420', isBold: true),
            ],
          ),
        ),

        32.verticalSpace,

        // Proceed Button
        CustomButton(
          label: 'Proceed',
          fullWidth: true,
          loading: _isLoading,
          onPressed: _handleProceed,
        ),
      ],
    );
  }

  Widget _buildBreakdownRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SecondaryText(text: label, fontSize: 12, color: color),
        PrimaryText(
          text: value,
          fontSize: 13,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          color: color,
        ),
      ],
    );
  }
}

// Function to show the contribute sheet
void showContributeSheet(BuildContext context) {
  CustomBottomSheet.show(
    context,
    title: 'Add money to Group Savings',
    pages: [
      const ContributeStepOne(),
      const ContributeStepTwo(),
    ],
  ).then((result) {
    if (result == 'Success') {
      // Handle success notification or update
      context.showInAppNotification(
        'Contribution successful!',
        type: InAppNotificationType.success,
      );
    }
  });
}
