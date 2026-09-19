import 'package:mindpilot/export.dart';

/// Animated, collapsible UI widget displaying the agent's internal reasoning and tool deliberation trace.
class AgentReasoningTrace extends StatefulWidget {
  final List<String> thoughts;
  final bool initiallyExpanded;

  const AgentReasoningTrace({
    super.key,
    required this.thoughts,
    this.initiallyExpanded = false,
  });

  @override
  State<AgentReasoningTrace> createState() => _AgentReasoningTraceState();
}

class _AgentReasoningTraceState extends State<AgentReasoningTrace>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  IconData _getIconForThought(String thought) {
    final lower = thought.toLowerCase();
    if (lower.contains('context') || lower.contains('streak') || lower.contains('user')) {
      return Icons.psychology_outlined;
    } else if (lower.contains('wisdom') || lower.contains('scripture') || lower.contains('proverb')) {
      return Icons.lightbulb_outline;
    } else if (lower.contains('plan') || lower.contains('action_plan') || lower.contains('task')) {
      return Icons.checklist_rtl_outlined;
    } else if (lower.contains('focus') || lower.contains('timer') || lower.contains('session')) {
      return Icons.timer_outlined;
    } else if (lower.contains('journal') || lower.contains('record') || lower.contains('reflection')) {
      return Icons.auto_stories_outlined;
    }
    return Icons.auto_awesome;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.thoughts.isEmpty) return const SizedBox.shrink();

    final theme = context.watch<AppTheme>();
    final count = widget.thoughts.length;

    return Container(
      margin: EdgeInsets.only(bottom: 6.h),
      decoration: BoxDecoration(
        color: theme.primaryBase.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.primaryBase.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Chip
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.primaryBase.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      size: 12,
                      color: theme.primaryBase,
                    ),
                  ),
                  6.horizontalSpace,
                  Text(
                    'Agent Deliberation ($count ${count == 1 ? 'step' : 'steps'})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.primaryBase,
                      letterSpacing: 0.2,
                    ),
                  ),
                  4.horizontalSpace,
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 16,
                    color: theme.primaryBase,
                  ),
                ],
              ),
            ),
          ),

          // Expanded Details
          if (_isExpanded)
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 8.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(
                    height: 10,
                    thickness: 0.6,
                    color: theme.primaryBase.withValues(alpha: 0.15),
                  ),
                  ...widget.thoughts.asMap().entries.map((entry) {
                    final index = entry.key;
                    final thought = entry.value;
                    final icon = _getIconForThought(thought);

                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 3.h),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: EdgeInsets.only(top: 2.h),
                            child: Icon(
                              icon,
                              size: 13,
                              color: theme.accentTxt.withValues(alpha: 0.7),
                            ),
                          ),
                          6.horizontalSpace,
                          Expanded(
                            child: Text(
                              thought,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.3,
                                color: theme.accentTxt.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
