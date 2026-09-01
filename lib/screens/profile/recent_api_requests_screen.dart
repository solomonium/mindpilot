import 'package:mindpilot/export.dart';

class RecentApiRequestsScreen extends StatefulWidget {
  const RecentApiRequestsScreen({super.key});

  @override
  State<RecentApiRequestsScreen> createState() => _RecentApiRequestsScreenState();
}

class _RecentApiRequestsScreenState extends State<RecentApiRequestsScreen> {
  String _sortBy = 'time'; // 'time', 'highest_tokens', 'lowest_tokens'
  bool _isSelectionMode = false;
  final Set<String> _selectedDocIds = {};
  List<String> _currentDocIds = [];

  void _toggleSelectAll() {
    setState(() {
      if (_selectedDocIds.length == _currentDocIds.length) {
        _selectedDocIds.clear();
      } else {
        _selectedDocIds.clear();
        _selectedDocIds.addAll(_currentDocIds);
      }
    });
  }

  void _confirmDeleteSelected() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = context.read<AppTheme>();
        return AlertDialog(
          backgroundColor: theme.brandDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: PrimaryText(
            text: 'Delete API Logs',
            color: theme.accentTxt,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          content: SecondaryText(
            text: 'Are you sure you want to delete the ${_selectedDocIds.length} selected API request logs? This action cannot be undone.',
            color: theme.accentTxt.withOpacity(0.8),
            fontSize: 13,
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
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                _deleteSelected();
              },
              child: const PrimaryText(
                text: 'Delete',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteSelected() async {
    final idsToDelete = _selectedDocIds.toList();
    setState(() {
      _isSelectionMode = false;
      _selectedDocIds.clear();
    });

    context.showInAppNotification('Deleting ${idsToDelete.length} requests...', type: InAppNotificationType.success);

    try {
      final firestore = FirebaseFirestore.instance;
      for (var i = 0; i < idsToDelete.length; i += 500) {
        final chunk = idsToDelete.sublist(
          i,
          i + 500 > idsToDelete.length ? idsToDelete.length : i + 500,
        );
        final batch = firestore.batch();
        for (final id in chunk) {
          batch.delete(firestore.collection('api_usage').doc(id));
        }
        await batch.commit();
      }
      if (mounted) {
        context.showInAppNotification('Successfully deleted requests.', type: InAppNotificationType.success);
      }
    } catch (e) {
      if (mounted) {
        context.showInAppNotification('Error deleting requests: $e', type: InAppNotificationType.error);
      }
    }
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
          text: _isSelectionMode
              ? '${_selectedDocIds.length} Selected'
              : 'Recent API Requests',
          color: theme.accentTxt,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
        leading: Icon(
          _isSelectionMode ? Icons.close : Icons.chevron_left,
          color: theme.accentTxt,
        ).rippleClick(() {
          if (_isSelectionMode) {
            setState(() {
              _isSelectionMode = false;
              _selectedDocIds.clear();
            });
          } else {
            context.pop();
          }
        }),
        actions: isSuperAdmin
            ? [
                if (!_isSelectionMode) ...[
                  IconButton(
                    icon: Icon(Icons.check_box_outlined, color: theme.accentTxt),
                    onPressed: () {
                      setState(() {
                        _isSelectionMode = true;
                      });
                    },
                  ),
                ] else ...[
                  IconButton(
                    icon: Icon(
                      _selectedDocIds.length == _currentDocIds.length
                          ? Icons.deselect
                          : Icons.select_all,
                      color: theme.accentTxt,
                    ),
                    onPressed: _toggleSelectAll,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: _selectedDocIds.isEmpty ? null : _confirmDeleteSelected,
                  ),
                ]
              ]
            : null,
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
                        _statusDashboard(theme),
                        _filterSelector(theme),
                        Expanded(child: _requestsList(theme)),
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

  Widget _filterSelector(AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        gradient: theme.glassGradient,
        child: Row(
          children: [
            SecondaryText(
              text: 'Sort by:',
              color: theme.accentTxt.withOpacity(0.7),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            16.horizontalSpace,
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('Newest', 'time', theme),
                    8.horizontalSpace,
                    _filterChip('Highest Tokens', 'highest_tokens', theme),
                    8.horizontalSpace,
                    _filterChip('Lowest Tokens', 'lowest_tokens', theme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value, AppTheme theme) {
    bool isSelected = _sortBy == value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? theme.primaryBase : theme.accentTxt.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? theme.primaryBase : theme.accentTxt.withOpacity(0.1),
        ),
      ),
      child: SecondaryText(
        text: label,
        color: isSelected ? Colors.white : theme.accentTxt.withOpacity(0.8),
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    ).rippleClick(() {
      setState(() {
        _sortBy = value;
      });
    });
  }

  Widget _requestsList(AppTheme theme) {
    Query query = FirebaseFirestore.instance.collection('api_usage');

    if (_sortBy == 'time') {
      query = query.orderBy('timestamp', descending: true);
    } else if (_sortBy == 'highest_tokens') {
      query = query.orderBy('totalTokens', descending: true);
    } else if (_sortBy == 'lowest_tokens') {
      query = query.orderBy('totalTokens', descending: false);
    }

    query = query.limit(500);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: SecondaryText(
              text: 'Error: ${snapshot.error}',
              color: theme.errorPrimary,
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        _currentDocIds = docs.map((d) => d.id).toList();

        if (docs.isEmpty) {
          return Center(
            child: SecondaryText(
              text: 'No API requests found.',
              color: theme.accentTxt.withOpacity(0.6),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final docId = doc.id;
            return _ApiRequestItem(
              docId: docId,
              data: data,
              theme: theme,
              isSelectionMode: _isSelectionMode,
              isSelected: _selectedDocIds.contains(docId),
              onToggleSelection: () {
                setState(() {
                  if (_selectedDocIds.contains(docId)) {
                    _selectedDocIds.remove(docId);
                  } else {
                    _selectedDocIds.add(docId);
                  }
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _statusDashboard(AppTheme theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('api_usage')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final docs = snapshot.data!.docs;
        
        bool directOk = true;
        String? directError;
        bool openRouterOk = true;
        String? openRouterError;

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final source = data['source'] as String? ?? 'direct';
          final status = data['status'] as String? ?? 'success';
          final error = data['errorMessage'] as String?;

          if (source == 'direct' && directError == null && status != 'success') {
            directOk = false;
            directError = error ?? 'Unknown error';
          }
          if (source == 'openrouter' && openRouterError == null && status != 'success') {
            openRouterOk = false;
            openRouterError = error ?? 'Unknown error';
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            gradient: theme.glassGradient,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SecondaryText(
                  text: 'Service Status Monitor',
                  color: theme.accentTxt,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                12.verticalSpace,
                Row(
                  children: [
                    Expanded(
                      child: _statusIndicator(
                        'Gemini Direct API',
                        directOk,
                        directError,
                        theme,
                      ),
                    ),
                    12.horizontalSpace,
                    Expanded(
                      child: _statusIndicator(
                        'OpenRouter Gateway',
                        openRouterOk,
                        openRouterError,
                        theme,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusIndicator(String title, bool isOperational, String? error, AppTheme theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOperational ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOperational ? Colors.greenAccent.withOpacity(0.3) : Colors.redAccent.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SecondaryText(
            text: title,
            color: theme.accentTxt.withOpacity(0.8),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
          6.verticalSpace,
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isOperational ? Colors.greenAccent : Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              ),
              8.horizontalSpace,
              Expanded(
                child: PrimaryText(
                  text: isOperational ? 'Operational' : 'Downtime Detected',
                  color: isOperational ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApiRequestItem extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final AppTheme theme;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onToggleSelection;

  const _ApiRequestItem({
    required this.docId,
    required this.data,
    required this.theme,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onToggleSelection,
  });

  @override
  State<_ApiRequestItem> createState() => _ApiRequestItemState();
}

class _ApiRequestItemState extends State<_ApiRequestItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final data = widget.data;

    final email = data['userEmail'] as String? ?? 'Unknown User';
    final model = data['model'] as String? ?? 'unknown';
    final source = data['source'] as String? ?? 'direct';
    final promptTokens = data['promptTokens'] as int? ?? 0;
    final responseTokens = data['responseTokens'] as int? ?? 0;
    final tokens = data['totalTokens'] as int? ?? 0;
    final status = data['status'] as String? ?? 'success';
    final errorMessage = data['errorMessage'] as String?;
    final isFailed = status == 'failed';
    final timeStamp = data['timestamp'] as Timestamp?;
    final timeStr = timeStamp != null
        ? DateFormat('yyyy-MM-dd HH:mm:ss').format(timeStamp.toDate())
        : 'Unknown Time';

    Widget itemContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PrimaryText(
                    text: email,
                    color: theme.accentTxt,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  4.verticalSpace,
                  SecondaryText(
                    text: timeStr,
                    color: theme.accentTxt.withOpacity(0.4),
                    fontSize: 11,
                  ),
                ],
              ),
            ),
            Row(
              children: [
                if (isFailed) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                    ),
                    child: const SecondaryText(
                      text: 'FAILED',
                      color: Colors.redAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  8.horizontalSpace,
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: source == 'direct'
                        ? theme.primaryBase.withOpacity(0.2)
                        : Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: source == 'direct'
                          ? theme.primaryBase.withOpacity(0.3)
                          : Colors.amber.withOpacity(0.3),
                    ),
                  ),
                  child: SecondaryText(
                    text: source == 'direct' ? 'Direct SDK' : 'OpenRouter',
                    color: source == 'direct' ? theme.primaryBase : Colors.amber,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!widget.isSelectionMode) ...[
                  8.horizontalSpace,
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.accentTxt.withOpacity(0.6),
                    size: 20,
                  ),
                ],
              ],
            ),
          ],
        ),
        if (_isExpanded && !widget.isSelectionMode) ...[
          12.verticalSpace,
          const Divider(color: Colors.white12),
          12.verticalSpace,
          SecondaryText(
            text: 'Model: $model',
            color: theme.accentTxt.withOpacity(0.7),
            fontSize: 12,
          ),
          8.verticalSpace,
          const SecondaryText(
            text: 'Prompt / Query:',
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: Colors.white70,
          ),
          4.verticalSpace,
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 120),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: SingleChildScrollView(
              child: SecondaryText(
                text: data['prompt'] as String? ?? 'No prompt recorded for this log',
                color: theme.accentTxt.withOpacity(0.8),
                fontSize: 11,
              ),
            ),
          ),
          if (isFailed && errorMessage != null) ...[
            8.verticalSpace,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.redAccent.withOpacity(0.15)),
              ),
              child: SecondaryText(
                text: errorMessage,
                color: Colors.redAccent.withOpacity(0.9),
                fontSize: 11,
              ),
            ),
          ],
          12.verticalSpace,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SecondaryText(
                text: isFailed
                    ? 'Error occurred'
                    : 'Prompt: $promptTokens  •  Response: $responseTokens',
                color: theme.accentTxt.withOpacity(0.6),
                fontSize: 11,
              ),
              PrimaryText(
                text: isFailed ? '0 Tokens' : '$tokens Tokens',
                color: theme.accentTxt,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ],
          ),
        ],
      ],
    );

    if (widget.isSelectionMode) {
      itemContent = Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Icon(
              widget.isSelected ? Icons.check_box : Icons.check_box_outline_blank,
              color: widget.isSelected ? theme.primaryBase : theme.accentTxt.withOpacity(0.6),
              size: 24,
            ),
          ),
          Expanded(child: itemContent),
        ],
      );
    }

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      gradient: isFailed
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.red.withOpacity(0.15),
                Colors.red.withOpacity(0.05),
              ],
            )
          : theme.glassGradient,
      child: itemContent,
    ).rippleClick(() {
      if (widget.isSelectionMode) {
        widget.onToggleSelection();
      } else {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      }
    });
  }
}

