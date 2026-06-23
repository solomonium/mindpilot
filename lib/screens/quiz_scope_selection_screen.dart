import 'package:mindpilot/export.dart';

class QuizScopeSelectionScreen extends StatefulWidget {
  final String initialScopeType;
  final String initialScopeValue;

  const QuizScopeSelectionScreen({
    super.key,
    required this.initialScopeType,
    required this.initialScopeValue,
  });

  @override
  State<QuizScopeSelectionScreen> createState() => _QuizScopeSelectionScreenState();
}

class _QuizScopeSelectionScreenState extends State<QuizScopeSelectionScreen> {
  late String _selectedScopeType;
  late final TextEditingController _chapterOrTopicController;

  @override
  void initState() {
    super.initState();
    _selectedScopeType = widget.initialScopeType;
    _chapterOrTopicController = TextEditingController(text: widget.initialScopeValue);
  }

  @override
  void dispose() {
    _chapterOrTopicController.dispose();
    super.dispose();
  }

  bool get _isValid {
    if (_selectedScopeType == 'chapter' || _selectedScopeType == 'deep_learning' || _selectedScopeType == 'custom') {
      return _chapterOrTopicController.text.trim().isNotEmpty;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppTheme>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: PrimaryText(
          text: 'Select Quiz Category',
          color: theme.accentTxt,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
        leading: Icon(Icons.arrow_back_ios, color: theme.accentTxt, size: 20)
            .rippleClick(() {
          Navigator.of(context).pop();
        }),
      ),
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
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _scopeTile(theme, 'general', 'General Bible Knowledge', 'Covers Old and New Testament questions'),
                        12.verticalSpace,
                        _scopeTile(theme, 'chapter', 'Specific Chapter Study', 'Test yourself on a specific Bible book & chapter'),
                        12.verticalSpace,
                        _scopeTile(theme, 'deep_learning', 'Deep Learning & Application', 'Critical thinking and life application questions based on a specific chapter', isPremiumOnly: true),
                        12.verticalSpace,
                        _scopeTile(theme, 'tech', 'Technology & Coding', 'Questions about software engineering, programming, and tech'),
                        12.verticalSpace,
                        _scopeTile(theme, 'science', 'Science & Physics', 'Questions about physics, chemistry, astronomy, and biology'),
                        12.verticalSpace,
                        _scopeTile(theme, 'english', 'English & Literature', 'Questions about grammar, classic literature, and vocabulary'),
                        12.verticalSpace,
                        _scopeTile(theme, 'economics', 'Economics & Finance', 'Questions about finance, economics, and business'),
                        12.verticalSpace,
                        _scopeTile(theme, 'mindfulness', 'Personality & Mindfulness', 'Questions about mindfulness, positive psychology, and emotional intelligence'),
                        12.verticalSpace,
                        _scopeTile(theme, 'custom', 'Custom Topic', 'Test yourself on any custom topic you specify'),
                        
                        32.verticalSpace,
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: CustomButton(
                    label: 'Confirm Selection',
                    onPressed: _isValid
                        ? () {
                            Navigator.pop(context, {
                              'scopeType': _selectedScopeType,
                              'scopeValue': _chapterOrTopicController.text.trim(),
                            });
                          }
                        : null,
                    backgroundColor: _isValid ? theme.primaryBase : Colors.white10,
                    textColor: _isValid ? Colors.black : theme.accentTxt.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scopeTile(AppTheme theme, String scopeKey, String label, String desc, {bool isPremiumOnly = false}) {
    final isSelected = _selectedScopeType == scopeKey;
    final isPro = context.read<AppAuthProvider>().isPro;
    final showTextField = isSelected && (scopeKey == 'chapter' || scopeKey == 'deep_learning' || scopeKey == 'custom');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassContainer(
          padding: const EdgeInsets.all(16),
          gradient: isSelected ? theme.glassGradient : null,
          border: Border.all(
            color: isSelected ? theme.primaryBase : Colors.white12,
            width: isSelected ? 2.0 : 1.0,
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: isSelected ? theme.primaryBase : theme.accentTxt.withOpacity(0.4),
              ),
              16.horizontalSpace,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        PrimaryText(
                          text: label,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.accentTxt,
                        ),
                        if (isPremiumOnly) ...[
                          8.horizontalSpace,
                          const Icon(
                            Icons.star,
                            color: Color(0xFFF59E0B),
                            size: 14,
                          ),
                        ],
                      ],
                    ),
                    4.verticalSpace,
                    SecondaryText(
                      text: desc,
                      fontSize: 11,
                      color: theme.accentTxt.withOpacity(0.5),
                    ),
                  ],
                ),
              ),
              if (isPremiumOnly && !isPro)
                Icon(
                  Icons.lock_outline,
                  color: theme.accentTxt.withOpacity(0.6),
                  size: 18,
                ),
            ],
          ),
        ).rippleClick(() {
          setState(() => _selectedScopeType = scopeKey);
        }),
        if (showTextField) ...[
          12.verticalSpace,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: CustomTextField(
              textController: _chapterOrTopicController,
              autoFocus: true,
              hintText: scopeKey == 'custom' ? 'e.g. World History' : 'e.g. John 3 or Romans 8',
              textInputType: TextInputType.text,
              textInputAction: TextInputAction.done,
              labelText: scopeKey == 'custom' ? 'Enter Custom Topic' : 'Specify Bible Book & Chapter',
              labelColor: Colors.white70,
              textColor: Colors.white,
              onChanged: (val) {
                setState(() {});
              },
            ),
          ),
          12.verticalSpace,
        ],
      ],
    );
  }
}
