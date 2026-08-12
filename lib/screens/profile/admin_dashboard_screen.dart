import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:mindpilot/export.dart';
import 'package:mindpilot/screens/profile/ai_model_management_screen.dart';

class ModelHealthCheckResult {
  final String modelId;
  final String category; // 'Direct Gemini', 'OpenRouter Free', 'OpenRouter Pro'
  final bool isOk;
  final String statusText;
  final int latencyMs;
  final bool isActive;

  ModelHealthCheckResult({
    required this.modelId,
    required this.category,
    required this.isOk,
    required this.statusText,
    required this.latencyMs,
    required this.isActive,
  });
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final TextEditingController _emailController = TextEditingController();
  final List<String> _superAdmins = [
    'laleyesolomon2@gmail.com',
    'solteqinnovationsltd@gmail.com',
  ];
  bool _isLoading = false;
  bool _isBroadcasting = false;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _versionController = TextEditingController();
  final TextEditingController _intervalController = TextEditingController();
  final TextEditingController _updateUrlController = TextEditingController();
  bool _forceUpdateValue = false;
  bool _isEditMode = false;
  bool _isUpdatingConfig = false;

  bool _isCheckingHealth = false;
  String? _directGeminiStatus;
  bool? _directGeminiOk;
  String? _openRouterStatus;
  bool? _openRouterOk;
  List<ModelHealthCheckResult> _healthCheckResults = [];
  String? _autoSwitchLog;
  bool _isHealthResultsExpanded = true;

  int _totalUsers = 0;
  bool _isLoadingUsersCount = true;
  bool _isPurgingLogs = false;

  @override
  void initState() {
    super.initState();
    final config = ConfigService();
    _phoneController.text = config.supportPhone;
    _versionController.text = config.latestVersion;
    _intervalController.text = (config.quoteIntervalMs / 60000)
        .round()
        .toString();
    _updateUrlController.text = config.updateUrl;
    _forceUpdateValue = config.forceUpdate;
    _fetchTotalUsers();
  }

  Future<void> _fetchTotalUsers() async {
    try {
      final countSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .count()
          .get();
      final count = countSnapshot.count ?? 0;

      setState(() {
        _totalUsers = count;
        _isLoadingUsersCount = false;
      });

      // Self-healing: automatically synchronize the authenticated users count
      // in the settings collection with the actual number of registered users in Firestore.
      final config = ConfigService();
      if (config.authenticatedUsersCount != count) {
        await FirebaseFirestore.instance
            .collection('app_config')
            .doc('settings')
            .set({'authenticated_users_count': count}, SetOptions(merge: true));
        await config.fetchRemoteConfig();
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Error fetching user count: $e');
      setState(() => _isLoadingUsersCount = false);
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
          text: 'Admin Dashboard',
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
                _sectionTitle(context, 'App Configuration'),
                16.verticalSpace,
                _configCard(context),
                32.verticalSpace,
                _sectionTitle(context, 'AI Model Configurations'),
                16.verticalSpace,
                _aiModelManagementCard(context),
                32.verticalSpace,
                _sectionTitle(context, 'Live Gateway Health & Downtime'),
                16.verticalSpace,
                _healthCheckCard(context),
                32.verticalSpace,
                if (FirebaseAuth.instance.currentUser?.email == 'laleyesolomon2@gmail.com') ...[
                  _sectionTitle(context, 'Gemini API Quota Tracking'),
                  16.verticalSpace,
                  _quotaTrackerCard(context),
                  32.verticalSpace,
                ],
                _sectionTitle(context, 'Broadcast System'),
                16.verticalSpace,
                _broadcastCard(context),
                32.verticalSpace,
                _sectionTitle(context, 'Feedback Card Control'),
                16.verticalSpace,
                _feedbackToggleCard(context),
                32.verticalSpace,
                _sectionTitle(context, 'User Membership Management'),
                16.verticalSpace,
                _allRegisteredUsersCard(context),
                32.verticalSpace,
                _sectionTitle(context, 'Manage Admin Privileges'),
                16.verticalSpace,
                _addAdminRow(context),
                24.verticalSpace,
                _adminList(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _selectedBroadcastType = 'update';
  final TextEditingController _broadcastTitleController = TextEditingController(
    text: 'Daily Reflection',
  );
  final TextEditingController _broadcastBodyController = TextEditingController(
    text:
        'Take a moment to reflect on your achievements today. You are making great progress!',
  );

  Widget _broadcastCard(BuildContext context) {
    AppTheme theme = context.watch<AppTheme>();
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      gradient: theme.glassGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SecondaryText(
            text: 'Send a broadcast message to all users instantly.',
            color: theme.accentTxt.withOpacity(0.7),
            fontSize: 13,
          ),
          20.verticalSpace,
          _configEditField(theme, 'Broadcast Title', _broadcastTitleController),
          16.verticalSpace,
          _configEditField(
            theme,
            'Broadcast Message',
            _broadcastBodyController,
            maxLines: 5,
          ),
          16.verticalSpace,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SecondaryText(
                text: 'Broadcast Type:',
                color: theme.accentTxt.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              8.verticalSpace,
              Row(
                children: [
                  Expanded(child: _typeOption('Regular Alert', 'update')),
                  12.horizontalSpace,
                  Expanded(child: _typeOption('Daily Insight', 'insight')),
                ],
              ),
            ],
          ),
          16.verticalSpace,
          SecondaryText(
            text: 'Quick Templates:',
            color: theme.accentTxt.withOpacity(0.5),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
          8.verticalSpace,
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _templateChip(
                  'Task Reminder',
                  'Have you completed your tasks today?',
                ),
                8.horizontalSpace,
                _templateChip(
                  'Learning Check',
                  'What have you learned today that made you better?',
                ),
                8.horizontalSpace,
                _templateChip(
                  'Focus Mode',
                  'Time to dive into a focus session and get things done!',
                ),
                8.horizontalSpace,
                _templateChip(
                  'Insight of the Day',
                  'Growth begins where your comfort zone ends. Push yourself today!',
                  isInsight: true,
                ),
              ],
            ),
          ),
          24.verticalSpace,
          CustomButton(
            label: 'Deploy Broadcast',
            loading: _isBroadcasting,
            onPressed: _sendBroadcastReminder,
          ),
          12.verticalSpace,
          CustomButton(
            label: 'Prompt All Unconfigured Users for Push Notifications 🔔',
            onPressed: () async {
              try {
                await FirebaseFirestore.instance.collection('app_config').doc('settings').set({
                  'force_push_prompt_timestamp': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));

                if (context.mounted) {
                  context.showInAppNotification(
                    'Push Notification Setup prompt dispatched app-wide!',
                    type: InAppNotificationType.success,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  context.showInAppNotification(
                    'Failed to dispatch prompt: $e',
                    type: InAppNotificationType.error,
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _sendBroadcastReminder() async {
    final title = _broadcastTitleController.text.trim();
    final body = _broadcastBodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      context.showInAppNotification('Title and message are required');
      return;
    }

    setState(() => _isBroadcasting = true);
    try {
      // Find if an identical broadcast already exists in Firestore
      final existingQuery = await FirebaseFirestore.instance
          .collection('broadcasts')
          .where('title', isEqualTo: title)
          .where('body', isEqualTo: body)
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        final doc = existingQuery.docs.first;
        final lastCreated = doc.data()['createdAt'] as Timestamp?;

        // Prevent rapid double-sends within a 1-minute window
        if (lastCreated != null) {
          final difference = DateTime.now().difference(lastCreated.toDate());
          if (difference.inSeconds < 60) {
            if (mounted) {
              context.showInAppNotification(
                '⚠️ Duplicate broadcast blocked to prevent spamming users.',
                type: InAppNotificationType.error,
              );
            }
            setState(() => _isBroadcasting = false);
            return;
          }
        }

        // Reuse the document and update its timestamp to trigger all listeners
        await FirebaseFirestore.instance
            .collection('broadcasts')
            .doc(doc.id)
            .update({'createdAt': FieldValue.serverTimestamp()});
      } else {
        // Create a new document if it does not exist
        await FirebaseFirestore.instance.collection('broadcasts').add({
          'title': title,
          'body': body,
          'type': _selectedBroadcastType,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        context.showInAppNotification(
          '🚀 Broadcast Sent Successfully!',
          type: InAppNotificationType.success,
        );
      }
    } catch (e) {
      if (mounted) context.showInAppNotification('Error: $e');
    }
    setState(() => _isBroadcasting = false);
  }

  Widget _allRegisteredUsersCard(BuildContext context) {
    AppTheme theme = context.watch<AppTheme>();
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      gradient: theme.glassGradient,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PrimaryText(
                  text: 'Registered Users Directory',
                  color: theme.accentTxt,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                4.verticalSpace,
                SecondaryText(
                  text: 'View directory, copy emails, and modify membership tiers.',
                  color: theme.accentTxt.withOpacity(0.6),
                  fontSize: 12,
                ),
              ],
            ),
          ),
          12.horizontalSpace,
          Icon(
            Icons.chevron_right,
            color: theme.primaryBase,
            size: 24,
          ),
        ],
      ),
    ).rippleClick(() {
      context.push(const AllRegisteredUsersScreen());
    });
  }

  Widget _sectionTitle(BuildContext context, String title) {
    AppTheme theme = context.watch<AppTheme>();
    return PrimaryText(
      text: title,
      color: theme.accentTxt,
      fontSize: 16,
      fontWeight: FontWeight.bold,
    );
  }

  Widget _configCard(BuildContext context) {
    AppTheme theme = context.watch<AppTheme>();
    final config = ConfigService();
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      gradient: theme.glassGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _configItem(
            'Registered Users (Firestore)',
            _isLoadingUsersCount ? 'Loading...' : '$_totalUsers',
          ),
          _configItem(
            'Total Authenticated (Config)',
            config.authenticatedUsersCount.toString(),
          ),
          _configItem('Version', config.latestVersion),
          _configItem(
            'Interval (mins)',
            (config.quoteIntervalMs / 60000).round().toString(),
          ),
          _configItem('Force Update', config.forceUpdate ? 'YES' : 'NO'),
          _configItem('Support Phone', config.supportPhone),
          16.verticalSpace,
          Row(
            children: [
              Checkbox(
                value: _isEditMode,
                activeColor: theme.primaryBase,
                onChanged: (val) => setState(() => _isEditMode = val ?? false),
              ),
              SecondaryText(
                text: 'Enable Configuration Edit Mode',
                color: theme.accentTxt,
                fontSize: 13,
              ),
            ],
          ),
          if (_isEditMode) ...[
            20.verticalSpace,
            const Divider(color: Colors.white24),
            20.verticalSpace,
            _configEditField(theme, 'Latest Version', _versionController),
            16.verticalSpace,
            _configEditField(
              theme,
              'Quote Interval (Minutes)',
              _intervalController,
              isNumber: true,
            ),
            16.verticalSpace,
            _configEditField(theme, 'Update URL', _updateUrlController),
            16.verticalSpace,
            _configEditField(theme, 'Support Phone', _phoneController),
            16.verticalSpace,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SecondaryText(
                  text: 'Force Update Required',
                  color: theme.accentTxt.withOpacity(0.7),
                ),
                Switch(
                  value: _forceUpdateValue,
                  activeColor: theme.primaryBase,
                  onChanged: (val) => setState(() => _forceUpdateValue = val),
                ),
              ],
            ),
            24.verticalSpace,
            CustomButton(
              label: 'Save & Deploy Configuration',
              loading: _isUpdatingConfig,
              onPressed: _updateRemoteConfig,
            ),
          ],
          if (!_isEditMode) ...[
            16.verticalSpace,
            Center(
              child:
                  SecondaryText(
                    text: 'Refresh Current Settings',
                    color: theme.primaryBase.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ).rippleClick(() async {
                    await config.fetchRemoteConfig();
                    await _fetchTotalUsers();
                    setState(() {
                      _phoneController.text = config.supportPhone;
                      _versionController.text = config.latestVersion;
                      _intervalController.text =
                          (config.quoteIntervalMs / 60000).round().toString();
                      _updateUrlController.text = config.updateUrl;
                      _forceUpdateValue = config.forceUpdate;
                    });
                    if (mounted) {
                      context.showInAppNotification(
                        'System settings refreshed!',
                        type: InAppNotificationType.success,
                      );
                    }
                  }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _aiModelManagementCard(BuildContext context) {
    AppTheme theme = context.watch<AppTheme>();
    final config = ConfigService();

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      gradient: theme.glassGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SecondaryText(
                  text: 'Manage lists of Direct Gemini models and OpenRouter fallback candidate lists.',
                  color: theme.accentTxt.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          16.verticalSpace,
          _configItem('Direct Gemini Model', config.directGeminiModel),
          _configItem('OpenRouter Free List', '${config.openRouterFreeModels.length} Active Models'),
          _configItem('OpenRouter Pro List', '${config.openRouterProModels.length} Active Models'),
          20.verticalSpace,
          CustomButton(
            label: 'Manage & Reorder AI Model Lists',
            onPressed: () {
              context.push(const AiModelManagementScreen());
            },
          ),
        ],
      ),
    );
  }

  Widget _configEditField(
    AppTheme theme,
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    int? maxLines,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SecondaryText(
          text: label,
          color: theme.accentTxt.withOpacity(0.7),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        4.verticalSpace,
        CustomTextField(
          textController: controller,
          hintText: 'Enter $label',
          textInputType: isNumber
              ? TextInputType.number
              : (maxLines != null
                    ? TextInputType.multiline
                    : TextInputType.text),
          autoFocus: false,
          maxLines: maxLines,
          textInputAction: maxLines != null
              ? TextInputAction.newline
              : TextInputAction.next,
        ),
      ],
    );
  }

  Future<void> _updateRemoteConfig() async {
    final phone = _phoneController.text.trim();
    final version = _versionController.text.trim();
    final intervalStr = _intervalController.text.trim();
    final updateUrl = _updateUrlController.text.trim();

    if (phone.isEmpty ||
        version.isEmpty ||
        intervalStr.isEmpty ||
        updateUrl.isEmpty) {
      context.showInAppNotification('All fields are required');
      return;
    }

    final intervalMinutes = int.tryParse(intervalStr);
    if (intervalMinutes == null) {
      context.showInAppNotification('Interval must be a number');
      return;
    }

    final intervalMs = intervalMinutes * 60000;

    setState(() => _isUpdatingConfig = true);
    try {
      await FirebaseFirestore.instance
          .collection('app_config')
          .doc('settings')
          .set({
            'support_phone': phone,
            'latest_version': version,
            'quote_interval_ms': intervalMs,
            'update_url': updateUrl,
            'force_update': _forceUpdateValue,
            'authenticated_users_count': _totalUsers,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Refresh local config
      await ConfigService().fetchRemoteConfig();

      if (mounted) {
        context.showInAppNotification(
          'Remote Configuration Deployed Successfully!',
          type: InAppNotificationType.success,
        );
        setState(() => _isEditMode = false);
      }
    } catch (e) {
      if (mounted) context.showInAppNotification('Error: $e');
    } finally {
      setState(() => _isUpdatingConfig = false);
    }
  }

  Widget _healthCheckCard(BuildContext context) {
    AppTheme theme = context.watch<AppTheme>();
    final directModelName = ConfigService().directGeminiModel.isNotEmpty
        ? ConfigService().directGeminiModel
        : 'gemini-2.0-flash';
    final freeModels = ConfigService().openRouterFreeModels;
    final openRouterModel = freeModels.isNotEmpty ? freeModels.first : 'google/gemma-4-31b-it:free';

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      gradient: theme.glassGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SecondaryText(
            text: 'Run real-time API health checks to test model availability, iterate through candidate models, and automatically switch to an available operational model.',
            color: theme.accentTxt.withOpacity(0.7),
            fontSize: 13,
          ),
          16.verticalSpace,
          if (_autoSwitchLog != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.successPrimary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.successPrimary.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: theme.successPrimary, size: 20),
                  10.horizontalSpace,
                  Expanded(
                    child: SecondaryText(
                      text: _autoSwitchLog!,
                      color: theme.successPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            16.verticalSpace,
          ],
          if (_healthCheckResults.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: PrimaryText(
                    text: 'Model Iteration Results (${_healthCheckResults.where((r) => r.isOk).length}/${_healthCheckResults.length} Operational)',
                    color: theme.accentTxt,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                10.horizontalSpace,
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.accentTxt.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SecondaryText(
                        text: _isHealthResultsExpanded ? 'Collapse' : 'Expand',
                        color: theme.accentTxt.withOpacity(0.8),
                        fontSize: 11,
                      ),
                      4.horizontalSpace,
                      Icon(
                        _isHealthResultsExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: theme.accentTxt,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ).rippleClick(() {
              setState(() {
                _isHealthResultsExpanded = !_isHealthResultsExpanded;
              });
            }),
            12.verticalSpace,
            if (_isHealthResultsExpanded) ...[
              ..._buildHealthResultsList(theme),
              16.verticalSpace,
            ],
          ] else ...[
            _healthStatusRow(
              theme,
              'Direct Gemini Gateway ($directModelName)',
              _directGeminiOk,
              _directGeminiStatus,
            ),
            16.verticalSpace,
            _healthStatusRow(
              theme,
              'OpenRouter Gateway ($openRouterModel)',
              _openRouterOk,
              _openRouterStatus,
            ),
            20.verticalSpace,
          ],
          CustomButton(
            label: _isCheckingHealth ? 'Testing & Switching Models...' : 'Check API Models & Auto-Switch Downtime',
            loading: _isCheckingHealth,
            onPressed: _runHealthCheck,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildHealthResultsList(AppTheme theme) {
    final categories = ['Direct Gemini', 'OpenRouter Free', 'OpenRouter Pro'];
    List<Widget> widgets = [];

    for (var cat in categories) {
      final items = _healthCheckResults.where((r) => r.category == cat).toList();
      if (items.isEmpty) continue;

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 6.0),
          child: SecondaryText(
            text: '$cat Models',
            color: theme.primaryBase,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      for (var item in items) {
        widgets.add(
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.accentTxt.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: item.isActive
                    ? theme.primaryBase.withOpacity(0.5)
                    : theme.accentTxt.withOpacity(0.1),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  item.isOk ? Icons.check_circle : Icons.cancel,
                  color: item.isOk ? theme.successPrimary : theme.errorPrimary,
                  size: 18,
                ),
                10.horizontalSpace,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryText(
                              text: item.modelId,
                              color: theme.accentTxt,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (item.isActive) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.primaryBase.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: SecondaryText(
                                text: 'ACTIVE & ENABLED',
                                color: theme.primaryBase,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                      2.verticalSpace,
                      SecondaryText(
                        text: item.statusText,
                        color: item.isOk
                            ? theme.successPrimary
                            : theme.errorPrimary,
                        fontSize: 11,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _healthStatusRow(
    AppTheme theme,
    String gatewayName,
    bool? isOk,
    String? statusText,
  ) {
    Color iconColor = Colors.white54;
    IconData iconData = Icons.help_outline;

    if (isOk == true) {
      iconColor = theme.successPrimary;
      iconData = Icons.check_circle_outline;
    } else if (isOk == false) {
      iconColor = theme.errorPrimary;
      iconData = Icons.error_outline;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(iconData, color: iconColor, size: 20),
            8.horizontalSpace,
            Expanded(
              child: PrimaryText(
                text: gatewayName,
                color: theme.accentTxt,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (statusText != null && statusText.isNotEmpty) ...[
          6.verticalSpace,
          Padding(
            padding: const EdgeInsets.only(left: 28.0),
            child: SecondaryText(
              text: statusText,
              color: isOk == true
                  ? theme.successPrimary
                  : (isOk == false ? theme.errorPrimary : theme.accentTxt.withOpacity(0.7)),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  String _formatOpenRouterStatusError(int statusCode, dynamic data) {
    String serverMsg = '';
    if (data != null && data['error'] != null) {
      if (data['error'] is Map) {
        serverMsg = data['error']['message']?.toString() ?? data['error'].toString();
      } else {
        serverMsg = data['error'].toString();
      }
    }

    switch (statusCode) {
      case 400:
        return 'Invalid Model ID (HTTP 400: $serverMsg)';
      case 401:
        return 'Authentication Failed (HTTP 401: Invalid or revoked OpenRouter API Key)';
      case 402:
        return 'Payment/Credits Required (HTTP 402: $serverMsg)';
      case 404:
        return 'Model Not Found (HTTP 404: $serverMsg)';
      case 429:
        return 'Rate Limited (HTTP 429: Too many requests on OpenRouter free tier)';
      default:
        return 'HTTP $statusCode${serverMsg.isNotEmpty ? ": $serverMsg" : ""}';
    }
  }

  String _formatHealthError(dynamic e) {
    final str = e.toString();
    if (str.contains('Failed host lookup') ||
        str.contains('SocketException') ||
        str.contains('No address associated with hostname') ||
        str.contains('connectionError')) {
      return 'No Internet Connection (DNS lookup failed)';
    }
    if (str.contains('TimeoutException') ||
        str.contains('connectTimeout') ||
        str.contains('receiveTimeout') ||
        str.contains('sendTimeout')) {
      return 'Request Timed Out (>15s)';
    }
    return 'Downtime ($str)';
  }

  Future<void> _runHealthCheck() async {
    setState(() {
      _isCheckingHealth = true;
      _healthCheckResults.clear();
      _autoSwitchLog = null;
      _isHealthResultsExpanded = true;
      _directGeminiStatus = 'Testing Direct Gemini models...';
      _openRouterStatus = 'Testing OpenRouter models...';
      _directGeminiOk = null;
      _openRouterOk = null;
    });

    final dio = Dio();
    final List<String> autoSwitchEvents = [];
    bool needsFirestoreUpdate = false;

    // 1. ITERATE DIRECT GEMINI CANDIDATE MODELS
    final geminiApiKey = dotenv.env['GEMINI_API_KEY'];
    final rawPrimaryGeminiModel = ConfigService().directGeminiModel.isNotEmpty
        ? ConfigService().directGeminiModel
        : 'gemini-2.0-flash';
    final primaryGeminiModel = rawPrimaryGeminiModel.replaceAll(RegExp(r'^google/'), '');

    final candidateGeminiModels = [
      primaryGeminiModel,
      'gemini-2.5-flash',
      'gemini-3.5-flash',
      'gemini-flash-latest',
      'gemini-2.0-flash',
      'gemini-2.0-flash-lite',
      'gemini-1.5-flash',
      'gemini-1.5-pro',
    ].map((m) => m.replaceAll(RegExp(r'^google/'), '')).toSet().toList();

    String? workingGeminiModel;

    if (geminiApiKey == null || geminiApiKey.isEmpty) {
      _directGeminiOk = false;
      _directGeminiStatus = 'Downtime (GEMINI_API_KEY missing)';
      _healthCheckResults.add(
        ModelHealthCheckResult(
          modelId: primaryGeminiModel,
          category: 'Direct Gemini',
          isOk: false,
          statusText: 'GEMINI_API_KEY not configured in .env',
          latencyMs: 0,
          isActive: true,
        ),
      );
    } else {
      for (int i = 0; i < candidateGeminiModels.length; i++) {
        final modelName = candidateGeminiModels[i];
        final bool isPrimary = (modelName == primaryGeminiModel);
        final Stopwatch sw = Stopwatch()..start();
        try {
          final model = GenerativeModel(
            model: modelName,
            apiKey: geminiApiKey,
          );
          final response = await model
              .generateContent([Content.text('Ping')])
              .timeout(const Duration(seconds: 15));
          sw.stop();

          if (response.text != null && response.text!.isNotEmpty) {
            if (workingGeminiModel == null) {
              workingGeminiModel = modelName;
            }
            _healthCheckResults.add(
              ModelHealthCheckResult(
                modelId: modelName,
                category: 'Direct Gemini',
                isOk: true,
                statusText: 'Operational — ${sw.elapsedMilliseconds}ms',
                latencyMs: sw.elapsedMilliseconds,
                isActive: isPrimary,
              ),
            );
          } else {
            _healthCheckResults.add(
              ModelHealthCheckResult(
                modelId: modelName,
                category: 'Direct Gemini',
                isOk: false,
                statusText: 'Degraded — empty response',
                latencyMs: sw.elapsedMilliseconds,
                isActive: isPrimary,
              ),
            );
          }
        } catch (e) {
          sw.stop();
          _healthCheckResults.add(
            ModelHealthCheckResult(
              modelId: modelName,
              category: 'Direct Gemini',
              isOk: false,
              statusText: _formatHealthError(e),
              latencyMs: sw.elapsedMilliseconds,
              isActive: isPrimary,
            ),
          );
        }
      }

      final primaryResult = _healthCheckResults.firstWhere(
        (r) => r.category == 'Direct Gemini' && r.modelId == primaryGeminiModel,
        orElse: () => _healthCheckResults.first,
      );

      _directGeminiOk = primaryResult.isOk;
      _directGeminiStatus = primaryResult.statusText;

      if (!primaryResult.isOk && workingGeminiModel != null && workingGeminiModel != primaryGeminiModel) {
        autoSwitchEvents.add('Auto-Switched Direct Gemini from "$primaryGeminiModel" to "$workingGeminiModel"');
        needsFirestoreUpdate = true;
      }
    }

    // 2. ITERATE OPENROUTER FREE MODELS
    final openRouterApiKey = (dotenv.env['OPEN_ROUTER_API_KEY'] ?? '').trim();
    // Only test models that end with :free or are valid free endpoints
    List<String> currentFreeModels = ConfigService()
        .openRouterFreeModels
        .where((m) => m.contains(':free'))
        .toList();
    if (currentFreeModels.isEmpty) {
      currentFreeModels = [
        'google/gemma-4-31b-it:free',
        'google/gemma-4-26b-a4b-it:free',
        'openai/gpt-oss-20b:free',
      ];
    }
    String? workingFreeModel;
    final List<String> invalidFreeModels = [];

    if (openRouterApiKey.isEmpty) {
      _openRouterOk = false;
      _openRouterStatus = 'Downtime (OPEN_ROUTER_API_KEY missing)';
      if (currentFreeModels.isNotEmpty) {
        _healthCheckResults.add(
          ModelHealthCheckResult(
            modelId: currentFreeModels.first,
            category: 'OpenRouter Free',
            isOk: false,
            statusText: 'OPEN_ROUTER_API_KEY not configured in .env',
            latencyMs: 0,
            isActive: true,
          ),
        );
      }
    } else {
      for (int i = 0; i < currentFreeModels.length; i++) {
        final m = currentFreeModels[i];
        final bool isPrimary = (i == 0);
        final Stopwatch sw = Stopwatch()..start();
        try {
          final response = await dio.post(
            'https://openrouter.ai/api/v1/chat/completions',
            options: Options(
              headers: {
                'Authorization': 'Bearer $openRouterApiKey',
                'Content-Type': 'application/json',
                'HTTP-Referer': 'https://mindpilot-131f1.web.app/',
                'X-Title': 'MindPilot Health Check',
              },
              validateStatus: (s) => s != null && s < 600,
              receiveTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 15),
            ),
            data: {
              'model': m,
              'messages': [
                {'role': 'user', 'content': 'Ping'}
              ],
              'max_tokens': 5,
            },
          ).timeout(const Duration(seconds: 15));
          sw.stop();

          if (response.statusCode == 200 &&
              response.data != null &&
              response.data['choices'] != null &&
              (response.data['choices'] as List).isNotEmpty) {
            if (workingFreeModel == null) {
              workingFreeModel = m;
            }
            _healthCheckResults.add(
              ModelHealthCheckResult(
                modelId: m,
                category: 'OpenRouter Free',
                isOk: true,
                statusText: 'Operational — ${sw.elapsedMilliseconds}ms',
                latencyMs: sw.elapsedMilliseconds,
                isActive: isPrimary,
              ),
            );
          } else {
            if (response.statusCode == 400 || response.statusCode == 404 || response.statusCode == 402) {
              invalidFreeModels.add(m);
            }
            _healthCheckResults.add(
              ModelHealthCheckResult(
                modelId: m,
                category: 'OpenRouter Free',
                isOk: false,
                statusText: _formatOpenRouterStatusError(response.statusCode ?? 500, response.data),
                latencyMs: sw.elapsedMilliseconds,
                isActive: isPrimary,
              ),
            );
          }
        } catch (e) {
          sw.stop();
          _healthCheckResults.add(
            ModelHealthCheckResult(
              modelId: m,
              category: 'OpenRouter Free',
              isOk: false,
              statusText: _formatHealthError(e),
              latencyMs: sw.elapsedMilliseconds,
              isActive: isPrimary,
            ),
          );
        }
      }

      // Strip out invalid/non-free models
      if (invalidFreeModels.isNotEmpty) {
        currentFreeModels.removeWhere((m) => invalidFreeModels.contains(m));
        needsFirestoreUpdate = true;
      }

      final primaryFreeResult = _healthCheckResults.firstWhere(
        (r) => r.category == 'OpenRouter Free' && r.isActive,
        orElse: () => _healthCheckResults.firstWhere((r) => r.category == 'OpenRouter Free'),
      );
      _openRouterOk = primaryFreeResult.isOk;
      _openRouterStatus = primaryFreeResult.statusText;

      if (workingFreeModel != null && currentFreeModels.isNotEmpty && workingFreeModel != currentFreeModels.first) {
        currentFreeModels.remove(workingFreeModel);
        currentFreeModels.insert(0, workingFreeModel);
        autoSwitchEvents.add('Promoted operational Free model: "$workingFreeModel" to primary.');
        needsFirestoreUpdate = true;
      }
    }

    // 3. ITERATE OPENROUTER PRO MODELS (Claude, ChatGPT, DeepSeek, Gemini Pro)
    List<String> currentProModels = List<String>.from(ConfigService().openRouterProModels);
    if (currentProModels.isEmpty) {
      currentProModels = [
        'anthropic/claude-3.5-sonnet',
        'openai/gpt-4o',
        'openai/gpt-4o-mini',
        'anthropic/claude-3.5-haiku',
        'deepseek/deepseek-chat',
      ];
    }
    String? workingProModel;
    final List<String> invalidProModels = [];

    if (openRouterApiKey.isNotEmpty) {
      for (int i = 0; i < currentProModels.length; i++) {
        final m = currentProModels[i];
        final bool isPrimary = (i == 0);
        final Stopwatch sw = Stopwatch()..start();
        try {
          final response = await dio.post(
            'https://openrouter.ai/api/v1/chat/completions',
            options: Options(
              headers: {
                'Authorization': 'Bearer $openRouterApiKey',
                'Content-Type': 'application/json',
                'HTTP-Referer': 'https://mindpilot-131f1.web.app/',
                'X-Title': 'MindPilot Health Check',
              },
              validateStatus: (s) => s != null && s < 600,
              receiveTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 15),
            ),
            data: {
              'model': m,
              'messages': [
                {'role': 'user', 'content': 'Ping'}
              ],
              'max_tokens': 5,
            },
          ).timeout(const Duration(seconds: 15));
          sw.stop();

          if (response.statusCode == 200 &&
              response.data != null &&
              response.data['choices'] != null &&
              (response.data['choices'] as List).isNotEmpty) {
            if (workingProModel == null) {
              workingProModel = m;
            }
            _healthCheckResults.add(
              ModelHealthCheckResult(
                modelId: m,
                category: 'OpenRouter Pro',
                isOk: true,
                statusText: 'Operational — ${sw.elapsedMilliseconds}ms',
                latencyMs: sw.elapsedMilliseconds,
                isActive: isPrimary,
              ),
            );
          } else {
            if (response.statusCode == 400 || response.statusCode == 404 || response.statusCode == 402) {
              invalidProModels.add(m);
            }
            _healthCheckResults.add(
              ModelHealthCheckResult(
                modelId: m,
                category: 'OpenRouter Pro',
                isOk: false,
                statusText: _formatOpenRouterStatusError(response.statusCode ?? 500, response.data),
                latencyMs: sw.elapsedMilliseconds,
                isActive: isPrimary,
              ),
            );
          }
        } catch (e) {
          sw.stop();
          _healthCheckResults.add(
            ModelHealthCheckResult(
              modelId: m,
              category: 'OpenRouter Pro',
              isOk: false,
              statusText: _formatHealthError(e),
              latencyMs: sw.elapsedMilliseconds,
              isActive: isPrimary,
            ),
          );
        }
      }

      // Strip out invalid/non-free models
      if (invalidProModels.isNotEmpty) {
        currentProModels.removeWhere((m) => invalidProModels.contains(m));
        needsFirestoreUpdate = true;
      }

      if (workingProModel != null && currentProModels.isNotEmpty && workingProModel != currentProModels.first) {
        currentProModels.remove(workingProModel);
        currentProModels.insert(0, workingProModel);
        autoSwitchEvents.add('Promoted operational Pro model: "$workingProModel" to primary.');
        needsFirestoreUpdate = true;
      }
    }

    // 4. AUTO-SWITCH AND ENABLE FOR ALL USERS VIA FIRESTORE
    if (needsFirestoreUpdate) {
      try {
        final Map<String, dynamic> updateData = {
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (workingGeminiModel != null) {
          updateData['direct_gemini_model'] = workingGeminiModel;
        }
        if (currentFreeModels.isNotEmpty) {
          updateData['openrouter_free_models'] = currentFreeModels;
        }
        if (currentProModels.isNotEmpty) {
          updateData['openrouter_pro_models'] = currentProModels;
        }

        await FirebaseFirestore.instance
            .collection('app_config')
            .doc('settings')
            .set(updateData, SetOptions(merge: true));

        await ConfigService().fetchRemoteConfig();
        _autoSwitchLog = autoSwitchEvents.join('\n');
      } catch (err) {
        safePrint("Auto-switch deployment error: $err");
      }
    }

    if (mounted) {
      setState(() {
        _isCheckingHealth = false;
      });

      if (autoSwitchEvents.isNotEmpty) {
        context.showInAppNotification(
          'Downtime detected! Automatically switched and enabled operational model(s) for all users.',
          type: InAppNotificationType.success,
        );
      }
    }
  }

  Widget _configItem(String label, String value) {
    AppTheme theme = context.watch<AppTheme>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: SecondaryText(text: label, color: theme.accentTxt.withOpacity(0.6)),
          ),
          8.horizontalSpace,
          Flexible(
            child: PrimaryText(
              text: value,
              color: theme.accentTxt,
              fontWeight: FontWeight.bold,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _addAdminRow(BuildContext context) {
    AppTheme theme = context.watch<AppTheme>();
    return Row(
      children: [
        Expanded(
          child: CustomTextField(
            textController: _emailController,
            hintText: 'New Admin Email',
            textInputType: TextInputType.emailAddress,
            autoFocus: false,
            textInputAction: TextInputAction.done,
          ),
        ),

        16.horizontalSpace,
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.primaryBase,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.add, color: Colors.white),
        ).rippleClick(_addAdmin),
      ],
    );
  }

  Future<void> _addAdmin() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('admins').doc(email).set({
        'email': email,
        'addedAt': FieldValue.serverTimestamp(),
      });
      _emailController.clear();
      if (mounted) {
        context.showInAppNotification(
          'Admin Added Successfully!',
          type: InAppNotificationType.success,
        );
      }
    } catch (e) {
      if (mounted) context.showInAppNotification('Error: $e');
    }
    setState(() => _isLoading = false);
  }

  Widget _adminList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('admins').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final admins = snapshot.data!.docs
            .map((doc) => doc['email'] as String)
            .toList();
        final allAdmins = {..._superAdmins, ...admins}.toList();

        return Column(
          children: allAdmins
              .map(
                (email) => _adminTile(
                  context,
                  email,
                  isSuper: _superAdmins.contains(email),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _adminTile(
    BuildContext context,
    String email, {
    bool isSuper = false,
  }) {
    AppTheme theme = context.watch<AppTheme>();
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      gradient: theme.glassGradient,
      child: Row(
        children: [
          Icon(
            isSuper ? Icons.verified_user : Icons.person_outline,
            color: isSuper ? const Color(0xFFF59E0B) : theme.accentTxt,
            size: 20,
          ),
          16.horizontalSpace,
          Expanded(
            child: PrimaryText(
              text: email,
              color: theme.accentTxt,
              fontSize: 14,
            ),
          ),
          if (!isSuper)
            Icon(
              Icons.delete_outline,
              color: theme.errorPrimary,
              size: 20,
            ).rippleClick(() => _removeAdmin(email)),
          if (isSuper)
            SecondaryText(
              text: 'SUPER',
              color: const Color(0xFFF59E0B),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
        ],
      ),
    );
  }

  Widget _templateChip(String label, String message, {bool isInsight = false}) {
    AppTheme theme = context.watch<AppTheme>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isInsight
            ? theme.primaryBase.withOpacity(0.2)
            : theme.accentTxt.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isInsight
              ? theme.primaryBase.withOpacity(0.3)
              : theme.accentTxt.withOpacity(0.1),
        ),
      ),
      child: SecondaryText(
        text: label,
        color: isInsight ? theme.primaryBase : theme.accentTxt.withOpacity(0.8),
        fontSize: 11,
      ),
    ).rippleClick(() {
      _broadcastTitleController.text = label;
      _broadcastBodyController.text = message;
      if (isInsight) _selectedBroadcastType = 'insight';
      setState(() {});
    });
  }

  Widget _typeOption(String label, String value) {
    AppTheme theme = context.watch<AppTheme>();
    bool isSelected = _selectedBroadcastType == value;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedBroadcastType = value);
        if (value == 'insight') {
          _broadcastTitleController.text = 'Daily Reflection';
          _broadcastBodyController.text =
              'Growth begins where your comfort zone ends. Push yourself today!';
        } else {
          _broadcastTitleController.text = 'Daily Reflection';
          _broadcastBodyController.text =
              'Take a moment to reflect on your achievements today. You are making great progress!';
        }
      },
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryBase : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? theme.primaryBase
                : theme.accentTxt.withOpacity(0.2),
          ),
        ),
        child: SecondaryText(
          text: label,
          color: isSelected ? Colors.white : theme.accentTxt.withOpacity(0.6),
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _feedbackToggleCard(BuildContext context) {
    AppTheme theme = context.watch<AppTheme>();
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      gradient: theme.glassGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SecondaryText(
            text:
                'Instantly trigger a feedback card for all active users. Toggle ON to show the feedback prompt app-wide.',
            color: theme.accentTxt.withOpacity(0.7),
            fontSize: 13,
          ),
          20.verticalSpace,
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('app_config')
                .doc('settings')
                .snapshots(),
            builder: (context, snapshot) {
              bool isEnabled = false;
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                isEnabled = data?['showFeedbackCard'] ?? false;
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isEnabled ? Icons.feedback : Icons.feedback_outlined,
                        color: isEnabled
                            ? theme.successPrimary
                            : theme.accentTxt.withOpacity(0.5),
                        size: 22,
                      ),
                      12.horizontalSpace,
                      PrimaryText(
                        text: isEnabled
                            ? 'Feedback Card Active'
                            : 'Feedback Card Off',
                        color: isEnabled
                            ? theme.successPrimary
                            : theme.accentTxt.withOpacity(0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ],
                  ),
                  Switch(
                    value: isEnabled,
                    activeColor: theme.successPrimary,
                    onChanged: (val) async {
                      try {
                        await FirebaseFirestore.instance
                            .collection('app_config')
                            .doc('settings')
                            .set({
                              'showFeedbackCard': val,
                            }, SetOptions(merge: true));
                        if (mounted) {
                          context.showInAppNotification(
                            val
                                ? '✅ Feedback card activated for all users!'
                                : '⛔ Feedback card deactivated.',
                            type: val
                                ? InAppNotificationType.success
                                : InAppNotificationType.error,
                          );
                        }
                      } catch (e) {
                        if (mounted) context.showInAppNotification('Error: $e');
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _removeAdmin(String email) async {
    try {
      await FirebaseFirestore.instance.collection('admins').doc(email).delete();
      if (mounted) context.showInAppNotification('Admin Removed');
    } catch (e) {
      if (mounted) context.showInAppNotification('Error: $e');
    }
  }

  Future<void> _clearAllUsageLogs() async {
    if (_isPurgingLogs) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = context.read<AppTheme>();
        return AlertDialog(
          backgroundColor: theme.brandDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: PrimaryText(
            text: 'Clear All API Logs?',
            color: theme.accentTxt,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          content: SecondaryText(
            text: 'This will instantly delete all usage logs from Firestore and reset your daily quota progress back to 0. This action cannot be undone.',
            color: theme.accentTxt.withOpacity(0.8),
            fontSize: 13,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: SecondaryText(
                text: 'Cancel',
                color: theme.accentTxt.withOpacity(0.6),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const PrimaryText(
                text: 'Delete All',
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isPurgingLogs = true);
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('api_usage')
          .get();

      if (querySnapshot.docs.isEmpty) {
        if (mounted) {
          context.showInAppNotification(
            'No API logs found to clear.',
            type: InAppNotificationType.success,
          );
        }
        setState(() => _isPurgingLogs = false);
        return;
      }

      final docs = querySnapshot.docs;
      await Future.wait(docs.map((doc) => doc.reference.delete()));

      if (mounted) {
        context.showInAppNotification(
          'Successfully cleared all API usage logs!',
          type: InAppNotificationType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        context.showInAppNotification('Error purging logs: $e', type: InAppNotificationType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isPurgingLogs = false);
      }
    }
  }

  Widget _quotaTrackerCard(BuildContext context) {
    AppTheme theme = context.watch<AppTheme>();
    final todayStart = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('api_usage')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return GlassContainer(
            padding: const EdgeInsets.all(20),
            gradient: theme.glassGradient,
            child: Center(
              child: SecondaryText(
                text: 'Error loading API usage: ${snapshot.error}',
                color: theme.errorPrimary,
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return GlassContainer(
            padding: const EdgeInsets.all(20),
            gradient: theme.glassGradient,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final docs = snapshot.data!.docs;
        int directRequests = 0;
        int directTokens = 0;
        int openRouterRequests = 0;
        int openRouterTokens = 0;

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final source = data['source'] as String? ?? 'direct';
          final tokens = data['totalTokens'] as int? ?? 0;

          if (source == 'direct') {
            directRequests++;
            directTokens += tokens;
          } else {
            openRouterRequests++;
            openRouterTokens += tokens;
          }
        }

        final totalRequests = directRequests + openRouterRequests;
        final totalTokens = directTokens + openRouterTokens;

        // Free tier daily limit for Gemini 2.5 Flash is 1500 requests
        const dailyRequestLimit = 1500;
        final dailyRequestPercentage = (totalRequests / dailyRequestLimit).clamp(0.0, 1.0);

        return GlassContainer(
          padding: const EdgeInsets.all(20),
          gradient: theme.glassGradient,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SecondaryText(
                    text: 'Daily Request Limit Proximity',
                    color: theme.accentTxt.withOpacity(0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  PrimaryText(
                    text: '${(dailyRequestPercentage * 100).toStringAsFixed(1)}%',
                    color: dailyRequestPercentage > 0.8
                        ? theme.errorPrimary
                        : (dailyRequestPercentage > 0.5
                            ? const Color(0xFFF59E0B)
                            : theme.successPrimary),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ],
              ),
              8.verticalSpace,
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: dailyRequestPercentage,
                  backgroundColor: theme.accentTxt.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    dailyRequestPercentage > 0.8
                        ? theme.errorPrimary
                        : (dailyRequestPercentage > 0.5
                            ? const Color(0xFFF59E0B)
                            : theme.successPrimary),
                  ),
                  minHeight: 8,
                ),
              ),
              12.verticalSpace,
              SecondaryText(
                text: '$totalRequests / $dailyRequestLimit free requests used today',
                color: theme.accentTxt.withOpacity(0.6),
                fontSize: 12,
              ),
              16.verticalSpace,
              const Divider(color: Colors.white24),
              16.verticalSpace,
              _metricRow(context, 'Total Tokens Consumed', totalTokens.toString()),
              _metricRow(context, 'Direct Gemini (2.5 Flash)', '$directRequests reqs ($directTokens tokens)'),
              _metricRow(context, 'OpenRouter Fallbacks', '$openRouterRequests reqs ($openRouterTokens tokens)'),
              16.verticalSpace,
              const Divider(color: Colors.white24),
              16.verticalSpace,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SecondaryText(
                    text: 'Recent API Requests',
                    color: theme.primaryBase,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.primaryBase,
                    size: 20,
                  ),
                ],
              ).rippleClick(() {
                context.push(const RecentApiRequestsScreen());
              }),
              16.verticalSpace,
              const Divider(color: Colors.white24),
              16.verticalSpace,
              Center(
                child: _isPurgingLogs
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.delete_sweep_outlined,
                            color: theme.errorPrimary.withOpacity(0.8),
                            size: 16,
                          ),
                          8.horizontalSpace,
                          SecondaryText(
                            text: 'Clear All API Logs Instantly',
                            color: theme.errorPrimary.withOpacity(0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ],
                      ).rippleClick(_clearAllUsageLogs),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _metricRow(BuildContext context, String label, String value) {
    AppTheme theme = context.watch<AppTheme>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SecondaryText(
            text: label,
            color: theme.accentTxt.withOpacity(0.6),
            fontSize: 12,
          ),
          PrimaryText(
            text: value,
            color: theme.accentTxt,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ],
      ),
    );
  }
}
