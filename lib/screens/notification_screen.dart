import 'package:mindpilot/export.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: PrimaryText(
          text: 'Alerts & Updates',
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
          Consumer<NotificationProvider>(
            builder: (context, notifStore, _) {
              final updates = notifStore.notifications.where((n) => n.type == 'update').toList();
              
              if (updates.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_outlined, color: theme.accentTxt.withOpacity(0.3), size: 60),
                      16.verticalSpace,
                      SecondaryText(text: 'No updates yet.', color: theme.accentTxt.withOpacity(0.5)),
                    ],
                  ),
                );
              }
              
              return ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: updates.length,
                itemBuilder: (context, index) {
                  final notif = updates[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
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
                            PrimaryText(
                              text: notif.title,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.accentTxt,
                            ),
                            SecondaryText(
                              text: DateFormat('MMM dd, hh:mm a').format(DateTime.parse(notif.date)),
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
                        if (!notif.isRead) ...[
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
                  ).rippleClick(() {
                    if (!notif.isRead) notifStore.markAsRead(notif.id!);
                  });
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
