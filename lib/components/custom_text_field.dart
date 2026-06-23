import 'package:mindpilot/export.dart';

class CustomTextField extends StatefulWidget {
  final Icon? icon;
  final TextInputType textInputType;
  final String? labelText;
  final Color? labelColor;
  final Color? textColor;
  final String? prefixText;
  final TextEditingController textController;
  final bool autoFocus;
  final String? Function(String?)? validate;
  final bool isPassword;
  final String? hintText;
  final TextStyle? textStyle;
  final TextInputAction textInputAction;
  final bool? obscure;
  final bool? readOnly;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final FormFieldSetter<String>? onChanged;
  final VoidCallback? onDone;
  final int? maxLines; // Add maxLines parameter
  final Color? fillColor;

  const CustomTextField({
    super.key,
    this.icon,
    this.obscure = false,
    this.readOnly,
    this.isPassword = false,
    required this.textInputType,
    this.labelText,
    this.labelColor,
    this.textColor,
    this.textStyle,
    this.prefixText,
    required this.textController,
    required this.autoFocus,
    this.validate,
    this.onChanged,
    this.suffixIcon,
    this.prefixIcon,
    this.hintText,
    required this.textInputAction,
    this.onDone,
    this.maxLines, // Initialize maxLines
    this.fillColor,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late final TextEditingController _textEditingController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textEditingController = widget.textController;
    _focusNode = FocusNode();

    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
    _textEditingController.addListener(_handleTextChange);
  }

  void _handleTextChange() {
    if (widget.validate == Validator.phone()) {
      final trimmedText = _textEditingController.text.replaceAll(' ', '');
      if (_textEditingController.text != trimmedText) {
        _textEditingController.value = _textEditingController.value.copyWith(
          text: trimmedText,
          selection: TextSelection.collapsed(offset: trimmedText.length),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    return SizedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.labelText == ''
              ? const SizedBox.shrink()
              : PrimaryText(
                  text: widget.labelText ?? '',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: widget.labelColor ?? theme.primaryText,
                ),
          5.verticalSpace,
          SizedBox(
            child: TextFormField(
              readOnly: widget.readOnly ?? false,
              style: GoogleFonts.inter(
                color: widget.textColor ?? theme.primaryText,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              cursorColor: theme.primaryBase,
              focusNode: _focusNode,
              onChanged: widget.onChanged,
              controller: _textEditingController,
              validator: widget.validate,
              textInputAction: widget.textInputAction,
              keyboardType: widget.textInputType,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              obscureText: widget.obscure!,
              obscuringCharacter: '*',
              maxLines: widget.maxLines ?? 1, // Set maxLines (default to 1)
              decoration: InputDecoration(
                hintText: widget.hintText,
                prefixText: widget.prefixText,
                hintStyle:
                    widget.textStyle ??
                    GoogleFonts.inter(
                      color: (widget.textColor == Colors.white ||
                              widget.textColor == Colors.white70 ||
                              widget.textColor == theme.accentTxt)
                          ? theme.accentTxt.withValues(alpha: 0.3)
                          : theme.hintText,
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                    ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.dividerAndBorderColor,
                    width: 0.9,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                errorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: theme.errorPrimary, width: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.dividerAndBorderColor,
                    width: 0.9,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.errorPrimary, width: 0.9),
                ),
                filled: true,
                fillColor: widget.fillColor ??
                    ((widget.textColor == Colors.white ||
                            widget.textColor == Colors.white70 ||
                            widget.textColor == theme.accentTxt)
                        ? theme.accentTxt.withValues(alpha: 0.05)
                        : theme.background),
                errorStyle: const TextStyle(),
                prefixIcon: widget.prefixIcon,
                suffixIcon: widget.isPassword
                    ? widget.suffixIcon
                    : const SizedBox(),
              ),
              onFieldSubmitted: (value) {
                if (widget.textInputAction == TextInputAction.done) {
                  widget.onDone?.call();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
