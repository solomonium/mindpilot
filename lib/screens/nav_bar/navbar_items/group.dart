// ignore_for_file: must_be_immutable

import 'package:mindpilot/export.dart';
import 'package:mindpilot/screens/recommended.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<GroupScreen> with FormMixin {
  int _selectedCategoryIndex = 0;

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
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        // Toolbar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            PrimaryText(
                              text: R.S.groups,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: theme.foundationColor,
                            ),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                const Icon(
                                  Icons.notifications_outlined,
                                  color: Color(0xFF1170B2),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 10,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE9AD21),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const PrimaryText(
                                      text: '18',
                                      color: Colors.white,
                                      fontSize: 8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        24.verticalSpace,

                        CustomContainer(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          borderRadius: 8,
                          color: theme.searchFillColor,
                          border: Border.all(color: Colors.transparent),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.search,
                                color: Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              SecondaryText(
                                text: R.S.exploreCrowdfunds,
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ],
                          ),
                        ),
                        20.verticalSpace,

                        SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: Mock.groupCategories().length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              bool isSelected = _selectedCategoryIndex == index;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedCategoryIndex = index),
                                child: CustomContainer(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  alignment: Alignment.center,
                                  borderRadius: 12,
                                  color: isSelected
                                      ? theme.primaryBase
                                      : theme.searchFillColor,
                                  border: Border.all(color: Colors.transparent),
                                  child: PrimaryText(
                                    text: Mock.groupCategories()[index],
                                    color: isSelected
                                        ? theme.whiteBackground
                                        : theme.foundationColor,
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 32),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            PrimaryText(
                              text: R.S.recommended,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            PrimaryText(
                              text: R.S.viewAll,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1170B2),
                            ).rippleClick(() {
                              context.push(const RecommendedGroupsScreen());
                            }),
                          ],
                        ),
                        16.verticalSpace,

                        SizedBox(
                          height: 260,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: Mock.recommendedGroups().length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 16),
                            itemBuilder: (context, index) {
                              var group = Mock.recommendedGroups()[index];
                              return CustomContainer(
                                width: 180,
                                padding: EdgeInsets.zero,
                                borderRadius: 16,
                                color: Colors.white,
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(16),
                                      ),
                                      child: Image.network(
                                        group['image'],
                                        height: 80,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.verified,
                                                color: Color(0xFF1170B2),
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: PrimaryText(
                                                  text: group['name'],
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  maxLines: 1,
                                                  textOverflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          SecondaryText(
                                            text: group['description'],
                                            fontSize: 12,
                                            maxLines: 2,
                                            color: Colors.grey.shade600,
                                            textOverflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              CustomContainer(
                                                width: 10,
                                                height: 10,
                                                padding: EdgeInsets.zero,
                                                borderRadius: 50,
                                                color: Colors.green,
                                                border: Border.all(color: Colors.transparent),
                                                child: const SizedBox.shrink(),
                                              ),
                                              const SizedBox(width: 8),
                                              SecondaryText(
                                                text:
                                                    '${group['online']} Members online',
                                                fontSize: 10,
                                                color: Colors.grey.shade600,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.people_outline,
                                                color: Colors.grey.shade500,
                                                size: 14,
                                              ),
                                              const SizedBox(width: 8),
                                              SecondaryText(
                                                text:
                                                    '${group['members']} Members',
                                                fontSize: 10,
                                                color: Colors.grey.shade600,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 32,
                                            child: OutlinedButton(
                                              onPressed: () {},
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(
                                                  color: Color(0xFF1170B2),
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                padding: EdgeInsets.zero,
                                              ),
                                              child: Text(
                                                R.S.join,
                                                style: const TextStyle(
                                                  color: Color(0xFF1170B2),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 32),

                        // My Groups
                        PrimaryText(
                          text: R.S.myGroups,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        const SizedBox(height: 16),
                        ...List.generate(Mock.myGroups().length, (index) {
                          var g = Mock.myGroups()[index];
                          return CustomContainer(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        PrimaryText(
                                          text: g['name'],
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                        const SizedBox(width: 8),
                                        if (g['count'] != null)
                                          CustomContainer(
                                            padding: const EdgeInsets.all(6),
                                            borderRadius: 50,
                                            color: const Color(0xFFE9AD21),
                                            border: Border.all(color: Colors.transparent),
                                            child: Text(
                                              g['count'].toString(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 14,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                CustomContainer(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  borderRadius: 8,
                                  color: g['type'] == 'Savings Group'
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.blue.withOpacity(0.1),
                                  border: Border.all(color: Colors.transparent),
                                  child: PrimaryText(
                                    text: g['type'],
                                    color: g['type'] == 'Savings Group'
                                        ? Colors.green
                                        : Colors.blue,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.people_outline,
                                          color: Colors.grey,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        SecondaryText(
                                          text: g['members'],
                                          fontSize: 12,
                                        ),
                                      ],
                                    ),
                                    SecondaryText(
                                      text: 'Balance: ${g['balance']}',
                                      fontSize: 14,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 100),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF1170B2),
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
    );
  }
}
