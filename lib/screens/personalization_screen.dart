import 'package:mindpilot/export.dart';
import 'package:intl_phone_field/countries.dart';

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
      
      bool shouldPrompt = false;
      if (!doc.exists) {
        shouldPrompt = true;
      } else {
        final data = doc.data();
        if (data != null) {
          final currentHeardFrom = data['heardFrom'] as String? ?? '';
          if (!data.containsKey('heardFrom') ||
              data['heardFrom'] == null ||
              currentHeardFrom.trim().isEmpty ||
              currentHeardFrom == 'Unknown') {
            shouldPrompt = true;
          }
        }
      }

      if (shouldPrompt && mounted) {
        _showHeardFromDialog();
      } else {
        _checkAndPromptCountry();
      }
    } catch (e) {
      debugPrint('Error checking heardFrom: $e');
      _checkAndPromptCountry();
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
                                  .set({'heardFrom': selectedOption}, SetOptions(merge: true));
                            }
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            _checkAndPromptCountry();
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

  Future<void> _checkAndPromptCountry() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      
      bool shouldPrompt = false;
      if (!doc.exists) {
        shouldPrompt = true;
      } else {
        final data = doc.data();
        if (data != null) {
          final currentCountry = data['country'] as String? ?? '';
          if (!data.containsKey('country') ||
              data['country'] == null ||
              currentCountry.trim().isEmpty) {
            shouldPrompt = true;
          }
        }
      }

      if (shouldPrompt && mounted) {
        _showCountryDialog();
      }
    } catch (e) {
      debugPrint('Error checking country: $e');
    }
  }

  String _getFlagEmoji(String countryCode) {
    if (countryCode.length != 2) return '';
    final int firstLetter = countryCode.toUpperCase().codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = countryCode.toUpperCase().codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  void _showCountryDialog() {
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
                title: const PrimaryText(
                  text: 'Select Your Country 🌍',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SecondaryText(
                      text: 'Please select your country to continue using MindPilot.',
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                    16.verticalSpace,
                    InkWell(
                      onTap: () async {
                        final chosen = await _showCountryPickerBottomSheet();
                        if (chosen != null) {
                          setState(() {
                            selectedOption = chosen;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: theme.accentTxt.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedOption != null
                                ? theme.primaryBase
                                : theme.accentTxt.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: PrimaryText(
                                text: selectedOption ?? 'Select Country',
                                fontSize: 14,
                                color: selectedOption != null ? Colors.white : Colors.white54,
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: theme.primaryBase,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryBase,
                      foregroundColor: Colors.white,
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
                                  .set({'country': selectedOption}, SetOptions(merge: true));
                            }
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          },
                    child: const PrimaryText(
                      text: 'Submit & Proceed',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
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

  Future<String?> _showCountryPickerBottomSheet() async {
    final theme = context.read<AppTheme>();
    String searchQuery = '';

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: theme.brandDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final filteredCountries = countries.where((country) {
              final name = country.name.toLowerCase();
              final query = searchQuery.toLowerCase();
              return name.contains(query) || country.code.toLowerCase().contains(query);
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(bottomSheetContext).size.height * 0.7,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: PrimaryText(
                            text: 'Search Country',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(bottomSheetContext),
                        ),
                      ],
                    ),
                    12.verticalSpace,
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.accentTxt.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.accentTxt.withValues(alpha: 0.15)),
                      ),
                      child: TextField(
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        autofocus: true,
                        decoration: InputDecoration(
                          icon: const Icon(Icons.search, color: Colors.white54, size: 18),
                          border: InputBorder.none,
                          hintText: 'Type country name...',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 14,
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            searchQuery = val;
                          });
                        },
                      ),
                    ),
                    16.verticalSpace,
                    Expanded(
                      child: filteredCountries.isEmpty
                          ? const Center(
                              child: SecondaryText(
                                text: 'No countries found',
                                color: Colors.white54,
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredCountries.length,
                              itemBuilder: (context, index) {
                                final country = filteredCountries[index];
                                final flag = _getFlagEmoji(country.code);

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    clipBehavior: Clip.antiAlias,
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                      dense: true,
                                      leading: Text(
                                        flag,
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                      title: PrimaryText(
                                        text: country.name,
                                        fontSize: 14,
                                        color: Colors.white,
                                      ),
                                      onTap: () {
                                        Navigator.pop(bottomSheetContext, country.name);
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
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
