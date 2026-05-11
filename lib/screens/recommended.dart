import 'package:mindpilot/export.dart';

class RecommendedGroupsScreen extends StatelessWidget {
  const RecommendedGroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: PrimaryText(
          text: R.S.exploreGroups,
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.notifications_outlined, color: Color(0xFF1170B2)),
                Positioned(
                  right: 0,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE9AD21),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('18', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                PrimaryText(
                  text: R.S.recommended,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                Row(
                  children: [
                    const Icon(Icons.filter_list, color: Colors.black54),
                    const SizedBox(width: 16),
                    const Icon(Icons.search, color: Colors.black54),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.55,
                ),
                itemCount: Mock.recommendedGroups().length,
                itemBuilder: (context, index) {
                  var group = Mock.recommendedGroups()[index];
                  return CustomContainer(
                    padding: EdgeInsets.zero,
                    borderRadius: 16,
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: Image.network(
                            group['image'],
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.verified, color: Color(0xFF1170B2), size: 16),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: PrimaryText(
                                      text: group['name'],
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      maxLines: 1,
                                      textOverflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SecondaryText(
                                text: group['description'],
                                fontSize: 12,
                                maxLines: 3,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  CustomContainer(
                                    width: 10,
                                    height: 10,
                                    padding: EdgeInsets.all(0),
                                    borderRadius: 50,
                                    color: Colors.green,
                                    border: Border.all(color: Colors.transparent),
                                    child: const SizedBox.shrink(),
                                  ),
                                  const SizedBox(width: 8),
                                  SecondaryText(
                                    text: '${group['online']} Members online',
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.people_outline, color: Colors.grey.shade500, size: 14),
                                  const SizedBox(width: 8),
                                  SecondaryText(
                                    text: '${group['members']} Members',
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 32,
                                child: OutlinedButton(
                                  onPressed: () {},
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFF1170B2)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: const Text('Join', style: TextStyle(color: Color(0xFF1170B2), fontSize: 12, fontWeight: FontWeight.bold)),
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
          ],
        ),
      ),
    );
  }
}
