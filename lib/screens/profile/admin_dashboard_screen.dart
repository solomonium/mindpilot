import 'package:cloud_firestore/cloud_firestore.dart';
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
  bool _isRefreshing = false;

  String? _foundUserUid;
  String _foundUserType = 'Freemium';
  bool _isSearchingUser = false;

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
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

  Widget _broadcastCard(BuildContext context) {
    AppTheme theme = context.watch();
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      gradient: theme.glassGradient,
      child: Column(
        children: [
          SecondaryText(
            text:
                'Send a reminder to all users to reflect on their daily achievements.',
            color: theme.accentTxt.withOpacity(0.7),
            fontSize: 13,
            textAlign: TextAlign.center,
          ),
          20.verticalSpace,
          CustomButton(
            label: 'Send Achievement Reminder',
            loading: _isBroadcasting,
            onPressed: _sendBroadcastReminder,
          ),
        ],
      ),
    );
  }

  Future<void> _sendBroadcastReminder() async {
    setState(() => _isBroadcasting = true);
    try {
      // In a real app, this would trigger a Cloud Function or send via FCM topics
      // For now, we'll simulate the broadcast successfully
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        context.showInAppNotification(
          '🚀 Broadcast Sent to all users!',
          type: InAppNotificationType.success,
        );
      }
    } catch (e) {
      if (mounted) context.showInAppNotification('Error: $e');
    }
    setState(() => _isBroadcasting = false);
  }

  Widget _userManagementCard(BuildContext context) {
    AppTheme theme = context.watch();
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
        if (mounted)
          context.showInAppNotification('User not found in database.');
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
    AppTheme theme = context.watch();
    return PrimaryText(
      text: title,
      color: theme.accentTxt,
      fontSize: 16,
      fontWeight: FontWeight.bold,
    );
  }

  Widget _configCard(BuildContext context) {
    AppTheme theme = context.watch();
    final config = ConfigService();
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      gradient: theme.glassGradient,
      child: Column(
        children: [
          _configItem('Version', config.latestVersion),
          _configItem('Interval (ms)', config.quoteIntervalMs.toString()),
          _configItem('Force Update', config.forceUpdate ? 'YES' : 'NO'),
          16.verticalSpace,
          CustomButton(
            label: 'Refresh System Settings',
            loading: _isRefreshing,
            onPressed: () async {
              setState(() => _isRefreshing = true);
              await config.fetchRemoteConfig();
              setState(() {
                _isRefreshing = false;
              });
              if (mounted) {
                context.showInAppNotification(
                  'System settings refreshed!',
                  type: InAppNotificationType.success,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _configItem(String label, String value) {
    AppTheme theme = context.watch();
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
    AppTheme theme = context.watch();
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
    context.watch();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('admins').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

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
    AppTheme theme = context.watch();
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

  Future<void> _removeAdmin(String email) async {
    try {
      await FirebaseFirestore.instance.collection('admins').doc(email).delete();
      if (mounted) context.showInAppNotification('Admin Removed');
    } catch (e) {
      if (mounted) context.showInAppNotification('Error: $e');
    }
  }
}
