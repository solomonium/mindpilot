import 'package:mindpilot/export.dart';
import '../models/agent_action.dart';
import '../tools/agent_tool_registry.dart';
import 'action_plan_card.dart';

/// Interactive UI Card rendered inside chat messages when the AI Agent invokes a tool.
class AgentActionCard extends StatefulWidget {
  final AgentAction action;
  final VoidCallback? onStatusChanged;

  const AgentActionCard({
    super.key,
    required this.action,
    this.onStatusChanged,
  });

  @override
  State<AgentActionCard> createState() => _AgentActionCardState();
}

class _AgentActionCardState extends State<AgentActionCard> {
  bool _isExecuting = false;

  IconData _getIconForTool(String toolName) {
    switch (toolName) {
      case 'start_focus_session':
        return Icons.timer_outlined;
      case 'create_journal_entry':
        return Icons.auto_stories_outlined;
      case 'get_user_context':
        return Icons.person_search_outlined;
      case 'search_wisdom':
        return Icons.lightbulb_outline;
      default:
        return Icons.auto_awesome_outlined;
    }
  }

  Color _getColorForTool(String toolName, AppTheme theme) {
    switch (toolName) {
      case 'start_focus_session':
        return Colors.orangeAccent;
      case 'create_journal_entry':
        return Colors.tealAccent;
      case 'get_user_context':
        return Colors.lightBlueAccent;
      case 'search_wisdom':
        return Colors.amberAccent;
      default:
        return theme.primaryBase;
    }
  }

  Future<void> _handleActionExecute() async {
    setState(() => _isExecuting = true);
    widget.action.status = ActionStatus.executing;
    widget.onStatusChanged?.call();

    final result = await AgentToolRegistry().dispatch(
      toolName: widget.action.toolName,
      arguments: widget.action.arguments,
      context: context,
    );

    if (mounted) {
      setState(() {
        _isExecuting = false;
        if (result['status'] == 'failed' || result['status'] == 'error') {
          widget.action.status = ActionStatus.failed;
          widget.action.errorMessage = result['error']?.toString();
        } else {
          widget.action.status = ActionStatus.completed;
          widget.action.result = result;
        }
      });
      widget.onStatusChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.action.toolName == 'create_action_plan') {
      return ActionPlanCard(
        action: widget.action,
        onStatusChanged: widget.onStatusChanged,
      );
    }

    final theme = context.watch<AppTheme>();
    final accentColor = _getColorForTool(widget.action.toolName, theme);
    final isCompleted = widget.action.status == ActionStatus.completed;
    final isPending = widget.action.status == ActionStatus.pendingApproval;
    final isFailed = widget.action.status == ActionStatus.failed;

    return Container(
      margin: EdgeInsets.only(top: 8.h, bottom: 4.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIconForTool(widget.action.toolName),
                  size: 16.sp,
                  color: accentColor,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  widget.action.title,
                  style: TextStyle(
                    color: theme.txt,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.sp,
                  ),
                ),
              ),
              if (isCompleted)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 12.sp, color: Colors.greenAccent),
                      SizedBox(width: 3.w),
                      Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (widget.action.description.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(
              widget.action.description,
              style: TextStyle(
                fontSize: 12.sp,
                color: theme.secondaryTxt,
              ),
            ),
          ],
          if (isPending) ...[
            SizedBox(height: 10.h),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _isExecuting ? null : _handleActionExecute,
                icon: _isExecuting
                    ? SizedBox(
                        width: 12.w,
                        height: 12.w,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.play_arrow, size: 14.sp),
                label: Text(
                  widget.action.toolName == 'start_focus_session'
                      ? 'Launch Focus Session'
                      : 'Confirm Action',
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor.withValues(alpha: 0.25),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    side: BorderSide(color: accentColor.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ),
          ],
          if (isFailed) ...[
            SizedBox(height: 6.h),
            Text(
              widget.action.errorMessage ?? 'Execution failed',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 11.sp,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
