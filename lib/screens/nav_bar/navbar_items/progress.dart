import 'package:mindpilot/export.dart';
import 'package:share_plus/share_plus.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: PrimaryText(
          text: 'My Journal',
          color: theme.accentTxt,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
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
          Consumer<JournalProvider>(
            builder: (context, journal, _) {
              if (journal.entries.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      200.verticalSpace,
                      Icon(Icons.book_outlined, color: theme.accentTxt.withOpacity(0.3), size: 60),
                      16.verticalSpace,
                      SecondaryText(text: 'No journal entries yet.', color: theme.accentTxt.withOpacity(0.5)),
                    ],
                  ),
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: theme.primaryBase.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.primaryBase.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb_outline, color: theme.primaryBase, size: 20),
                          12.horizontalSpace,
                          Expanded(
                            child: SecondaryText(
                              text: 'Tip: Swipe left on any entry to delete it from your journal.',
                              color: theme.accentTxt.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...journal.entries.map((entry) {
                      return Dismissible(
                        key: Key(entry.id.toString()),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (direction) async {
                          return await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: theme.brandDark,
                              title: PrimaryText(text: 'Delete Entry?', color: theme.accentTxt, fontSize: 18),
                              content: SecondaryText(
                                text: 'Are you sure you want to delete this journal entry? This action cannot be undone.',
                                color: theme.accentTxt.withOpacity(0.7),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: SecondaryText(text: 'Cancel', color: theme.accentTxt.withOpacity(0.5)),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: PrimaryText(text: 'Delete', color: theme.errorPrimary, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) {
                          if (entry.id != null) {
                            journal.deleteJournalEntry(entry.id!);
                            context.showInAppNotification(
                              'Entry deleted successfully',
                              type: InAppNotificationType.success,
                            );
                          }
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: theme.errorPrimary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.delete_outline, color: theme.errorPrimary),
                        ),
                        child: _entryCard(context, entry.date, entry.text, entry.mood, entry.time, entry.title),
                      );
                    }).toList(),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _entryCard(BuildContext context, String date, String text, String mood, String time, String? title) {
    AppTheme theme = context.watch();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: theme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: theme.primaryBase.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: theme.accentTxt,
          collapsedIconColor: theme.accentTxt.withOpacity(0.5),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SecondaryText(text: date, fontSize: 12, color: theme.accentTxt.withOpacity(0.6)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: theme.accentTxt.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: SecondaryText(text: mood, fontSize: 10, color: theme.accentTxt.withOpacity(0.8)),
              ),
            ],
          ),
          trailing: Icon(Icons.share, color: theme.accentTxt.withOpacity(0.5), size: 20).rippleClick(() {
            final isPro = context.read<AuthProvider>().isPro;
            if (!isPro) {
              AppHelper.showPaywall(context, feature: 'Sharing Journal Entries');
              return;
            }
            final shareText = """
🧠 MindPilot Journal: ${title ?? 'Reflections'}
Date: $date

${text.replaceAll('**', '').replaceAll('*', '')}

---
Generated by MindPilot - Think clearly. Live intentionally.
Download MindPilot now for your own AI clarity!
""";
            Share.share(shareText);
          }),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: PrimaryText(
              text: title ?? (text.length > 50 ? "${text.substring(0, 50)}..." : text),
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: theme.accentTxt,
              maxLines: 1,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SelectionArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(color: Colors.white24),
                    8.verticalSpace,
                    if (title != null) ...[
                      PrimaryText(text: title, fontSize: 16, fontWeight: FontWeight.bold, color: theme.accentTxt),
                      12.verticalSpace,
                    ],
                    MarkdownBody(
                      data: text,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(color: theme.accentTxt, fontSize: 14, height: 1.5),
                        strong: TextStyle(color: theme.accentTxt, fontWeight: FontWeight.bold),
                        h1: TextStyle(color: theme.accentTxt, fontSize: 18, fontWeight: FontWeight.bold),
                        h2: TextStyle(color: theme.accentTxt, fontSize: 16, fontWeight: FontWeight.bold),
                        h3: TextStyle(color: theme.accentTxt, fontSize: 14, fontWeight: FontWeight.bold),
                        listBullet: TextStyle(color: theme.accentTxt),
                      ),
                    ),
                    12.verticalSpace,
                    Align(
                      alignment: Alignment.bottomRight,
                      child: SecondaryText(text: "Time: $time", fontSize: 10, color: theme.accentTxt.withOpacity(0.5)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
