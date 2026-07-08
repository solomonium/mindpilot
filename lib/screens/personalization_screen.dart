import 'package:mindpilot/export.dart';

class PersonalizationScreen extends StatefulWidget {
  const PersonalizationScreen({super.key});

  @override
  State<PersonalizationScreen> createState() => _PersonalizationScreenState();
}

class _PersonalizationScreenState extends State<PersonalizationScreen> {
  final List<Map<String, dynamic>> goals = [
    {
      "title": "Expand My Knowledge",
      "subtitle": "Learn new topics across Bible, science & more",
      "icon": Icons.menu_book_outlined,
      "color": const Color(0xFF6366F1),
    },
    {
      "title": "Sharpen My Mind",
      "subtitle": "Build focus, memory & critical thinking",
      "icon": Icons.psychology_outlined,
      "color": const Color(0xFF3B82F6),
    },
    {
      "title": "Track My Growth",
      "subtitle": "Measure progress and celebrate wins",
      "icon": Icons.trending_up,
      "color": const Color(0xFF10B981),
    },
    {
      "title": "Make Better Decisions",
      "subtitle": "Gain clarity on complex life choices",
      "icon": Icons.lightbulb_outline,
      "color": const Color(0xFFF59E0B),
    },
    {
      "title": "Build Daily Habits",
      "subtitle": "Stay consistent with structured routines",
      "icon": Icons.repeat_outlined,
      "color": const Color(0xFFEF4444),
    },
    {
      "title": "Grow Spiritually",
      "subtitle": "Deepen faith and biblical understanding",
      "icon": Icons.auto_awesome_outlined,
      "color": const Color(0xFF8B5CF6),
    },
  ];

  final Set<int> selectedGoals = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadExistingPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndPromptHeardFrom();
    });
  }

  Future<void> _checkAndPromptHeardFrom() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!doc.exists) return;

      final data = doc.data();
      if (data == null) return;

      if (!data.containsKey('heardFrom') ||
          data['heardFrom'] == null ||
          data['heardFrom'].toString().trim().isEmpty ||
          data['heardFrom'] == 'Unknown') {
        if (mounted) {
          _showHeardFromDialog();
        }
      }
    } catch (e) {
      debugPrint('Error checking heardFrom: $e');
    }
  }

  void _showHeardFromDialog() {
    final theme = context.read<AppTheme>();
    String? selectedOption;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                backgroundColor: theme.brandDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const PrimaryText(text: 'Welcome to MindPilot! 👋'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SecondaryText(
                      text: 'Where did you hear about us?',
                      color: theme.accentTxt.withOpacity(0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    16.verticalSpace,
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.accentTxt.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.accentTxt.withOpacity(0.1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedOption,
                          hint: SecondaryText(
                            text: 'Select an option',
                            color: theme.accentTxt.withOpacity(0.4),
                          ),
                          dropdownColor: theme.brandDark,
                          isExpanded: true,
                          icon: Icon(Icons.arrow_drop_down, color: theme.accentTxt),
                          items: [
                            'Google Search',
                            'App Store / Play Store',
                            'Social Media (Instagram/TikTok/Twitter)',
                            'Reddit',
                            'Friend / Recommendation',
                            'Ad / Promotion',
                            'Other',
                          ].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: PrimaryText(
                                text: value,
                                fontSize: 14,
                                color: theme.accentTxt,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              selectedOption = val;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryBase,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    onPressed: selectedOption == null
                        ? null
                        : () async {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .update({'heardFrom': selectedOption});
                            }
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          },
                    child: const PrimaryText(
                      text: 'Submit & Proceed',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _loadExistingPreferences() async {
    final auth = FirebaseAuth.instance.currentUser;
    if (auth != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(auth.uid)
          .get();
      final existing = List<String>.from(doc.data()?['personalization'] ?? []);
      if (existing.isNotEmpty) {
        setState(() {
          for (int i = 0; i < goals.length; i++) {
            if (existing.contains(goals[i]['title'])) {
              selectedGoals.add(i);
            }
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    return Scaffold(
      backgroundColor: theme.brandDark,
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  20.verticalSpace,
                  20.verticalSpace,
                  PrimaryText(
                    text: R.S.personalizeTitle,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    textAlign: TextAlign.center,
                    color: theme.accentTxt,
                  ),
                  8.verticalSpace,
                  SecondaryText(
                    text:
                        'Please select at least one area to help us tailor your experience.',
                    textAlign: TextAlign.center,
                    color: selectedGoals.isEmpty
                        ? theme.errorPrimary.withOpacity(0.8)
                        : theme.accentTxt.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: selectedGoals.isEmpty
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  20.verticalSpace,
                  Expanded(
                    child: ListView.separated(
                      itemCount: goals.length,
                      separatorBuilder: (context, index) => 16.verticalSpace,
                      itemBuilder: (context, index) {
                        final goal = goals[index];
                        final isSelected = selectedGoals.contains(index);
                        return _goalTile(goal, isSelected, () {
                          setState(() {
                            if (isSelected) {
                              selectedGoals.remove(index);
                            } else {
                              selectedGoals.add(index);
                            }
                          });
                        });
                      },
                    ),
                  ),
                  24.verticalSpace,
                  CustomButton(
                    label: R.S.continueBtn,
                    loading: _isSaving,
                    onPressed: () {
                      if (selectedGoals.isNotEmpty) {
                        _finishPersonalization();
                      } else {
                        context.showInAppNotification(
                          'Please select at least one focus area to continue.',
                        );
                      }
                    },
                    backgroundColor: selectedGoals.isEmpty
                        ? theme.primaryBase.withOpacity(0.3)
                        : theme.primaryBase,
                  ),
                  40.verticalSpace,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _finishPersonalization({bool isSkip = false}) async {
    if (!isSkip) setState(() => _isSaving = true);
    try {
      final auth = FirebaseAuth.instance.currentUser;
      if (auth != null && !isSkip) {
        final selectedTitles = selectedGoals
            .map((index) => goals[index]['title'] as String)
            .toList();
        await FirebaseFirestore.instance.collection('users').doc(auth.uid).set({
          'personalization': selectedTitles,
          'hasCompletedSetup': true,
        }, SetOptions(merge: true));
        await AnalyticsService.logPersonalizationCompleted(selectedTitles);
      }

      if (mounted) {
        context.pushOff(const MainScreen());
      }
    } catch (e) {
      if (mounted && !isSkip) {
        context.showInAppNotification('Error saving preferences: $e');
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Widget _goalTile(
    Map<String, dynamic> goal,
    bool isSelected,
    VoidCallback onTap,
  ) {
    AppTheme theme = context.watch();
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      gradient: isSelected ? null : theme.glassGradient,
      color: isSelected ? theme.primaryBase.withOpacity(0.2) : null,
      border: isSelected
          ? Border.all(color: theme.primaryBase, width: 2)
          : null,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: goal['color'].withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(goal['icon'], color: goal['color']),
          ),
          16.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PrimaryText(
                  text: goal['title'],
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.accentTxt,
                ),
                SecondaryText(
                  text: goal['subtitle'],
                  fontSize: 12,
                  color: theme.accentTxt.withOpacity(0.6),
                ),
              ],
            ),
          ),
          if (isSelected)
            Icon(Icons.check_circle, color: theme.primaryBase, size: 24),
        ],
      ),
    ).rippleClick(onTap);
  }
}
