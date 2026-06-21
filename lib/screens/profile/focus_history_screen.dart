import 'package:mindpilot/export.dart';

class FocusHistoryScreen extends StatefulWidget {
  const FocusHistoryScreen({super.key});

  @override
  State<FocusHistoryScreen> createState() => _FocusHistoryScreenState();
}

class _FocusHistoryScreenState extends State<FocusHistoryScreen> {
  List<Map<String, dynamic>> _sessions = [];
  int _weeklyTotal = 0;
  int _todayTotal = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final db = DatabaseHelper();
    final sessions = await db.getRecentFocusSessions(limit: 30);
    final weekStart = DateTime.now().subtract(const Duration(days: 7));
    final weekly = await db.getFocusMinutesSince(weekStart.toIso8601String());
    final todayStart = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final today = await db.getFocusMinutesSince(todayStart.toIso8601String());

    if (mounted) {
      setState(() {
        _sessions = sessions;
        _weeklyTotal = weekly;
        _todayTotal = today;
        _loading = false;
      });
    }
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
          text: 'Focus History',
          color: theme.accentTxt,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Icon(Icons.arrow_back_ios, color: theme.accentTxt, size: 20)
              .rippleClick(() => context.pop()),
        ),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: theme.primaryBase),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          theme,
                          'Today',
                          '$_todayTotal min',
                          Icons.today_outlined,
                          theme.successPrimary,
                        ),
                      ),
                      12.horizontalSpace,
                      Expanded(
                        child: _statCard(
                          theme,
                          'This Week',
                          '$_weeklyTotal min',
                          Icons.calendar_view_week,
                          theme.primaryBase,
                        ),
                      ),
                    ],
                  ),
                  24.verticalSpace,
                  PrimaryText(
                    text: 'Recent Sessions',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.accentTxt,
                  ),
                  12.verticalSpace,
                  if (_sessions.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.accentTxt.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: SecondaryText(
                          text: 'No focus sessions yet. Start one to build your history!',
                          color: theme.accentTxt.withOpacity(0.5),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ..._sessions.map((s) => _sessionTile(theme, s)),
                ],
              ),
            ),
    );
  }

  Widget _statCard(
    AppTheme theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          8.verticalSpace,
          PrimaryText(
            text: value,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.accentTxt,
          ),
          SecondaryText(
            text: label,
            fontSize: 11,
            color: theme.accentTxt.withOpacity(0.6),
          ),
        ],
      ),
    );
  }

  Widget _sessionTile(AppTheme theme, Map<String, dynamic> session) {
    final dateStr = session['date'] as String? ?? '';
    final minutes = session['duration_minutes'] as int? ?? 0;
    DateTime? parsed;
    try {
      parsed = DateTime.parse(dateStr);
    } catch (_) {}

    final displayDate = parsed != null
        ? DateFormat('MMM dd, yyyy • hh:mm a').format(parsed)
        : dateStr;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.accentTxt.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.accentTxt.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.primaryBase.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.timer, color: theme.primaryBase, size: 20),
          ),
          12.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PrimaryText(
                  text: '$minutes min session',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.accentTxt,
                ),
                4.verticalSpace,
                SecondaryText(
                  text: displayDate,
                  fontSize: 11,
                  color: theme.accentTxt.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
