// ignore_for_file: must_be_immutable

import 'package:mindpilot/export.dart';

class DirectScreen extends StatefulWidget {
  DirectScreen({super.key, this.titleDestination});

  String? titleDestination;

  @override
  State<DirectScreen> createState() => _DirectScreenState();
}

class _DirectScreenState extends State<DirectScreen> with FormMixin {
  final List<String> _categories = ['Direct Messages', 'Unread', 'Archived', 'Spam'];
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = _categories[0];
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: theme.background,
      body: Consumer<HomeProvider>(
        builder: (context, home, _) {
          return Form(
            key: formKey,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        // Top Bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CustomDropdown<String>(
                              items: _categories,
                              value: _selectedCategory,
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedCategory = val);
                              },
                              child: Row(
                                children: [
                                  PrimaryText(
                                    text: _selectedCategory,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1170B2),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.keyboard_arrow_down, color: Color(0xFF1170B2)),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                PrimaryText(
                                  text: R.S.unreads,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF1170B2),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 40,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      margin: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Icon(Icons.edit_square, color: Color(0xFF1170B2), size: 20),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // Search bar
                        CustomContainer(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          borderRadius: 8,
                          color: const Color(0xFF1170B2).withOpacity(0.5),
                          border: Border.all(color: Colors.transparent),
                          child: Row(
                            children: [
                              const Icon(Icons.search, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              SecondaryText(
                                text: R.S.findDM,
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // DM List
                        ...List.generate(Mock.dms().length, (index) {
                          var dm = Mock.dms()[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 20.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Avatar with online status
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.grey.shade200,
                                      child: Icon(Icons.person, color: Colors.grey.shade400, size: 30),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                // Message Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          PrimaryText(
                                            text: dm['name'],
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: theme.primaryText,
                                          ),
                                          const SizedBox(width: 8),
                                          if (dm['online'])
                                            CustomContainer(
                                              width: 8,
                                              height: 8,
                                              padding: EdgeInsets.zero,
                                              borderRadius: 50,
                                              color: Colors.green,
                                              border: Border.all(color: Colors.transparent),
                                              child: const SizedBox.shrink(),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      SecondaryText(
                                        text: dm['message'],
                                        fontSize: 14,
                                        color: dm['unread'] > 0 ? theme.primaryText : theme.secondaryTxt,
                                        // fontweight if unread can't be easily done with SecondaryText if it forces normal weight, 
                                        // but we can just use the color difference.
                                      ),
                                      const SizedBox(height: 4),
                                      SecondaryText(
                                        text: dm['time'],
                                        fontSize: 12,
                                        color: const Color(0xFF1170B2),
                                      ),
                                    ],
                                  ),
                                ),
                                // Unread badge
                                if (dm['unread'] > 0)
                                  CustomContainer(
                                    width: 24,
                                    height: 24,
                                    padding: EdgeInsets.zero,
                                    borderRadius: 50,
                                    color: const Color(0xFFE9AD21),
                                    border: Border.all(color: Colors.transparent),
                                    child: Center(
                                      child: Text(
                                        dm['unread'].toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                        
                        const SizedBox(height: 100), // Bottom padding
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
