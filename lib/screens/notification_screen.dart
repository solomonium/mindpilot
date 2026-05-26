import 'package:mindpilot/export.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _isMultiSelectMode = false;
  final Set<int> _selectedIds = {};

  void _exitMultiSelect() {
    setState(() {
      _isMultiSelectMode = false;
      _selectedIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    final notifStore = context.watch<NotificationProvider>();
    final updates = notifStore.notifications.where((n) => n.type == 'update').toList();
    final allSelected = updates.isNotEmpty && _selectedIds.length == updates.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: PrimaryText(
          text: _isMultiSelectMode ? '${_selectedIds.length} Selected' : 'Alerts & Updates',
          color: theme.accentTxt,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            icon: Icon(
              _isMultiSelectMode ? Icons.close : Icons.chevron_left,
              color: theme.accentTxt,
            ),
            onPressed: () {
              if (_isMultiSelectMode) {
                _exitMultiSelect();
              } else {
                context.pop();
              }
            },
          ),
        ),
        actions: updates.isEmpty
            ? null
            : [
                if (_isMultiSelectMode) ...[
                  IconButton(
                    icon: Icon(
                      allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                      color: theme.accentTxt,
                    ),
                    onPressed: () {
                      setState(() {
                        if (allSelected) {
                          _selectedIds.clear();
                        } else {
                          _selectedIds.addAll(updates.map((n) => n.id!));
                        }
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: theme.errorPrimary),
                    onPressed: _selectedIds.isEmpty
                        ? null
                        : () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  backgroundColor: theme.brandDark,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  title: PrimaryText(
                                    text: 'Delete Selected',
                                    color: theme.accentTxt,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  content: SecondaryText(
                                    text: 'Are you sure you want to delete ${_selectedIds.length} notifications?',
                                    color: theme.accentTxt.withOpacity(0.8),
                                  ),
                                  actions: [
                                    TextButton(
                                      child: SecondaryText(
                                          text: 'Cancel', color: theme.accentTxt.withOpacity(0.5)),
                                      onPressed: () => Navigator.of(context).pop(false),
                                    ),
                                    TextButton(
                                      child: PrimaryText(
                                          text: 'Delete', color: theme.errorPrimary, fontWeight: FontWeight.bold),
                                      onPressed: () => Navigator.of(context).pop(true),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirm == true) {
                              final idsToDelete = _selectedIds.toList();
                              await context
                                  .read<NotificationProvider>()
                                  .deleteMultipleNotifications(idsToDelete);
                              _exitMultiSelect();
                              if (mounted) {
                                context.showInAppNotification(
                                  '${idsToDelete.length} notifications deleted',
                                  type: InAppNotificationType.success,
                                );
                              }
                            }
                          },
                  ),
                ] else ...[
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: theme.accentTxt),
                    onPressed: () {
                      setState(() {
                        _isMultiSelectMode = true;
                      });
                    },
                  ),
                ]
              ],
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
          if (updates.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, color: theme.accentTxt.withOpacity(0.3), size: 60),
                  16.verticalSpace,
                  SecondaryText(text: 'No updates yet.', color: theme.accentTxt.withOpacity(0.5)),
                ],
              ),
            )
          else
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.accentTxt.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.accentTxt.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: theme.primaryBase,
                          size: 18,
                        ),
                        12.horizontalSpace,
                        Expanded(
                          child: SecondaryText(
                            text: R.S.notificationTip,
                            fontSize: 12,
                            color: theme.accentTxt.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    itemCount: updates.length,
                    itemBuilder: (context, index) {
                      final notif = updates[index];
                      return Dismissible(
                        key: Key(notif.id.toString()),
                        direction: _isMultiSelectMode ? DismissDirection.none : DismissDirection.endToStart,
                        confirmDismiss: (direction) async {
                          return await showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                backgroundColor: theme.brandDark,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: PrimaryText(
                                    text: 'Delete Notification',
                                    color: theme.accentTxt,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                                content: SecondaryText(
                                    text: 'Are you sure you want to delete this notification?',
                                    color: theme.accentTxt.withOpacity(0.8)),
                                actions: [
                                  TextButton(
                                    child: SecondaryText(
                                        text: 'Cancel', color: theme.accentTxt.withOpacity(0.5)),
                                    onPressed: () => Navigator.of(context).pop(false),
                                  ),
                                  TextButton(
                                    child: PrimaryText(
                                        text: 'Delete', color: theme.errorPrimary, fontWeight: FontWeight.bold),
                                    onPressed: () => Navigator.of(context).pop(true),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        onDismissed: (direction) {
                          notifStore.deleteNotification(notif.id!);
                          context.showInAppNotification('Notification deleted',
                              type: InAppNotificationType.success);
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: theme.errorPrimary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: InkWell(
                            onTap: () {
                              if (_isMultiSelectMode) {
                                setState(() {
                                  if (_selectedIds.contains(notif.id)) {
                                    _selectedIds.remove(notif.id);
                                    if (_selectedIds.isEmpty) {
                                      _isMultiSelectMode = false;
                                    }
                                  } else {
                                    _selectedIds.add(notif.id!);
                                  }
                                });
                              } else {
                                if (!notif.isRead) notifStore.markAsRead(notif.id!);
                              }
                            },
                            onLongPress: () {
                              if (!_isMultiSelectMode) {
                                setState(() {
                                  _isMultiSelectMode = true;
                                  _selectedIds.add(notif.id!);
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Row(
                              children: [
                                if (_isMultiSelectMode) ...[
                                  Icon(
                                    _selectedIds.contains(notif.id)
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked,
                                    color: _selectedIds.contains(notif.id)
                                        ? theme.primaryBase
                                        : theme.accentTxt.withOpacity(0.4),
                                    size: 24,
                                  ),
                                  12.horizontalSpace,
                                ],
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: notif.isRead
                                          ? theme.accentTxt.withOpacity(0.05)
                                          : theme.primaryBase.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: notif.isRead
                                            ? theme.accentTxt.withOpacity(0.1)
                                            : theme.primaryBase.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: PrimaryText(
                                                text: notif.title,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: theme.accentTxt,
                                              ),
                                            ),
                                            12.horizontalSpace,
                                            SecondaryText(
                                              text: DateFormat('MMM dd, hh:mm a')
                                                  .format(DateTime.parse(notif.date)),
                                              fontSize: 10,
                                              color: theme.accentTxt.withOpacity(0.5),
                                            ),
                                          ],
                                        ),
                                        8.verticalSpace,
                                        SecondaryText(
                                          text: notif.body,
                                          fontSize: 14,
                                          color: theme.accentTxt.withOpacity(0.8),
                                        ),
                                        if (!notif.isRead && !_isMultiSelectMode) ...[
                                          12.verticalSpace,
                                          Align(
                                            alignment: Alignment.bottomRight,
                                            child: PrimaryText(
                                              text: 'Mark as read',
                                              fontSize: 12,
                                              color: theme.primaryBase,
                                              fontWeight: FontWeight.bold,
                                            ).rippleClick(() => notifStore.markAsRead(notif.id!)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
