import 'package:mindpilot/export.dart';

class PaymentSourceTile extends StatelessWidget {
  final String label;
  final Widget? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const PaymentSourceTile({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();

    return CustomContainer(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: isSelected ? theme.primaryBase.withValues(alpha: 0.05) : theme.background,
      borderRadius: 12,
      border: Border.all(
        color: isSelected ? theme.primaryBase : theme.dividerAndBorderColor,
        width: 1.2,
      ),
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.check_box : Icons.check_box_outline_blank,
            color: isSelected ? theme.primaryBase : theme.dividerAndBorderColor,
            size: 20,
          ),
          12.horizontalSpace,
          if (icon != null) ...[
            icon!,
            12.horizontalSpace,
          ],
          Expanded(
            child: PrimaryText(
              text: label,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? theme.primaryBase : theme.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}
