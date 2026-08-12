import 'package:flutter/services.dart';
import 'package:mindpilot/export.dart';

class AllRegisteredUsersScreen extends StatefulWidget {
  const AllRegisteredUsersScreen({super.key});

  @override
  State<AllRegisteredUsersScreen> createState() =>
      _AllRegisteredUsersScreenState();
}

enum UserSortOption { lastActive, registrationDate, nameAsc }

class _AllRegisteredUsersScreenState extends State<AllRegisteredUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  UserSortOption _selectedSortOption = UserSortOption.lastActive;
  String? _expandedUserId;

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

  DateTime _extractTimestamp(dynamic raw) {
    if (raw == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatRegistrationDate(dynamic raw) {
    final dt = _extractTimestamp(raw);
    if (dt.millisecondsSinceEpoch == 0) return 'Date unknown';
    return DateFormat('MMM d, yyyy • h:mm a').format(dt);
  }

  String _formatTimeSpent(dynamic raw) {
    if (raw == null) return '0 seconds';
    int seconds = 0;
    if (raw is int) {
      seconds = raw;
    } else if (raw is double) {
      seconds = raw.toInt();
    } else if (raw is String) {
      seconds = int.tryParse(raw) ?? 0;
    }
    if (seconds <= 0) return '0 seconds';

    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final remainingSeconds = duration.inSeconds.remainder(60);

    final parts = <String>[];
    if (hours > 0) {
      parts.add('${hours}h');
    }
    if (minutes > 0) {
      parts.add('${minutes}m');
    }
    if (remainingSeconds > 0 || parts.isEmpty) {
      parts.add('${remainingSeconds}s');
    }
    return parts.join(' ');
  }

  void _showStatusChangeDialog(
    String userId,
    String name,
    String currentStatus,
    AppTheme theme,
  ) {
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
                    color: theme.accentTxt.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                  16.verticalSpace,
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: theme.accentTxt.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.accentTxt.withValues(alpha: 0.1),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedStatus,
                        dropdownColor: theme.brandDark,
                        isExpanded: true,
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: theme.accentTxt,
                        ),
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
                  PrimaryText(
                    text: 'Registered Users',
                    color: theme.accentTxt,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.primaryBase.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.primaryBase.withOpacity(0.3),
                      ),
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
              12.verticalSpace,
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildSortChip(
                      theme,
                      label: 'Last Active',
                      isSelected:
                          _selectedSortOption == UserSortOption.lastActive,
                      onTap: () {
                        setState(() {
                          _selectedSortOption = UserSortOption.lastActive;
                        });
                      },
                    ),
                    8.horizontalSpace,
                    _buildSortChip(
                      theme,
                      label: 'Registration Date',
                      isSelected:
                          _selectedSortOption ==
                          UserSortOption.registrationDate,
                      onTap: () {
                        setState(() {
                          _selectedSortOption = UserSortOption.registrationDate;
                        });
                      },
                    ),
                    8.horizontalSpace,
                    _buildSortChip(
                      theme,
                      label: 'Name (A-Z)',
                      isSelected: _selectedSortOption == UserSortOption.nameAsc,
                      onTap: () {
                        setState(() {
                          _selectedSortOption = UserSortOption.nameAsc;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortChip(
    AppTheme theme, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.primaryBase.withOpacity(0.2)
            : theme.accentTxt.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? theme.primaryBase.withOpacity(0.5)
              : theme.accentTxt.withOpacity(0.12),
        ),
      ),
      child: SecondaryText(
        text: label,
        color: isSelected
            ? theme.primaryBase
            : theme.accentTxt.withOpacity(0.8),
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
      ),
    ).rippleClick(onTap);
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
          return const Center(child: CircularProgressIndicator());
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
          final name =
              (data['name'] as String? ?? data['displayName'] as String? ?? '')
                  .toLowerCase();
          final email = (data['email'] as String? ?? '').toLowerCase();
          return name.contains(searchQuery) || email.contains(searchQuery);
        }).toList();

        if (_selectedSortOption == UserSortOption.lastActive) {
          // Sort by last active / engagement timestamp descending (Newest first)
          filteredDocs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;

            final timeA = _extractTimestamp(
              dataA['lastActive'] ??
                  dataA['lastAppOpen'] ??
                  dataA['lastEngagementDate'] ??
                  dataA['lastVisited'] ??
                  dataA['updatedAt'] ??
                  dataA['createdAt'],
            );
            final timeB = _extractTimestamp(
              dataB['lastActive'] ??
                  dataB['lastAppOpen'] ??
                  dataB['lastEngagementDate'] ??
                  dataB['lastVisited'] ??
                  dataB['updatedAt'] ??
                  dataB['createdAt'],
            );

            return timeB.compareTo(timeA);
          });
        } else if (_selectedSortOption == UserSortOption.registrationDate) {
          // Sort by registration timestamp descending (Newest / Recent first)
          filteredDocs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;

            final timeA = _extractTimestamp(dataA['createdAt']);
            final timeB = _extractTimestamp(dataB['createdAt']);

            return timeB.compareTo(timeA);
          });
        } else {
          // Sort alphabetically by name (A-Z) ascending
          filteredDocs.sort((a, b) {
            final nameA =
                ((a.data() as Map<String, dynamic>)['name'] as String? ??
                        (a.data() as Map<String, dynamic>)['displayName']
                            as String? ??
                        '')
                    .toLowerCase();
            final nameB =
                ((b.data() as Map<String, dynamic>)['name'] as String? ??
                        (b.data() as Map<String, dynamic>)['displayName']
                            as String? ??
                        '')
                    .toLowerCase();
            return nameA.compareTo(nameB);
          });
        }

        if (filteredDocs.isEmpty) {
          return Center(
            child: SecondaryText(
              text: 'No users match your search.',
              color: theme.accentTxt.withOpacity(0.5),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            bottom: 24.0,
            top: 4.0,
          ),
          child: GlassContainer(
            padding: const EdgeInsets.symmetric(vertical: 8),
            gradient: theme.glassGradient,
            child: ListView.separated(
              itemCount: filteredDocs.length,
              separatorBuilder: (context, index) =>
                  Divider(color: Colors.white.withOpacity(0.08), height: 1),
              itemBuilder: (context, index) {
                return _buildUserTile(context, filteredDocs[index], theme);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserTile(
    BuildContext context,
    DocumentSnapshot doc,
    AppTheme theme,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final name =
        data['name'] as String? ?? data['displayName'] as String? ?? 'No Name';
    final email = data['email'] as String? ?? 'No Email';
    final heardFrom = data['heardFrom'] as String? ?? 'Unknown';
    final userType = data['userType'] as String? ?? 'Freemium';
    final isPro = userType == 'Pro Member';
    final streak = data['streak'] as int? ?? data['dailyStreak'] as int? ?? 0;
    final points = data['totalPoints'] as int? ?? data['points'] as int? ?? 0;
    final fcmToken = data['fcmToken'] as String?;
    final createdAtRaw = data['createdAt'];
    final lastActiveRaw = data['lastActive'] ?? data['lastAppOpen'] ?? data['lastEngagementDate'] ?? data['createdAt'];
    final lastVisitedScreen = data['lastVisitedScreen'] as String?;
    final lastVisitedScreenAtRaw = data['lastVisitedScreenAt'];

    final isExpanded = _expandedUserId == doc.id;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: isExpanded
            ? theme.accentTxt.withOpacity(0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded
              ? theme.primaryBase.withOpacity(0.3)
              : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          // User Card Header Row (Tap to expand/collapse one at a time)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                _expandedUserId = isExpanded ? null : doc.id;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: isPro
                            ? theme.primaryBase.withOpacity(0.2)
                            : theme.accentTxt.withOpacity(0.1),
                        child: PrimaryText(
                          text: name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          color: isPro ? theme.primaryBase : theme.accentTxt,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      10.horizontalSpace,
                      Expanded(
                        child: PrimaryText(
                          text: name,
                          color: theme.accentTxt,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isPro
                              ? theme.primaryBase.withOpacity(0.2)
                              : Colors.white10,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isPro
                                ? theme.primaryBase.withOpacity(0.3)
                                : Colors.white.withOpacity(0.05),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SecondaryText(
                              text: userType,
                              color: isPro
                                  ? theme.primaryBase
                                  : theme.accentTxt.withOpacity(0.5),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            4.horizontalSpace,
                            Icon(
                              Icons.edit,
                              size: 10,
                              color: isPro
                                  ? theme.primaryBase
                                  : theme.accentTxt.withOpacity(0.4),
                            ),
                          ],
                        ),
                      ).rippleClick(() {
                        _showStatusChangeDialog(doc.id, name, userType, theme);
                      }),
                      8.horizontalSpace,
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: isExpanded
                            ? theme.primaryBase
                            : theme.accentTxt.withOpacity(0.5),
                        size: 22,
                      ),
                    ],
                  ),
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
                        _selectedSortOption == UserSortOption.lastActive
                            ? Icons.access_time_rounded
                            : Icons.schedule_outlined,
                        size: 12,
                        color: theme.primaryBase.withOpacity(0.7),
                      ),
                      4.horizontalSpace,
                      SecondaryText(
                        text: _selectedSortOption == UserSortOption.lastActive
                            ? (lastActiveRaw != null
                                  ? 'Active: ${_formatRegistrationDate(lastActiveRaw)}'
                                  : 'Joined: ${_formatRegistrationDate(createdAtRaw)}')
                            : 'Joined: ${_formatRegistrationDate(createdAtRaw)}',
                        color: theme.accentTxt.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded Details Section
          if (isExpanded) ...[
            Divider(color: Colors.white.withOpacity(0.08), height: 1),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.brandDark.withOpacity(0.4),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PrimaryText(
                    text: 'Account & Membership Details',
                    color: theme.primaryBase,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  10.verticalSpace,
                  _detailRow(
                    theme,
                    Icons.fingerprint,
                    'User ID',
                    doc.id,
                    canCopy: true,
                  ),
                  8.verticalSpace,
                  _detailRow(
                    theme,
                    Icons.email_outlined,
                    'Email Address',
                    email,
                    canCopy: true,
                  ),
                  8.verticalSpace,
                  _detailRow(
                    theme,
                    Icons.verified_user_outlined,
                    'Membership Tier',
                    userType,
                  ),
                  8.verticalSpace,
                  _detailRow(
                    theme,
                    Icons.calendar_today_outlined,
                    'Registration Date',
                    _formatRegistrationDate(createdAtRaw),
                  ),
                  if (lastActiveRaw != null) ...[
                    8.verticalSpace,
                    _detailRow(
                      theme,
                      Icons.access_time_rounded,
                      'Last Activity',
                      _formatRegistrationDate(lastActiveRaw),
                    ),
                  ],
                  8.verticalSpace,
                  _detailRow(
                    theme,
                    Icons.timer_outlined,
                    'Time Spent on App',
                    _formatTimeSpent(data['totalTimeSpent']),
                  ),
                  if (lastVisitedScreen != null) ...[
                    8.verticalSpace,
                    _detailRow(
                      theme,
                      Icons.phone_android_rounded,
                      'Last Screen',
                      lastVisitedScreenAtRaw != null
                          ? '$lastVisitedScreen · ${_formatRegistrationDate(lastVisitedScreenAtRaw)}'
                          : lastVisitedScreen,
                    ),
                  ],
                  8.verticalSpace,
                  _detailRow(
                    theme,
                    Icons.campaign_outlined,
                    'Acquisition Source',
                    'Joined via $heardFrom',
                  ),
                  8.verticalSpace,
                  _detailRow(
                    theme,
                    Icons.local_fire_department_outlined,
                    'Engagement Streak',
                    '$streak Days Active',
                  ),
                  8.verticalSpace,
                  _detailRow(
                    theme,
                    Icons.stars_outlined,
                    'Total XP Points',
                    '$points Points',
                  ),
                  8.verticalSpace,
                  _detailRow(
                    theme,
                    Icons.notifications_active_outlined,
                    'Push Device Token',
                    fcmToken != null && fcmToken.isNotEmpty
                        ? 'Configured (${fcmToken.substring(0, fcmToken.length > 12 ? 12 : fcmToken.length)}...)'
                        : 'Not Configured',
                  ),
                  if (fcmToken == null || fcmToken.isEmpty) ...[
                    8.verticalSpace,
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryBase.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.primaryBase.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_active,
                            size: 14,
                            color: theme.primaryBase,
                          ),
                          6.horizontalSpace,
                          SecondaryText(
                            text: 'Trigger Notification Setup Prompt',
                            color: theme.primaryBase,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ],
                      ),
                    ).rippleClick(() async {
                      try {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(doc.id)
                            .update({'promptPushNotification': true});
                        if (context.mounted) {
                          context.showInAppNotification(
                            'Notification setup prompt queued for $name!',
                            type: InAppNotificationType.success,
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          context.showInAppNotification(
                            'Failed to queue prompt: $e',
                            type: InAppNotificationType.error,
                          );
                        }
                      }
                    }),
                  ],
                  14.verticalSpace,
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          label: 'Edit Membership Status',
                          onPressed: () => _showStatusChangeDialog(
                            doc.id,
                            name,
                            userType,
                            theme,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(
    AppTheme theme,
    IconData icon,
    String label,
    String value, {
    bool canCopy = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: theme.primaryBase),
        8.horizontalSpace,
        SecondaryText(
          text: '$label:',
          color: theme.accentTxt.withOpacity(0.6),
          fontSize: 11,
        ),
        6.horizontalSpace,
        Expanded(
          child: SecondaryText(
            text: value,
            color: theme.accentTxt,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (canCopy)
          Icon(
            Icons.copy_rounded,
            size: 12,
            color: theme.accentTxt.withOpacity(0.5),
          ).rippleClick(() async {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) {
              context.showInAppNotification(
                '$label copied to clipboard!',
                type: InAppNotificationType.success,
              );
            }
          }),
      ],
    );
  }
}
