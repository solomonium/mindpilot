import 'package:mindpilot/export.dart';

class QuickAmountChip extends StatelessWidget {
  final String amount;
  final VoidCallback onTap;
  final bool isSelected;

  const QuickAmountChip({
    super.key,
    required this.amount,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryBase.withValues(alpha: 0.1) : theme.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? theme.primaryBase : theme.dividerAndBorderColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: SecondaryText(
          text: amount,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? theme.primaryBase : theme.primaryText,
        ),
      ),
    );
  }
}
