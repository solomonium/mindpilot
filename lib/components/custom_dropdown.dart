import 'package:mindpilot/export.dart';

typedef ItemBuilder<T> = Widget Function(BuildContext context, T item);

class CustomDropdown<T> extends StatelessWidget {
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final ItemBuilder<T>? itemBuilder;
  final String? hint;
  final String? labelText;
  final Widget? child;
  final BoxDecoration? decoration;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const CustomDropdown({
    super.key,
    this.value,
    required this.items,
    required this.onChanged,
    this.itemBuilder,
    this.hint,
    this.labelText,
    this.child,
    this.decoration,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();

    Widget dropdown = DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isExpanded: child == null,
        hint: child ??
            SecondaryText(
              text: hint ?? 'Select option',
              color: theme.hintText,
            ),
        icon: child != null ? const SizedBox.shrink() : Icon(Icons.keyboard_arrow_down, color: theme.hintText),
        items: items.map((T item) {
          return DropdownMenuItem<T>(
            value: item,
            child: itemBuilder != null
                ? itemBuilder!(context, item)
                : SecondaryText(
                    text: item.toString(),
                    color: theme.primaryText,
                  ),
          );
        }).toList(),
        onChanged: onChanged,
        dropdownColor: theme.background,
        borderRadius: BorderRadius.circular(12),
      ),
    );

    Widget trigger = child != null
        ? (onTap != null
            ? GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: child,
              )
            : dropdown)
        : dropdown;

    if (child != null) return trigger;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText != null && labelText!.isNotEmpty) ...[
          PrimaryText(
            text: labelText!,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          8.verticalSpace,
        ],
        Container(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
          decoration: decoration ??
              BoxDecoration(
                color: theme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.dividerAndBorderColor,
                  width: 0.9,
                ),
              ),
          child: dropdown,
        ),
      ],
    );
  }
}
