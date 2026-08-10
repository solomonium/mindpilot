import 'package:mindpilot/export.dart';

class AiModelManagementScreen extends StatefulWidget {
  const AiModelManagementScreen({super.key});

  @override
  State<AiModelManagementScreen> createState() => _AiModelManagementScreenState();
}

class _AiModelManagementScreenState extends State<AiModelManagementScreen> {
  final TextEditingController _directModelController = TextEditingController();
  final TextEditingController _newFreeModelController = TextEditingController();
  final TextEditingController _newProModelController = TextEditingController();
  final TextEditingController _newAgentRouterModelController = TextEditingController();

  List<String> _freeModels = [];
  List<String> _proModels = [];
  List<String> _agentRouterModels = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  void _loadCurrentConfig() {
    final config = ConfigService();
    _directModelController.text = config.directGeminiModel;
    _freeModels = List<String>.from(config.openRouterFreeModels);
    _proModels = List<String>.from(config.openRouterProModels);
    _agentRouterModels = List<String>.from(config.agentRouterModels);
  }

  void _addFreeModel() {
    final model = _newFreeModelController.text.trim();
    if (model.isEmpty) return;
    if (!_freeModels.contains(model)) {
      setState(() {
        _freeModels.add(model);
        _newFreeModelController.clear();
      });
    } else {
      context.showInAppNotification('Model already exists in Free list');
    }
  }

  void _removeFreeModel(int index) {
    setState(() {
      _freeModels.removeAt(index);
    });
  }

  void _addProModel() {
    final model = _newProModelController.text.trim();
    if (model.isEmpty) return;
    if (!_proModels.contains(model)) {
      setState(() {
        _proModels.add(model);
        _newProModelController.clear();
      });
    } else {
      context.showInAppNotification('Model already exists in Pro list');
    }
  }

  void _removeProModel(int index) {
    setState(() {
      _proModels.removeAt(index);
    });
  }

  void _addAgentRouterModel() {
    final model = _newAgentRouterModelController.text.trim();
    if (model.isEmpty) return;
    if (!_agentRouterModels.contains(model)) {
      setState(() {
        _agentRouterModels.add(model);
        _newAgentRouterModelController.clear();
      });
    } else {
      context.showInAppNotification('Model already exists in Agent Router list');
    }
  }

  void _removeAgentRouterModel(int index) {
    setState(() {
      _agentRouterModels.removeAt(index);
    });
  }

  @override
  void dispose() {
    _directModelController.dispose();
    _newFreeModelController.dispose();
    _newProModelController.dispose();
    _newAgentRouterModelController.dispose();
    super.dispose();
  }

  Future<void> _saveAndDeploy() async {
    final directModel = _directModelController.text.trim();
    if (directModel.isEmpty) {
      context.showInAppNotification('Direct Gemini Model cannot be empty');
      return;
    }
    if (_freeModels.isEmpty) {
      context.showInAppNotification('Please keep at least 1 Free OpenRouter model');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('app_config')
          .doc('settings')
          .set({
        'direct_gemini_model': directModel,
        'openrouter_free_models': _freeModels,
        'openrouter_pro_models': _proModels,
        'agent_router_models': _agentRouterModels,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await ConfigService().fetchRemoteConfig();

      if (mounted) {
        context.showInAppNotification(
          'AI Model Configuration Deployed to Firebase!',
          type: InAppNotificationType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        context.showInAppNotification('Error deploying models: $e', type: InAppNotificationType.error);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch<AppTheme>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: PrimaryText(
          text: 'AI Model Management',
          color: theme.accentTxt,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
        leading: Icon(
          Icons.chevron_left,
          color: theme.accentTxt,
        ).rippleClick(() => context.pop()),
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
                _sectionHeader(theme, '1. Direct Google Gemini Model', 'Model name for direct Google Generative AI SDK calls.'),
                12.verticalSpace,
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  gradient: theme.glassGradient,
                  child: CustomTextField(
                    textController: _directModelController,
                    hintText: 'e.g. gemini-2.0-flash',
                    textInputType: TextInputType.text,
                    autoFocus: false,
                    textInputAction: TextInputAction.done,
                  ),
                ),
                28.verticalSpace,

                _sectionHeader(theme, '2. OpenRouter Free Models (Fallback List)', 'Models attempted sequentially for free users when Direct API fails.'),
                12.verticalSpace,
                _modelListCard(
                  theme: theme,
                  models: _freeModels,
                  inputController: _newFreeModelController,
                  inputHint: 'Add OpenRouter Free model ID (e.g. deepseek/deepseek-chat:free)',
                  onAdd: _addFreeModel,
                  onRemove: _removeFreeModel,
                ),
                28.verticalSpace,

                _sectionHeader(theme, '3. OpenRouter Pro Models (Premium Tier)', 'Premium models attempted for Pro subscribers.'),
                12.verticalSpace,
                _modelListCard(
                  theme: theme,
                  models: _proModels,
                  inputController: _newProModelController,
                  inputHint: 'Add OpenRouter Pro model ID (e.g. google/gemini-2.0-flash-001)',
                  onAdd: _addProModel,
                  onRemove: _removeProModel,
                ),
                28.verticalSpace,

                _sectionHeader(theme, '4. Agent Router Models', 'Models configured for Agent Router gateway.'),
                12.verticalSpace,
                _modelListCard(
                  theme: theme,
                  models: _agentRouterModels,
                  inputController: _newAgentRouterModelController,
                  inputHint: 'Add Agent Router model ID (e.g. anthropic/claude-3.5-sonnet)',
                  onAdd: _addAgentRouterModel,
                  onRemove: _removeAgentRouterModel,
                ),
                36.verticalSpace,

                CustomButton(
                  label: _isSaving ? 'Deploying to Firebase...' : 'Save & Deploy Configuration',
                  loading: _isSaving,
                  onPressed: _saveAndDeploy,
                ),
                32.verticalSpace,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(AppTheme theme, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PrimaryText(
          text: title,
          color: theme.accentTxt,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
        4.verticalSpace,
        SecondaryText(
          text: subtitle,
          color: theme.accentTxt.withOpacity(0.6),
          fontSize: 12,
        ),
      ],
    );
  }

  Widget _modelListCard({
    required AppTheme theme,
    required List<String> models,
    required TextEditingController inputController,
    required String inputHint,
    required VoidCallback onAdd,
    required Function(int) onRemove,
  }) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      gradient: theme.glassGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  textController: inputController,
                  hintText: inputHint,
                  textInputType: TextInputType.text,
                  autoFocus: false,
                  textInputAction: TextInputAction.done,
                ),
              ),
              10.horizontalSpace,
              Container(
                decoration: BoxDecoration(
                  color: theme.primaryBase,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(12),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ).rippleClick(onAdd),
            ],
          ),
          16.verticalSpace,
          if (models.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SecondaryText(
                  text: 'No models configured in this list.',
                  color: theme.accentTxt.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: models.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = models.removeAt(oldIndex);
                  models.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final model = models[index];
                return Container(
                  key: ValueKey(model),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.accentTxt.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.accentTxt.withOpacity(0.12)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.drag_indicator, color: theme.accentTxt.withOpacity(0.4), size: 20),
                      10.horizontalSpace,
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.primaryBase.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: SecondaryText(
                          text: '#${index + 1}',
                          color: theme.primaryBase,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      10.horizontalSpace,
                      Expanded(
                        child: PrimaryText(
                          text: model,
                          color: theme.accentTxt,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Icon(
                        Icons.delete_outline,
                        color: theme.errorPrimary.withOpacity(0.8),
                        size: 20,
                      ).rippleClick(() => onRemove(index)),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
