import 'dart:io';

import 'package:mindpilot/export.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class JournalEntriesScreen extends StatefulWidget {
  const JournalEntriesScreen({super.key});

  @override
  State<JournalEntriesScreen> createState() => _JournalEntriesScreenState();
}

class _JournalEntriesScreenState extends State<JournalEntriesScreen> {
  @override
  void initState() {
    super.initState();
    AppHelper.setScreenshotProtection(true);
  }

  @override
  void dispose() {
    // AppHelper.setScreenshotProtection(false);
    super.dispose();
  }

  Color? _selectedTextColor;

  Widget _colorPickerItem(
    BuildContext context,
    Color color, {
    bool isReset = false,
  }) {
    AppTheme theme = context.watch();
    final isPro = context.read<AppAuthProvider>().isPro;
    return GestureDetector(
      onTap: () {
        if (!isPro) {
          AppHelper.showPaywall(context, feature: 'Journal Customization');
          return;
        }
        setState(() {
          _selectedTextColor = isReset ? null : color;
        });
      },
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color:
                _selectedTextColor == color ||
                    (isReset && _selectedTextColor == null)
                ? Colors.white
                : Colors.white24,
            width: 2,
          ),
          boxShadow: [
            if (_selectedTextColor == color ||
                (isReset && _selectedTextColor == null))
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 1,
              ),
          ],
        ),
        child: isReset
            ? Icon(Icons.refresh, size: 14, color: theme.brandDark)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: PrimaryText(
          text: R.S.myJournal,
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
          SafeArea(
            child: Consumer<JournalProvider>(
              builder: (context, journal, _) {
                final entries = journal.entries;

                if (entries.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.book_outlined,
                          color: theme.accentTxt.withOpacity(0.3),
                          size: 60,
                        ),
                        16.verticalSpace,
                        SecondaryText(
                          text: R.S.noEntries,
                          color: theme.accentTxt.withOpacity(0.5),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          SecondaryText(
                            text: R.S.textColor,
                            color: theme.accentTxt.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          16.horizontalSpace,
                          _colorPickerItem(
                            context,
                            const Color(0xFFC0FF00),
                          ), // Lemon Green
                          12.horizontalSpace,
                          _colorPickerItem(
                            context,
                            const Color(0xFFFF914D),
                          ), // Orange
                          12.horizontalSpace,
                          _colorPickerItem(
                            context,
                            theme.accentTxt,
                            isReset: true,
                          ), // Reset
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return Dismissible(
                            key: Key(entry.id.toString()),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: theme.errorPrimary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.delete_outline,
                                color: theme.errorPrimary,
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              return await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: theme.brandDark,
                                  title: PrimaryText(
                                    text: R.S.deleteEntry,
                                    color: theme.accentTxt,
                                  ),
                                  content: SecondaryText(
                                    text: R.S.deleteConfirm,
                                    color: theme.accentTxt.withOpacity(0.7),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: SecondaryText(
                                        text: R.S.cancel,
                                        color: theme.accentTxt.withOpacity(0.5),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: PrimaryText(
                                        text: R.S.delete,
                                        color: theme.errorPrimary,
                                      ),
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
                            child: _entryCard(
                              context,
                              entry.date,
                              entry.text,
                              entry.mood,
                              entry.time,
                              entry.title,
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SecondaryText(
                        text: R.S.journalTip,
                        fontSize: 10,
                        textAlign: TextAlign.center,
                        color: theme.accentTxt.withOpacity(0.4),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _entryCard(
    BuildContext context,
    String date,
    String text,
    String mood,
    String time,
    String? title,
  ) {
    AppTheme theme = context.watch();
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 16),
      gradient: theme.glassGradient,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: theme.accentTxt,
          collapsedIconColor: theme.accentTxt.withOpacity(0.5),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SecondaryText(
                text: date,
                fontSize: 12,
                color: theme.accentTxt.withOpacity(0.6),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.accentTxt.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SecondaryText(
                  text: mood,
                  fontSize: 10,
                  color: theme.accentTxt.withOpacity(0.8),
                ),
              ),
            ],
          ),
          trailing: Icon(
            Icons.share,
            color: theme.accentTxt.withOpacity(0.5),
            size: 20,
          ).rippleClick(() => _showShareOptions(context, date, text, title)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: PrimaryText(
              text:
                  title ??
                  (text.length > 50 ? "${text.substring(0, 50)}..." : text),
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
                      PrimaryText(
                        text: title,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _selectedTextColor ?? theme.accentTxt,
                      ),
                      12.verticalSpace,
                    ],
                    MarkdownBody(
                      data: text,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: _selectedTextColor ?? theme.accentTxt,
                          fontSize: 14,
                          height: 1.5,
                        ),
                        strong: TextStyle(
                          color: _selectedTextColor ?? theme.accentTxt,
                          fontWeight: FontWeight.bold,
                        ),
                        em: TextStyle(
                          color: _selectedTextColor ?? theme.accentTxt,
                          fontStyle: FontStyle.italic,
                        ),
                        h1: TextStyle(
                          color: _selectedTextColor ?? theme.accentTxt,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        h2: TextStyle(
                          color: _selectedTextColor ?? theme.accentTxt,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        h3: TextStyle(
                          color: _selectedTextColor ?? theme.accentTxt,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        listBullet: TextStyle(
                          color: _selectedTextColor ?? theme.accentTxt,
                        ),
                        tableBody: TextStyle(
                          color: _selectedTextColor ?? theme.accentTxt,
                          fontSize: 13,
                        ),
                        tableHead: TextStyle(
                          color: _selectedTextColor ?? theme.accentTxt,
                          fontWeight: FontWeight.bold,
                        ),
                        blockquote: TextStyle(
                          color: _selectedTextColor ?? theme.accentTxt,
                        ),
                        code: TextStyle(
                          color: _selectedTextColor ?? theme.accentTxt,
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    ),
                    12.verticalSpace,
                    Align(
                      alignment: Alignment.bottomRight,
                      child: SecondaryText(
                        text: "Time: $time",
                        fontSize: 10,
                        color: theme.accentTxt.withOpacity(0.5),
                      ),
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

  void _showShareOptions(
    BuildContext context,
    String date,
    String text,
    String? title,
  ) {
    AppTheme theme = context.read<AppTheme>();
    final isPro = context.read<AppAuthProvider>().isPro;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassContainer(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        gradient: theme.glassGradient,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrimaryText(
              text: 'Share Journal Entry',
              color: theme.accentTxt,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            24.verticalSpace,
            _shareOptionTile(
              context,
              'Digital Receipt',
              'Fast & Stylish (Text)',
              Icons.receipt_long,
              () {
                Navigator.pop(context);
                _shareAsReceipt(context, date, text, title);
              },
            ),
            16.verticalSpace,
            _shareOptionTile(
              context,
              'Professional PDF',
              'Complete Document (Premium)',
              Icons.picture_as_pdf,
              () {
                Navigator.pop(context);
                if (!isPro) {
                  AppHelper.showPaywall(context, feature: 'PDF Sharing');
                } else {
                  _shareAsPDF(context, date, text, title);
                }
              },
            ),
            24.verticalSpace,
          ],
        ),
      ),
    );
  }

  Widget _shareOptionTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    AppTheme theme = context.watch<AppTheme>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.accentTxt.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.accentTxt.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.primaryBase.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.primaryBase, size: 24),
          ),
          16.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PrimaryText(
                  text: title,
                  color: theme.accentTxt,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                SecondaryText(
                  text: subtitle,
                  color: theme.accentTxt.withOpacity(0.6),
                  fontSize: 12,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: theme.accentTxt.withOpacity(0.3)),
        ],
      ),
    ).rippleClick(onTap);
  }

  void _shareAsReceipt(
    BuildContext context,
    String date,
    String text,
    String? title,
  ) {
    final isPro = context.read<AppAuthProvider>().isPro;
    final cleanText = text.replaceAll('**', '').replaceAll('*', '').trim();

    String shareContent;
    if (isPro) {
      shareContent = cleanText;
    } else {
      // 50% visibility for non-pro
      final length = cleanText.length;
      final visibleLength = (length * 0.5).toInt();
      shareContent =
          "${cleanText.substring(0, visibleLength)}...\n\n[PRO CONTENT HIDDEN]\nUpgrade to Yearly Premium to unlock full history and sharing!";
    }

    final downloadUrl = ConfigService().updateUrl;
    final receipt =
        """
----------------------------
      MIND PILOT JOURNAL
----------------------------
DATE: $date
TITLE: ${title?.toUpperCase() ?? 'REFLECTIONS'}
----------------------------
$shareContent
----------------------------
Generated by MindPilot
Think clearly. Live intentionally.
----------------------------
""";

    Share.share(
      "$receipt\n\nDownload MindPilot: $downloadUrl",
      subject: 'MindPilot Reflection',
    );
  }

  Future<void> _shareAsPDF(
    BuildContext context,
    String date,
    String text,
    String? title,
  ) async {
    final pdf = pw.Document();
    final cleanText = text.replaceAll('**', '').replaceAll('*', '').trim();
    final downloadUrl = ConfigService().updateUrl;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Text(
                'MIND PILOT',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'Daily Reflection Journal',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Divider(),
            pw.SizedBox(height: 16),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Date: $date', style: pw.TextStyle(fontSize: 12)),
                pw.Text('Mood: Recorded', style: pw.TextStyle(fontSize: 12)),
              ],
            ),
            pw.SizedBox(height: 24),
            if (title != null) ...[
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 16),
            ],
            ...cleanText
                .split('\n')
                .map(
                  (line) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Text(
                      line,
                      style: pw.TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ),
                ),
            pw.SizedBox(height: 32),
            pw.Divider(),
            pw.SizedBox(height: 16),
            pw.Center(
              child: pw.Text(
                'Think clearly. Live intentionally.',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'Downloaded via MindPilot App',
                style: pw.TextStyle(fontSize: 10),
              ),
            ),
          ];
        },
      ),
    );

    try {
      final output = await getTemporaryDirectory();
      final file = File(
        "${output.path}/mindpilot_journal_${DateTime.now().millisecondsSinceEpoch}.pdf",
      );
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            "Sharing my journal entry from MindPilot. Download the app here: $downloadUrl",
      );
    } catch (e) {
      if (context.mounted) {
        context.showInAppNotification(
          'Error generating PDF: $e',
          type: InAppNotificationType.error,
        );
      }
    }
  }
}
