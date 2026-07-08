import 'dart:async';
import 'dart:ui';
import 'package:mindpilot/export.dart';

class GroupLobbyScreen extends StatefulWidget {
  final String? groupId;
  const GroupLobbyScreen({super.key, this.groupId});

  @override
  State<GroupLobbyScreen> createState() => _GroupLobbyScreenState();
}

class _GroupLobbyScreenState extends State<GroupLobbyScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _inviteEmailController = TextEditingController();
  final TextEditingController _bibleChapterController = TextEditingController(
    text: 'Romans 8',
  );
  late TextEditingController _questionsPerPlayerController;

  bool _gamePushed = false;
  Timer? _debounceTimer;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<GroupQuizProvider>();
    _questionsPerPlayerController = TextEditingController(
      text: '${provider.questionsPerParticipant}',
    );
    _inviteEmailController.addListener(_onEmailChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final lastRead = await SharedPrefs.getString('LAST_READ_BIBLE_CHAPTER');
      if (lastRead.isNotEmpty) {
        if (mounted) {
          setState(() {
            _bibleChapterController.text = lastRead;
          });
        }
        provider.scopeValue = lastRead;
      } else {
        provider.scopeValue = 'Romans 8';
      }

      if (widget.groupId != null) {
        final allowed = await _checkAdAccess(widget.groupId);
        if (allowed) {
          provider.listenToGroup(widget.groupId!);
        } else {
          if (mounted) {
            context.showInAppNotification(
              "Access to group quiz requires watching an ad.",
            );
            Navigator.pop(context);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _inviteEmailController.removeListener(_onEmailChanged);
    _debounceTimer?.cancel();
    _groupNameController.dispose();
    _inviteEmailController.dispose();
    _bibleChapterController.dispose();
    _questionsPerPlayerController.dispose();
    super.dispose();
  }

  String _getScopeFriendlyName(String scopeType, String scopeValue) {
    switch (scopeType) {
      case 'general':
        return 'General Bible Knowledge';
      case 'chapter':
        return 'Specific Chapter Study${scopeValue.trim().isNotEmpty ? ": ${scopeValue.trim()}" : ""}';
      case 'tech':
        return 'Technology & Coding';
      case 'science':
        return 'Science & Physics';
      case 'english':
        return 'English & Literature';
      case 'economics':
        return 'Economics & Finance';
      case 'mindfulness':
        return 'Personality & Mindfulness';
      case 'custom':
        return 'Custom Topic${scopeValue.trim().isNotEmpty ? ": ${scopeValue.trim()}" : ""}';
      default:
        return 'General Bible Knowledge';
    }
  }

  Future<bool> _checkAdAccess(String? targetGroupId) async {
    final isPro = context.read<AppAuthProvider>().isPro;
    if (isPro) return true;

    final prefs = await SharedPreferences.getInstance();
    int sessionsAccessed =
        prefs.getInt('group_quiz_sessions_accessed_count') ?? 0;

    if (targetGroupId != null) {
      final isAlreadyUnlocked =
          prefs.getBool('group_quiz_unlocked_$targetGroupId') ?? false;
      if (isAlreadyUnlocked) {
        return true;
      }
    }

    if (sessionsAccessed < 3) {
      sessionsAccessed++;
      await prefs.setInt(
        'group_quiz_sessions_accessed_count',
        sessionsAccessed,
      );
      if (targetGroupId != null) {
        await prefs.setBool('group_quiz_unlocked_$targetGroupId', true);
      }
      return true;
    }

    if (!mounted) return false;
    final theme = context.read<AppTheme>();
    final Completer<bool> completer = Completer<bool>();

    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: theme.brandDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.play_circle_fill,
                color: Color(0xFFF59E0B),
                size: 24,
              ),
              8.horizontalSpace,
              const PrimaryText(
                text: 'Unlock Group Quiz 👥',
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ],
          ),
          content: const SecondaryText(
            text:
                'You have used your 3 free group quiz sessions. Watch a short video ad to unlock access to this lobby.',
            color: Colors.white70,
            fontSize: 13,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: SecondaryText(text: 'Cancel', color: Colors.white38),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: PrimaryText(
                text: 'Watch Ad',
                color: theme.primaryBase,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      },
    ).then((watchAdSelected) {
      if (watchAdSelected == true) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (spinnerContext) => Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryBase),
            ),
          ),
        );

        AdService.instance.showRewardedAd(
          onUserEarnedReward: (ad, reward) async {
            if (mounted) {
              Navigator.pop(context);
            }
            if (targetGroupId != null) {
              await prefs.setBool('group_quiz_unlocked_$targetGroupId', true);
            }
            completer.complete(true);
          },
          onAdFailedToShow: () {
            if (mounted) {
              Navigator.pop(context);
              context.showInAppNotification(
                "Ad not ready yet. Please try again in a few seconds.",
                type: InAppNotificationType.error,
              );
            }
            completer.complete(false);
          },
        );
      } else {
        completer.complete(false);
      }
    });

    return completer.future;
  }

  void _onEmailChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    final text = _inviteEmailController.text.trim();
    if (text.isEmpty) {
      context.read<GroupQuizProvider>().clearSuggestions();
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        context.read<GroupQuizProvider>().searchEmails(text);
      }
    });
  }

  void _createGroup() async {
    final name = _groupNameController.text.trim();
    if (name.isEmpty) {
      context.showInAppNotification('Please enter a group name');
      return;
    }

    final provider = context.read<GroupQuizProvider>();
    final allowed = await _checkAdAccess(null);
    if (!allowed) return;

    final groupId = await provider.createGroup(name);
    if (!mounted) return;
    if (groupId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('group_quiz_unlocked_$groupId', true);

      // PREFILL custom topic text with the room name
      _bibleChapterController.text = name;
      provider.scopeValue = name;

      provider.listenToGroup(groupId);
      context.showInAppNotification(
        'Group created successfully!',
        type: InAppNotificationType.success,
      );
    } else {
      context.showInAppNotification('Failed to create group');
    }
  }

  void _sendInvite() async {
    final email = _inviteEmailController.text.trim();
    if (email.isEmpty) {
      context.showInAppNotification('Please enter an email address');
      return;
    }

    final provider = context.read<GroupQuizProvider>();
    if (provider.activeGroupId == null) return;

    final name = provider.groupData?['name'] ?? 'Bible Quiz';
    final error = await provider.inviteUserByEmail(
      provider.activeGroupId!,
      name,
      email,
    );

    if (!mounted) return;
    if (error == null) {
      context.showInAppNotification(
        'Invitation sent successfully!',
        type: InAppNotificationType.success,
      );
      _inviteEmailController.clear();
      provider.clearSuggestions();
    } else {
      if (error.contains('not found')) {
        _showUnregisteredInviteDialog(email);
      } else {
        context.showInAppNotification(error, type: InAppNotificationType.error);
      }
    }
  }

  void _showUnregisteredInviteDialog(String email) {
    AppTheme theme = context.read<AppTheme>();
    final provider = context.read<GroupQuizProvider>();
    final groupName = provider.groupData?['name'] ?? 'Quiz Group';
    final groupId = provider.activeGroupId ?? '';
    final scopeType = provider.scopeType;
    final scopeValue = provider.scopeValue;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: theme.brandDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const PrimaryText(text: 'User Not Found 👥'),
          content: SecondaryText(
            text:
                'The email "$email" is not registered on MindPilot. Share a link so they can download the app and join directly!',
            color: theme.accentTxt.withOpacity(0.8),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: SecondaryText(
                text: 'Cancel',
                color: theme.accentTxt.withOpacity(0.6),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                if (context.mounted) {
                  AppShareSheet.showForGroup(
                    context,
                    groupId: groupId,
                    groupName: groupName,
                    scopeType: scopeType,
                    scopeValue: scopeValue,
                  );
                }
              },
              child: PrimaryText(
                text: 'Share Invite',
                color: theme.primaryBase,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showRemoveMemberConfirmDialog(
    String memberUid,
    String memberName,
    GroupQuizProvider provider,
    AppTheme theme,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: theme.brandDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const PrimaryText(text: 'Remove Player? 🚪'),
          content: SecondaryText(
            text:
                'Are you sure you want to remove "$memberName" from this group room?',
            color: theme.accentTxt.withOpacity(0.8),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: SecondaryText(
                text: 'Cancel',
                color: theme.accentTxt.withOpacity(0.6),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final error = await provider.removeMemberFromGroup(
                  provider.activeGroupId!,
                  memberUid,
                );
                if (mounted) {
                  if (error != null) {
                    context.showInAppNotification(
                      error,
                      type: InAppNotificationType.error,
                    );
                  } else {
                    context.showInAppNotification(
                      '$memberName removed from group.',
                      type: InAppNotificationType.success,
                    );
                  }
                }
              },
              child: PrimaryText(text: 'Remove', color: theme.errorPrimary),
            ),
          ],
        );
      },
    );
  }

  void _proceedToStartGame() async {
    final provider = context.read<GroupQuizProvider>();

    // Save settings local state into provider scope settings
    if (provider.scopeType == 'chapter' || provider.scopeType == 'custom') {
      final text = _bibleChapterController.text.trim();
      if (text.isEmpty) {
        final label = provider.scopeType == 'chapter'
            ? 'chapter (e.g. Genesis 1)'
            : 'custom topic';
        context.showInAppNotification('Please specify a $label');
        return;
      }
      provider.scopeValue = text;
    }

    final error = await provider.startGame();
    if (!mounted) return;
    if (error != null) {
      _handleGenerationFailure(error, true);
    }
  }

  Future<void> _handleGenerationFailure(String errorMsg, bool isStartGame) async {
    final provider = context.read<GroupQuizProvider>();
    final authProvider = context.read<AppAuthProvider>();

    // Only present this if the user is Freemium and it is an AI generation/connection error
    if (authProvider.userType != "Pro Member" &&
        (errorMsg.contains("AI connection failed") ||
         errorMsg.contains("AI generated an invalid format") ||
         errorMsg.contains("Failed to get response"))) {
      
      final theme = context.read<AppTheme>();
      final watchAd = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: theme.brandDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const PrimaryText(text: 'AI Connection Error 🤖'),
          content: SecondaryText(
            text: 'Question generation failed on the free server. Would you like to use the faster Gemini server for free by watching a short ad?',
            color: theme.accentTxt.withOpacity(0.8),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: SecondaryText(
                text: 'Cancel',
                color: theme.accentTxt.withOpacity(0.6),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryBase,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const PrimaryText(
                text: 'Watch Ad',
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );

      if (watchAd == true) {
        if (!mounted) return;
        provider.setLoading(true);
        await AdService.instance.showRewardedAd(
          onUserEarnedReward: (ad, reward) async {
            // Temporarily set Gemini Pro access
            GeminiService().setIsPro(true);
            String? newErr;
            if (isStartGame) {
              newErr = await provider.startGame();
            } else {
              newErr = await provider.preGenerateQuestions();
            }
            // Reset to Freemium status
            GeminiService().setIsPro(false);

            if (mounted) {
              provider.setLoading(false);
              if (newErr != null) {
                context.showInAppNotification(newErr, type: InAppNotificationType.error);
              } else {
                context.showInAppNotification('AI generated questions successfully using Gemini!', type: InAppNotificationType.success);
              }
            }
          },
          onAdFailedToShow: () {
            if (mounted) {
              provider.setLoading(false);
              context.showInAppNotification('Failed to load ad. Please try again.', type: InAppNotificationType.error);
            }
          },
        );
      }
    } else {
      context.showInAppNotification(errorMsg, type: InAppNotificationType.error);
    }
  }

  void _showStartAnywayDialog(AppTheme theme) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: theme.brandDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const PrimaryText(text: 'Pending Invitations 👥'),
          content: SecondaryText(
            text:
                'Some friends have not accepted the invitation yet. Do you want to wait for them or start the quiz anyway?',
            color: theme.accentTxt.withOpacity(0.8),
          ),
          actions: <Widget>[
            TextButton(
              child: SecondaryText(
                text: 'Wait for them',
                color: theme.accentTxt.withOpacity(0.6),
              ),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryBase,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                _proceedToStartGame();
              },
              child: const PrimaryText(
                text: 'Start Anyway',
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      },
    );
  }

  void _startGame() {
    final provider = context.read<GroupQuizProvider>();
    final membersMap =
        provider.groupData?['members'] as Map<String, dynamic>? ?? {};

    int pendingCount = 0;
    membersMap.forEach((uid, val) {
      if (val['status'] == 'pending') {
        pendingCount++;
      }
    });

    if (pendingCount > 0) {
      final theme = context.read<AppTheme>();
      _showStartAnywayDialog(theme);
    } else {
      _proceedToStartGame();
    }
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    final provider = context.watch<GroupQuizProvider>();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    // If we were listening to a specific group and it gets disbanded:
    if (_isListening &&
        provider.activeGroupId == null &&
        provider.groupData == null) {
      _isListening = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.showInAppNotification(
            'The group lobby has been disbanded by the creator.',
          );
          context.read<HomeProvider>().navIndex = 2;
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    } else if (provider.activeGroupId != null) {
      _isListening = true;
    }

    // Check if we need to auto-navigate to the active game
    if (provider.gameData != null &&
        provider.gameData!['status'] == 'playing') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_gamePushed) {
          _gamePushed = true;
          AnalyticsService.logGroupQuizAction(
            'joined',
            groupId: provider.activeGroupId,
          );
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'GroupQuizScreen'),
                  builder: (_) =>
                      GroupQuizScreen(groupId: provider.activeGroupId!),
                ),
              )
              .then((_) {
                _gamePushed = false;
              });
        }
      });
    }

    final hasGroup =
        provider.activeGroupId != null && provider.groupData != null;

    return PopScope(
      onPopInvoked: (didPop) {
        provider.leaveGroup();
        context.read<HomeProvider>().navIndex = 2;
        if (!didPop) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: PrimaryText(
            text: hasGroup
                ? (provider.groupData?['name'] ?? 'Lobby')
                : 'Quiz Lobby',
            color: theme.accentTxt,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          centerTitle: true,
          leading: Icon(Icons.arrow_back_ios, color: theme.accentTxt, size: 20)
              .rippleClick(() {
                provider.leaveGroup();
                context.read<HomeProvider>().navIndex = 2;
                Navigator.of(context).popUntil((route) => route.isFirst);
              }),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: (widget.groupId != null && provider.activeGroupId == null)
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.primaryBase,
                        ),
                      ),
                    )
                  : (hasGroup
                        ? _buildLobby(theme, provider, currentUid)
                        : _buildCreateGroupView(theme)),
            ),
            if (provider.isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.75),
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: GlassContainer(
                          padding: const EdgeInsets.all(32),
                          border: Border.all(
                            color: theme.primaryBase.withOpacity(0.3),
                            width: 1.5,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.primaryBase,
                                ),
                              ),
                              24.verticalSpace,
                              PrimaryText(
                                text:
                                    'Generating ${_getScopeFriendlyName(provider.scopeType, provider.scopeValue)} Quiz... 📖',
                                color: theme.accentTxt,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                textAlign: TextAlign.center,
                              ),
                              8.verticalSpace,
                              SecondaryText(
                                text:
                                    (provider.scopeType == 'general' ||
                                        provider.scopeType == 'chapter')
                                    ? 'Creating scripture questions. This can take up to a minute.'
                                    : 'Creating quiz questions. This can take up to a minute.',
                                color: theme.accentTxt.withOpacity(0.6),
                                fontSize: 13,
                                textAlign: TextAlign.center,
                              ),
                              24.verticalSpace,
                              CustomButton(
                                label: 'Cancel',
                                isOutline: true,
                                borderColor: theme.errorPrimary,
                                textColor: theme.errorPrimary,
                                onPressed: () {
                                  provider.cancelGameGeneration();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // View for entering group details to initialize a group lobby
  Widget _buildCreateGroupView(AppTheme theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryText(
          text: 'Start a Group Quiz 👥',
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: theme.accentTxt,
          textAlign: TextAlign.center,
        ),
        16.verticalSpace,
        SecondaryText(
          text:
              'Challenge your friends to study scripture together in real-time. Create a room name to get started!',
          color: theme.accentTxt.withOpacity(0.6),
          textAlign: TextAlign.center,
        ),
        32.verticalSpace,
        CustomTextField(
          textController: _groupNameController,
          autoFocus: false,
          hintText: 'e.g. Sunday Bible Study',
          textInputType: TextInputType.text,
          textInputAction: TextInputAction.done,
          labelText: 'Room Name',
          labelColor: Colors.white,
          textColor: Colors.white,
        ),
        24.verticalSpace,
        CustomButton(label: 'Create Room', onPressed: _createGroup),
      ],
    );
  }

  // Active lobby with settings, roster, and invitations
  Widget _buildLobby(
    AppTheme theme,
    GroupQuizProvider provider,
    String? currentUid,
  ) {
    final groupData = provider.groupData!;
    final isCreator = groupData['createdBy'] == currentUid;

    final membersMap = groupData['members'] as Map<String, dynamic>? ?? {};
    final List<MapEntry<String, dynamic>> membersList = membersMap.entries
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          20.verticalSpace,
          // Member Roster
          PrimaryText(
            text: 'Players in Room',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.accentTxt,
          ),
          12.verticalSpace,
          GlassContainer(
            padding: const EdgeInsets.all(16),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: membersList.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white10),
              itemBuilder: (context, index) {
                final entry = membersList[index];
                final uid = entry.key;
                final data = entry.value as Map<String, dynamic>;

                final email = data['email'] ?? '';
                final name = data['displayName'] ?? email;
                final status = data['status'] ?? 'pending';
                final isSelf = uid == currentUid;

                Widget statusIcon;
                Color statusColor;
                if (status == 'accepted') {
                  statusIcon = const Icon(
                    Icons.check_circle_outline,
                    color: Colors.greenAccent,
                    size: 18,
                  );
                  statusColor = Colors.greenAccent;
                } else if (status == 'rejected') {
                  statusIcon = const Icon(
                    Icons.cancel_outlined,
                    color: Colors.redAccent,
                    size: 18,
                  );
                  statusColor = Colors.redAccent;
                } else {
                  statusIcon = const Icon(
                    Icons.hourglass_empty_outlined,
                    color: Colors.amber,
                    size: 18,
                  );
                  statusColor = Colors.amber;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PrimaryText(
                              text: '$name ${isSelf ? "(You)" : ""}',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.accentTxt,
                            ),
                            SecondaryText(
                              text: email,
                              fontSize: 12,
                              color: theme.accentTxt.withOpacity(0.5),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          statusIcon,
                          6.horizontalSpace,
                          SecondaryText(
                            text: status[0].toUpperCase() + status.substring(1),
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          if (isCreator &&
                              !isSelf &&
                              (status == 'pending' ||
                                  status == 'accepted')) ...[
                            8.horizontalSpace,
                            Icon(
                              Icons.remove_circle_outline,
                              color: theme.errorPrimary,
                              size: 18,
                            ).rippleClick(() {
                              _showRemoveMemberConfirmDialog(
                                uid,
                                name,
                                provider,
                                theme,
                              );
                            }),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          24.verticalSpace,

          // Send invites
          Builder(
            builder: (context) {
              final isGenerating = groupData['isGeneratingGame'] == true;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PrimaryText(
                    text: 'Invite Friends',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isGenerating
                        ? theme.accentTxt.withOpacity(0.4)
                        : theme.accentTxt,
                  ),
                  12.verticalSpace,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: CustomTextField(
                          textController: _inviteEmailController,
                          autoFocus: false,
                          hintText: isGenerating
                              ? 'Quiz is starting...'
                              : 'friend@email.com',
                          textInputType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.send,
                          labelText: '',
                          textColor: Colors.white,
                          readOnly: isGenerating,
                          onDone: isGenerating ? null : _sendInvite,
                        ),
                      ),
                      12.horizontalSpace,
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isGenerating
                                  ? Colors.white10
                                  : theme.primaryBase,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                            ),
                            onPressed: isGenerating ? null : _sendInvite,
                            child: PrimaryText(
                              text: 'Invite',
                              color: isGenerating
                                  ? theme.accentTxt.withOpacity(0.3)
                                  : Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (provider.emailSuggestions.isNotEmpty &&
                      !isGenerating) ...[
                    8.verticalSpace,
                    GlassContainer(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: provider.emailSuggestions.map((suggestion) {
                          final email = suggestion['email'] ?? '';
                          final displayName = suggestion['displayName'] ?? '';
                          return ListTile(
                            dense: true,
                            title: PrimaryText(
                              text: displayName,
                              color: theme.accentTxt,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            subtitle: SecondaryText(
                              text: email,
                              color: theme.accentTxt.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_rounded,
                              color: theme.primaryBase,
                              size: 16,
                            ),
                            onTap: () {
                              _inviteEmailController.text = email;
                              provider.clearSuggestions();
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          // Share Group Link / QR — visible to creator only
          if (isCreator) ...[
            12.verticalSpace,
            GestureDetector(
              onTap: () {
                final provider = context.read<GroupQuizProvider>();
                final groupId = provider.activeGroupId ?? '';
                final groupName = provider.groupData?['name'] ?? 'Quiz Group';
                final scopeType = provider.scopeType;
                final scopeValue = provider.scopeValue;
                AppShareSheet.showForGroup(
                  context,
                  groupId: groupId,
                  groupName: groupName,
                  scopeType: scopeType,
                  scopeValue: scopeValue,
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: theme.primaryBase.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.primaryBase.withOpacity(0.35),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_2_rounded,
                      color: theme.primaryBase,
                      size: 18,
                    ),
                    8.horizontalSpace,
                    PrimaryText(
                      text: 'Share / QR Invite',
                      color: theme.primaryBase,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ],
                ),
              ),
            ),
          ],
          24.verticalSpace,

          // Game Settings (Creator can edit, others view read-only)
          PrimaryText(
            text: 'Game Settings',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.accentTxt,
          ),
          12.verticalSpace,
          Builder(
            builder: (context) {
              final isGenerating = groupData['isGeneratingGame'] == true;
              return GlassContainer(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Questions Per Player (typed by creator)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SecondaryText(
                                text: 'Questions per player',
                                color: theme.accentTxt,
                              ),
                              4.verticalSpace,
                              SecondaryText(
                                text:
                                    'Total: ${provider.questionCount} questions (${provider.acceptedMembersCount} players)',
                                fontSize: 12,
                                color: theme.accentTxt.withValues(alpha: 0.5),
                              ),
                            ],
                          ),
                        ),
                        if (isCreator)
                          SizedBox(
                            width: 70,
                            child: TextField(
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              enabled: !isGenerating,
                              style: TextStyle(
                                color: isGenerating
                                    ? theme.primaryBase.withOpacity(0.5)
                                    : theme.primaryBase,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: theme.primaryBase.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                disabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: theme.primaryBase.withValues(
                                      alpha: 0.1,
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: theme.primaryBase,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              controller: _questionsPerPlayerController,
                              onChanged: (val) {
                                final parsed = int.tryParse(val);
                                if (parsed != null &&
                                    parsed > 0 &&
                                    parsed <= 15) {
                                  provider.questionsPerParticipant = parsed;
                                }
                              },
                            ),
                          )
                        else
                          PrimaryText(
                            text: '${provider.questionsPerParticipant}',
                            color: theme.primaryBase,
                            fontWeight: FontWeight.bold,
                          ),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 24),

                    // 2. Timer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SecondaryText(
                          text: 'Timer per Question',
                          color: theme.accentTxt,
                        ),
                        if (isCreator)
                          DropdownButton<int>(
                            value: provider.timerSeconds,
                            dropdownColor: theme.brandDark,
                            underline: const SizedBox(),
                            style: TextStyle(
                              color: isGenerating
                                  ? theme.primaryBase.withOpacity(0.5)
                                  : theme.primaryBase,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            items: [15, 30, 45, 60]
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text('$t seconds'),
                                  ),
                                )
                                .toList(),
                            onChanged: isGenerating
                                ? null
                                : (v) {
                                    if (v != null) provider.timerSeconds = v;
                                  },
                          )
                        else
                          PrimaryText(
                            text: '${provider.timerSeconds}s',
                            color: theme.primaryBase,
                            fontWeight: FontWeight.bold,
                          ),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 24),

                    // 3. Quiz Scope Type
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SecondaryText(
                          text: 'Trivia Scope',
                          color: theme.accentTxt,
                        ),
                        16.horizontalSpace,
                        if (isCreator)
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: DropdownButton<String>(
                                isExpanded: false,
                                value: provider.scopeType,
                                dropdownColor: theme.brandDark,
                                underline: const SizedBox(),
                                style: TextStyle(
                                  color: isGenerating
                                      ? theme.primaryBase.withOpacity(0.5)
                                      : theme.primaryBase,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: 'general',
                                    child: Text('General Bible Knowledge'),
                                  ),
                                  const DropdownMenuItem(
                                    value: 'chapter',
                                    child: Text('Specific Chapter Study'),
                                  ),
                                  const DropdownMenuItem(
                                    value: 'tech',
                                    child: Text('Technology & Coding'),
                                  ),
                                  const DropdownMenuItem(
                                    value: 'science',
                                    child: Text('Science & Physics'),
                                  ),
                                  const DropdownMenuItem(
                                    value: 'english',
                                    child: Text('English & Literature'),
                                  ),
                                  const DropdownMenuItem(
                                    value: 'economics',
                                    child: Text('Economics & Finance'),
                                  ),
                                  const DropdownMenuItem(
                                    value: 'mindfulness',
                                    child: Text('Personality & Mindfulness'),
                                  ),
                                  const DropdownMenuItem(
                                    value: 'custom',
                                    child: Text('Custom Topic'),
                                  ),
                                ],
                                onChanged: isGenerating
                                    ? null
                                    : (v) {
                                        if (v != null) {
                                          provider.scopeType = v;
                                          if (v == 'custom') {
                                            final roomName =
                                                provider.groupData?['name'] ??
                                                '';
                                            provider.scopeValue = roomName;
                                            _bibleChapterController.text =
                                                roomName;
                                          }
                                        }
                                      },
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: PrimaryText(
                                text: provider.scopeType == 'general'
                                    ? 'General Bible Knowledge'
                                    : provider.scopeType == 'chapter'
                                    ? 'Specific Chapter Study'
                                    : provider.scopeType == 'tech'
                                    ? 'Technology & Coding'
                                    : provider.scopeType == 'science'
                                    ? 'Science & Physics'
                                    : provider.scopeType == 'english'
                                    ? 'English & Literature'
                                    : provider.scopeType == 'economics'
                                    ? 'Economics & Finance'
                                    : provider.scopeType == 'mindfulness'
                                    ? 'Personality & Mindfulness'
                                    : 'Custom Topic',
                                color: theme.primaryBase,
                                fontWeight: FontWeight.bold,
                                textOverflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                      ],
                    ),

                    // 4. Chapter/Topic textfield if Chapter or Custom Topic is selected
                    if (provider.scopeType == 'chapter' ||
                        provider.scopeType == 'custom') ...[
                      16.verticalSpace,
                      const Divider(color: Colors.white10, height: 1),
                      16.verticalSpace,
                      if (isCreator)
                        CustomTextField(
                          textController: _bibleChapterController,
                          autoFocus: false,
                          hintText: provider.scopeType == 'chapter'
                              ? 'e.g. Romans 8'
                              : 'e.g. World History',
                          textInputType: TextInputType.text,
                          textInputAction: TextInputAction.done,
                          labelText: provider.scopeType == 'chapter'
                              ? 'Bible Book & Chapter'
                              : 'Enter Custom Topic',
                          labelColor: Colors.white,
                          textColor: Colors.white,
                          readOnly: isGenerating,
                          onChanged: (val) {
                            provider.scopeValue = val ?? '';
                          },
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SecondaryText(
                              text: provider.scopeType == 'chapter'
                                  ? 'Target Chapter'
                                  : 'Custom Topic',
                              color: theme.accentTxt,
                            ),
                            PrimaryText(
                              text: provider.scopeValue,
                              color: theme.primaryBase,
                              fontWeight: FontWeight.bold,
                            ),
                          ],
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
          32.verticalSpace,

          // Start game controls
          if (isCreator) ...[
            Builder(
              builder: (context) {
                final membersMap =
                    provider.groupData?['members'] as Map<String, dynamic>? ??
                    {};
                int acceptedCountExcludingSelf = 0;
                membersMap.forEach((uid, val) {
                  if (uid != currentUid && val['status'] == 'accepted') {
                    acceptedCountExcludingSelf++;
                  }
                });
                final canStart = acceptedCountExcludingSelf > 0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!canStart) ...[
                      Center(
                        child: SecondaryText(
                          text:
                              '⚠️ Waiting for at least one invited friend to accept the invitation before starting.',
                          color: Colors.amber.withValues(alpha: 0.8),
                          fontSize: 13,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      16.verticalSpace,
                    ],
                    // Pre-generation section for host
                    Builder(
                      builder: (context) {
                        final isGeneratingQs =
                            groupData['isGeneratingQuestions'] == true;
                        final qsReady = groupData['questionsReady'] == true;

                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: CustomButton(
                                    label: isGeneratingQs
                                        ? 'Generating...'
                                        : (qsReady
                                              ? 'Regenerate Questions'
                                              : 'Generate Questions'),
                                    loading: isGeneratingQs,
                                    onPressed: isGeneratingQs
                                        ? null
                                        : () async {
                                            final err = await provider
                                                .preGenerateQuestions();
                                            if (context.mounted &&
                                                err != null) {
                                              _handleGenerationFailure(err, false);
                                            }
                                          },
                                    backgroundColor: qsReady
                                        ? Colors.white10
                                        : theme.primaryBase.withOpacity(0.08),
                                    textColor: qsReady
                                        ? theme.accentTxt
                                        : theme.primaryBase,
                                    isOutline: qsReady,
                                    borderColor: qsReady
                                        ? theme.accentTxt.withOpacity(0.3)
                                        : null,
                                  ),
                                ),
                                if (qsReady) ...[
                                  12.horizontalSpace,
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.greenAccent.withOpacity(
                                          0.5,
                                        ),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      color: Colors.greenAccent,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            16.verticalSpace,
                          ],
                        );
                      },
                    ),
                    CustomButton(
                      label: 'Start Game',
                      onPressed: canStart ? _startGame : null,
                      backgroundColor: canStart
                          ? theme.primaryBase
                          : Colors.white10,
                      textColor: canStart
                          ? Colors.black
                          : theme.accentTxt.withValues(alpha: 0.3),
                    ),
                    16.verticalSpace,
                    CustomButton(
                      label: 'Exit Room',
                      isOutline: true,
                      borderColor: theme.errorPrimary,
                      textColor: theme.errorPrimary,
                      onPressed: () {
                        provider.leaveGroup();
                        context.read<HomeProvider>().navIndex = 2;
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      },
                    ),
                  ],
                );
              },
            ),
          ] else ...[
            GlassContainer(
              padding: const EdgeInsets.symmetric(vertical: 16),
              border: Border.all(color: Colors.white12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  ),
                  16.horizontalSpace,
                  const SecondaryText(
                    text: 'Waiting for Host to start the quiz...',
                  ),
                ],
              ),
            ),
            16.verticalSpace,
            CustomButton(
              label: 'Exit Room',
              isOutline: true,
              borderColor: theme.errorPrimary,
              textColor: theme.errorPrimary,
              onPressed: () {
                provider.leaveGroup();
                context.read<HomeProvider>().navIndex = 2;
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ],
        ],
      ),
    );
  }
}
