import 'package:mindpilot/export.dart';

class AiPreferencesScreen extends StatefulWidget {
  const AiPreferencesScreen({super.key});

  @override
  State<AiPreferencesScreen> createState() => _AiPreferencesScreenState();
}

class _AiPreferencesScreenState extends State<AiPreferencesScreen> {
  String _selectedTone = 'Balanced';
  String _selectedPersonality = 'Encouraging';
  String _selectedProvider = 'Direct Gemini';

  final List<String> _tones = ['Concise', 'Balanced', 'Detailed'];
  final List<String> _personalities = ['Encouraging', 'Logical', 'Direct'];
  final List<String> _providers = ['Direct Gemini', 'OpenRouter', 'Agent Router'];

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AppAuthProvider>();
    _selectedTone = authProvider.aiTone;
    _selectedPersonality = authProvider.aiPersonality;
    _selectedProvider = authProvider.selectedLlmProvider;
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    final authProvider = context.watch<AppAuthProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: PrimaryText(
          text: R.S.aiPreferences,
          color: theme.accentTxt,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Icon(
            Icons.arrow_back_ios,
            color: theme.accentTxt,
            size: 20,
          ).rippleClick(() => context.pop()),
        ),
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
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(theme, R.S.responseStyle),
                16.verticalSpace,
                _preferenceCard(
                  theme,
                  R.S.responseTone,
                  R.S.toneDesc,
                  _tones,
                  _selectedTone,
                  (val) => setState(() => _selectedTone = val),
                ),
                24.verticalSpace,
                _sectionTitle(theme, R.S.personality),
                16.verticalSpace,
                _preferenceCard(
                  theme,
                  R.S.aiPersona,
                  R.S.personaDesc,
                  _personalities,
                  _selectedPersonality,
                  (val) => setState(() => _selectedPersonality = val),
                ),
                24.verticalSpace,
                _sectionTitle(theme, 'AI Model Provider'),
                16.verticalSpace,
                _preferenceCard(
                  theme,
                  'Preferred Gateway',
                  'Select the AI gateway service used for assistant tasks.',
                  _providers,
                  _selectedProvider,
                  (val) => setState(() => _selectedProvider = val),
                ),
                32.verticalSpace,
                _sectionTitle(theme, R.S.chatManagement),
                16.verticalSpace,
                GlassContainer(
                  padding: const EdgeInsets.all(20),
                  gradient: theme.glassGradient,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PrimaryText(
                        text: R.S.resetContext,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.accentTxt,
                      ),
                      8.verticalSpace,
                      SecondaryText(
                        text: R.S.resetContextDesc,
                        fontSize: 13,
                        color: theme.accentTxt.withOpacity(0.7),
                      ),
                      20.verticalSpace,
                      CustomButton(
                        label: R.S.resetContext,
                        isOutline: true,
                        borderColor: theme.errorPrimary.withOpacity(0.5),
                        textColor: theme.errorPrimary,
                        onPressed: () {
                          context.read<ChatProvider>().resetChat();
                          context.showInAppNotification(
                            R.S.aiContextReset,
                            type: InAppNotificationType.success,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                40.verticalSpace,
                CustomButton(
                  label: R.S.savePreferences,
                  onPressed: () async {
                    await authProvider.updateAiPreferences(
                      _selectedTone,
                      _selectedPersonality,
                      _selectedProvider,
                    );
                    if (mounted) {
                      context.showInAppNotification(
                        R.S.preferencesSaved,
                        type: InAppNotificationType.success,
                      );
                      context.pop();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(AppTheme theme, String title) {
    return PrimaryText(
      text: title,
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: theme.accentTxt,
    );
  }

  Widget _preferenceCard(
    AppTheme theme,
    String title,
    String description,
    List<String> options,
    String current,
    Function(String) onSelect,
  ) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      gradient: theme.glassGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrimaryText(
            text: title,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.accentTxt,
          ),
          4.verticalSpace,
          SecondaryText(
            text: description,
            fontSize: 12,
            color: theme.accentTxt.withOpacity(0.6),
          ),
          16.verticalSpace,
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: options.map((option) {
              final isSelected = current == option;
              return GestureDetector(
                onTap: () => onSelect(option),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.primaryBase.withOpacity(0.2)
                        : theme.accentTxt.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? theme.primaryBase
                          : theme.accentTxt.withOpacity(0.1),
                    ),
                  ),
                  child: SecondaryText(
                    text: option,
                    color: isSelected
                        ? theme.primaryBase
                        : theme.accentTxt.withOpacity(0.8),
                    fontSize: 13,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
