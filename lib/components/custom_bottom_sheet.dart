import 'package:mindpilot/export.dart';

class CustomBottomSheet extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<Widget> pages;
  final bool showHeader;
  final bool isDismissible;

  const CustomBottomSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.pages,
    this.showHeader = true,
    this.isDismissible = true,
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    String? subtitle,
    required List<Widget> pages,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: isDismissible,
      builder: (context) => CustomBottomSheet(
        title: title,
        subtitle: subtitle,
        pages: pages,
        isDismissible: isDismissible,
      ),
    );
  }

  @override
  State<CustomBottomSheet> createState() => CustomBottomSheetState();
}

class CustomBottomSheetState extends State<CustomBottomSheet> {
  int _currentIndex = 0;

  void nextPage() {
    if (_currentIndex < widget.pages.length - 1) {
      setState(() => _currentIndex++);
    }
  }

  void previousPage() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  void setPage(int index) {
    if (index >= 0 && index < widget.pages.length) {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    final mediaQuery = MediaQuery.of(context);

    // Provide navigation to children via InheritedWidget or just pass through if needed
    // For now, we'll use a simple approach where children can access navigation
    // if I use a builder, but for now let's keep it simple as requested.
    
    return Container(
      decoration: BoxDecoration(
        color: theme.whiteBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: mediaQuery.viewInsets.bottom + 24, // Account for keyboard
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Dynamic height
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme, context),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: widget.pages[_currentIndex],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppTheme theme, BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Back Button (only if not on first page)
          if (_currentIndex > 0)
            GestureDetector(
              onTap: previousPage,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, size: 20, color: theme.primaryText),
                  8.horizontalSpace,
                  SecondaryText(
                    text: 'Back',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.primaryText,
                  ),
                ],
              ),
            ),

          // Title & Subtitle (Centered or Left depending on Design)
          // In the image, title moves slightly when back is present.
          // Let's keep it left-aligned but with padding if back is present.
          Padding(
            padding: EdgeInsets.only(left: _currentIndex > 0 ? 60 : 0, right: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                PrimaryText(
                  text: widget.title,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                if (widget.subtitle != null) ...[
                  4.verticalSpace,
                  SecondaryText(
                    text: widget.subtitle!,
                    fontSize: 14,
                    color: theme.hintText,
                  ),
                ],
              ],
            ),
          ),

          // Close Button
          Positioned(
            right: 0,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.dividerAndBorderColor, width: 1),
                ),
                child: Icon(Icons.close, size: 16, color: theme.hintText),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Extension to allow pages to trigger navigation
extension CustomBottomSheetNavigation on BuildContext {
  void nextBottomSheetPage() {
    final state = findAncestorStateOfType<CustomBottomSheetState>();
    state?.nextPage();
  }

  void previousBottomSheetPage() {
    final state = findAncestorStateOfType<CustomBottomSheetState>();
    state?.previousPage();
  }

  void setBottomSheetPage(int index) {
    final state = findAncestorStateOfType<CustomBottomSheetState>();
    state?.setPage(index);
  }
}
