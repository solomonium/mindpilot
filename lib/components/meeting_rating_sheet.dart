import 'package:mindpilot/export.dart';
import 'package:mindpilot/models/calendar_event.dart';

/// A glass-morphism bottom sheet that lets the user rate how productive a
/// meeting was, with an optional notes field.
class MeetingRatingSheet extends StatefulWidget {
  final CalendarEvent event;
  final VoidCallback? onRated;

  const MeetingRatingSheet({
    super.key,
    required this.event,
    this.onRated,
  });

  static Future<void> show(
    BuildContext context, {
    required CalendarEvent event,
    VoidCallback? onRated,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MeetingRatingSheet(event: event, onRated: onRated),
    );
  }

  @override
  State<MeetingRatingSheet> createState() => _MeetingRatingSheetState();
}

class _MeetingRatingSheetState extends State<MeetingRatingSheet> {
  int _selectedRating = 0;
  final _notesController = TextEditingController();
  bool _isSaving = false;

  static const List<({String emoji, String label})> _ratings = [
    (emoji: '😩', label: 'Wasted'),
    (emoji: '😐', label: 'Okay'),
    (emoji: '🙂', label: 'Good'),
    (emoji: '😊', label: 'Great'),
    (emoji: '🚀', label: 'Excellent'),
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedRating == 0) return;
    setState(() => _isSaving = true);

    try {
      await DatabaseHelper().insertMeetingRating({
        'event_id': widget.event.id,
        'title': widget.event.title,
        'scheduled_at': widget.event.startTime.toIso8601String(),
        'rating': _selectedRating,
        'notes': _notesController.text.trim(),
        'rated_at': DateTime.now().toIso8601String(),
      });

      await EngagementService().recordAction(EngagementAction.meetingRated);

      if (mounted) {
        Navigator.pop(context);
        widget.onRated?.call();
      }
    } catch (e) {
      safePrint('MeetingRatingSheet: save error $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppTheme>();
    final mediaQuery = MediaQuery.of(context);
    final start = DateFormat('h:mm a').format(widget.event.startTime);
    final end = DateFormat('h:mm a').format(widget.event.endTime);

    return Container(
      decoration: BoxDecoration(
        color: theme.brandDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: theme.primaryBase.withOpacity(0.2)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: mediaQuery.viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: theme.accentTxt.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: theme.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.videocam, color: Colors.white, size: 20),
              ),
              12.horizontalSpace,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PrimaryText(
                      text: 'Meeting Productivity',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.accentTxt,
                    ),
                    4.verticalSpace,
                    SecondaryText(
                      text: '$start – $end',
                      fontSize: 12,
                      color: theme.accentTxt.withOpacity(0.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          16.verticalSpace,

          GlassContainer(
            padding: const EdgeInsets.all(14),
            gradient: theme.glassGradient,
            child: PrimaryText(
              text: widget.event.title,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.accentTxt,
              textOverflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          20.verticalSpace,

          PrimaryText(
            text: 'How productive was this meeting?',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.accentTxt.withOpacity(0.8),
          ),
          16.verticalSpace,

          // Emoji rating row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_ratings.length, (i) {
              final rating = i + 1;
              final isSelected = _selectedRating == rating;
              return GestureDetector(
                onTap: () => setState(() => _selectedRating = rating),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.primaryBase.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? theme.primaryBase
                          : theme.accentTxt.withOpacity(0.12),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _ratings[i].emoji,
                        style: TextStyle(
                            fontSize: isSelected ? 28 : 22),
                      ),
                      4.verticalSpace,
                      SecondaryText(
                        text: _ratings[i].label,
                        fontSize: 9,
                        color: isSelected
                            ? theme.primaryBase
                            : theme.accentTxt.withOpacity(0.5),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          20.verticalSpace,

          // Notes field
          TextField(
            controller: _notesController,
            maxLines: 3,
            style: TextStyle(color: theme.accentTxt, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Any notes or takeaways? (optional)',
              hintStyle: TextStyle(
                  color: theme.accentTxt.withOpacity(0.35), fontSize: 13),
              filled: true,
              fillColor: theme.accentTxt.withOpacity(0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: theme.accentTxt.withOpacity(0.12)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: theme.accentTxt.withOpacity(0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: theme.primaryBase, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          20.verticalSpace,

          CustomButton(
            label: _isSaving ? 'Saving…' : 'Save Rating',
            onPressed: _selectedRating == 0 || _isSaving ? null : _submit,
          ),
        ],
      ),
    );
  }
}
