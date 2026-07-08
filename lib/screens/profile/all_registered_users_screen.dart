import 'package:flutter/services.dart';
import 'package:mindpilot/export.dart';

class AllRegisteredUsersScreen extends StatefulWidget {
  const AllRegisteredUsersScreen({super.key});

  @override
  State<AllRegisteredUsersScreen> createState() => _AllRegisteredUsersScreenState();
}

class _AllRegisteredUsersScreenState extends State<AllRegisteredUsersScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
  }

  void _showStatusChangeDialog(String userId, String name, String currentStatus, AppTheme theme) {
    String selectedStatus = currentStatus;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: theme.brandDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: PrimaryText(
                text: 'Manage Status',
                color: theme.accentTxt,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SecondaryText(
                    text: 'Update membership tier for $name:',
                    color: theme.accentTxt.withOpacity(0.8),
                    fontSize: 13,
                  ),
                  16.verticalSpace,
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: theme.accentTxt.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.accentTxt.withOpacity(0.1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedStatus,
                        dropdownColor: theme.brandDark,
                        isExpanded: true,
                        icon: Icon(Icons.arrow_drop_down, color: theme.accentTxt),
                        items: ['Freemium', 'Pro Member'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: PrimaryText(
                              text: value,
                              fontSize: 14,
                              color: theme.accentTxt,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedStatus = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: SecondaryText(
                    text: 'Cancel',
                    color: theme.accentTxt.withOpacity(0.6),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryBase,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    try {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .update({'heardFrom': FieldValue.serverTimestamp() == null ? null : null}..remove('heardFrom')..['userType'] = selectedStatus);
                      
                      // Wait, standard update syntax is cleaner:
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .update({'userType': selectedStatus});

                      if (context.mounted) {
                        context.showInAppNotification(
                          'Membership updated successfully!',
                          type: InAppNotificationType.success,
                        );
                        Navigator.pop(dialogContext);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        context.showInAppNotification(
                          'Failed to update status: $e',
                          type: InAppNotificationType.error,
                        );
                      }
                    }
                  },
                  child: const PrimaryText(
                    text: 'Save Changes',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch<AppTheme>();
    final currentUserEmail = FirebaseAuth.instance.currentUser?.email;
    final isSuperAdmin = currentUserEmail == 'laleyesolomon2@gmail.com';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: PrimaryText(
          text: 'Registered Users',
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
          Positioned.fill(
            child: !isSuperAdmin
                ? _accessDeniedView(theme)
                : SafeArea(
                    child: Column(
                      children: [
                        _searchAndHeader(theme),
                        Expanded(child: _usersList(theme)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _accessDeniedView(AppTheme theme) {
    return Center(
      child: GlassContainer(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        gradient: theme.glassGradient,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: Colors.redAccent, size: 48),
            16.verticalSpace,
            PrimaryText(
              text: 'Access Denied',
              color: theme.accentTxt,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            8.verticalSpace,
            SecondaryText(
              text: 'Only the super administrator has access to this data.',
              color: theme.accentTxt.withOpacity(0.7),
              textAlign: TextAlign.center,
              fontSize: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchAndHeader(AppTheme theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        final totalCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SecondaryText(
                    text: 'Database Overview',
                    color: theme.accentTxt.withOpacity(0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.primaryBase.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.primaryBase.withOpacity(0.3)),
                    ),
                    child: PrimaryText(
                      text: '$totalCount Users Total',
                      color: theme.primaryBase,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              12.verticalSpace,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: theme.accentTxt.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.accentTxt.withOpacity(0.1)),
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: theme.accentTxt, fontSize: 14),
                  decoration: InputDecoration(
                    icon: Icon(
                      Icons.search,
                      color: theme.accentTxt.withOpacity(0.54),
                      size: 18,
                    ),
                    border: InputBorder.none,
                    hintText: 'Search by name or email...',
                    hintStyle: TextStyle(
                      color: theme.accentTxt.withOpacity(0.3),
                      fontSize: 14,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? Icon(
                            Icons.clear,
                            color: theme.accentTxt.withOpacity(0.5),
                            size: 16,
                          ).rippleClick(() => _searchController.clear())
                        : null,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _usersList(AppTheme theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SecondaryText(
                text: 'Error loading users: ${snapshot.error}',
                color: theme.errorPrimary,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: SecondaryText(
              text: 'No registered users found.',
              color: theme.accentTxt.withOpacity(0.5),
            ),
          );
        }

        // Apply Client-side Filtering based on search query
        final searchQuery = _searchController.text.trim().toLowerCase();
        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] as String? ?? data['displayName'] as String? ?? '').toLowerCase();
          final email = (data['email'] as String? ?? '').toLowerCase();
          return name.contains(searchQuery) || email.contains(searchQuery);
        }).toList();

        // Sort alphabetically by name (A-Z) ascending
        filteredDocs.sort((a, b) {
          final nameA = ((a.data() as Map<String, dynamic>)['name'] as String? ?? (a.data() as Map<String, dynamic>)['displayName'] as String? ?? '').toLowerCase();
          final nameB = ((b.data() as Map<String, dynamic>)['name'] as String? ?? (b.data() as Map<String, dynamic>)['displayName'] as String? ?? '').toLowerCase();
          return nameA.compareTo(nameB);
        });

        if (filteredDocs.isEmpty) {
          return Center(
            child: SecondaryText(
              text: 'No users match your search.',
              color: theme.accentTxt.withOpacity(0.5),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 24.0, top: 4.0),
          child: GlassContainer(
            padding: const EdgeInsets.symmetric(vertical: 8),
            gradient: theme.glassGradient,
            child: ListView.separated(
              itemCount: filteredDocs.length,
              separatorBuilder: (context, index) => Divider(
                color: Colors.white.withOpacity(0.08),
                height: 1,
              ),
              itemBuilder: (context, index) {
                final doc = filteredDocs[index];
                final data = doc.data() as Map<String, dynamic>;
                final name = data['name'] as String? ?? data['displayName'] as String? ?? 'No Name';
                final email = data['email'] as String? ?? 'No Email';
                final heardFrom = data['heardFrom'] as String? ?? 'Unknown';
                final userType = data['userType'] as String? ?? 'Freemium';
                final isPro = userType == 'Pro Member';

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Row(
                    children: [
                      Expanded(
                        child: PrimaryText(
                          text: name,
                          color: theme.accentTxt,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPro ? theme.primaryBase.withOpacity(0.2) : Colors.white10,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isPro ? theme.primaryBase.withOpacity(0.3) : Colors.white.withOpacity(0.05),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SecondaryText(
                              text: userType,
                              color: isPro ? theme.primaryBase : theme.accentTxt.withOpacity(0.5),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            4.horizontalSpace,
                            Icon(
                              Icons.edit,
                              size: 10,
                              color: isPro ? theme.primaryBase : theme.accentTxt.withOpacity(0.4),
                            ),
                          ],
                        ),
                      ).rippleClick(() {
                        _showStatusChangeDialog(doc.id, name, userType, theme);
                      }),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      4.verticalSpace,
                      Row(
                        children: [
                          Expanded(
                            child: SecondaryText(
                              text: email,
                              color: theme.accentTxt.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                          Icon(
                            Icons.copy_rounded,
                            size: 12,
                            color: theme.accentTxt.withOpacity(0.4),
                          ),
                        ],
                      ).rippleClick(() async {
                        await Clipboard.setData(ClipboardData(text: email));
                        if (context.mounted) {
                          context.showInAppNotification(
                            'Email copied to clipboard!',
                            type: InAppNotificationType.success,
                          );
                        }
                      }),
                      8.verticalSpace,
                      Row(
                        children: [
                          Icon(
                            Icons.campaign_outlined,
                            size: 14,
                            color: theme.primaryBase.withOpacity(0.7),
                          ),
                          4.horizontalSpace,
                          Expanded(
                            child: SecondaryText(
                              text: 'Joined via: $heardFrom',
                              color: theme.accentTxt.withOpacity(0.4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
