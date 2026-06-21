import 'package:mindpilot/export.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _userSearchController = TextEditingController();
  final List<String> _superAdmins = [
    'laleyesolomon2@gmail.com',
    'solteqinnovationsltd@gmail.com',
  ];
  bool _isLoading = false;
  bool _isBroadcasting = false;
  bool _isUpdatingMembership = false;

  String? _foundUserUid;
  String _foundUserType = 'Freemium';
  bool _isSearchingUser = false;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _versionController = TextEditingController();
  final TextEditingController _intervalController = TextEditingController();
  final TextEditingController _updateUrlController = TextEditingController();
  bool _forceUpdateValue = false;
  bool _isEditMode = false;
  bool _isUpdatingConfig = false;

  int _totalUsers = 0;
  bool _isLoadingUsersCount = true;

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
                _userManagementCard(context),
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

  Widget _userManagementCard(BuildContext context) {
    AppTheme theme = context.watch<AppTheme>();
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      gradient: theme.glassGradient,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  textController: _userSearchController,
                  hintText: 'Enter User Email',
                  textInputType: TextInputType.emailAddress,
                  autoFocus: false,
                  textInputAction: TextInputAction.search,
                  onDone: _searchUser,
                ),
              ),
              12.horizontalSpace,
              IconButton(
                icon: _isSearchingUser
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search, color: Colors.white),
                onPressed: _searchUser,
              ),
            ],
          ),
          if (_foundUserUid != null) ...[
            20.verticalSpace,
            const Divider(color: Colors.white24),
            20.verticalSpace,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SecondaryText(
                  text: 'Member Type:',
                  color: theme.accentTxt.withOpacity(0.7),
                ),
                DropdownButton<String>(
                  value: _foundUserType,
                  dropdownColor: theme.brandDark,
                  underline: const SizedBox(),
                  style: GoogleFonts.inter(
                    color: theme.accentTxt,
                    fontWeight: FontWeight.bold,
                  ),
                  items: ['Freemium', 'Pro Member'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _foundUserType = val);
                  },
                ),
              ],
            ),
            20.verticalSpace,
            CustomButton(
              label: 'Update Membership',
              loading: _isUpdatingMembership,
              onPressed: _updateUserType,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _searchUser() async {
    final email = _userSearchController.text.trim().toLowerCase();
    if (email.isEmpty) return;

    setState(() {
      _isSearchingUser = true;
      _foundUserUid = null;
    });

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        setState(() {
          _foundUserUid = doc.id;
          _foundUserType = doc.data()['userType'] ?? 'Freemium';
        });
      } else {
        if (mounted) {
          context.showInAppNotification('User not found in database.');
        }
      }
    } catch (e) {
      if (mounted) context.showInAppNotification('Error: $e');
    }
    setState(() => _isSearchingUser = false);
  }

  Future<void> _updateUserType() async {
    if (_foundUserUid == null) return;
    setState(() => _isUpdatingMembership = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_foundUserUid)
          .update({'userType': _foundUserType});
      if (mounted) {
        context.showInAppNotification(
          'User updated to $_foundUserType',
          type: InAppNotificationType.success,
        );
      }
    } catch (e) {
      if (mounted) context.showInAppNotification('Error: $e');
    } finally {
      setState(() => _isUpdatingMembership = false);
    }
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
          .update({
            'support_phone': phone,
            'latest_version': version,
            'quote_interval_ms': intervalMs,
            'update_url': updateUrl,
            'force_update': _forceUpdateValue,
            'authenticated_users_count':
                _totalUsers, // Maintain/sync the accurate total user count automatically
            'updatedAt': FieldValue.serverTimestamp(),
          });

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

  Widget _configItem(String label, String value) {
    AppTheme theme = context.watch<AppTheme>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SecondaryText(text: label, color: theme.accentTxt.withOpacity(0.6)),
          PrimaryText(
            text: value,
            color: theme.accentTxt,
            fontWeight: FontWeight.bold,
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
}
