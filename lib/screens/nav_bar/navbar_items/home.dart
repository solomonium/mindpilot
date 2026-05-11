import 'package:mindpilot/export.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CustomContainer(
                    padding: EdgeInsets.zero,
                    borderRadius: 50,
                    border: Border.all(
                      color: theme.primaryBase.withOpacity(0.1),
                      width: 2,
                    ),
                    child: const CircleAvatar(
                      radius: 24,
                      backgroundColor: Color(0xFFF1F5F9),
                      child: Icon(Icons.person, color: Color(0xFF64748B)),
                    ),
                  ),
                  14.horizontalSpace,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SecondaryText(text: R.S.helloBeatrice, fontSize: 13),
                      PrimaryText(
                        text: R.S.pendingActions,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.secondaryTxt,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Stack(
                    children: [
                      CustomContainer(
                        padding: EdgeInsets.all(8),
                        borderRadius: 50,
                        color: theme.primaryBase,
                        border: Border.all(color: Colors.transparent),
                        child: Icon(
                          Icons.notifications_outlined,
                          size: 24,
                          color: theme.background,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: theme.background,
                            shape: BoxShape.circle,
                          ),
                          child: PrimaryText(
                            text: '18',
                            color: theme.warningBase,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              25.verticalSpace,

              CustomContainer(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SecondaryText(
                          text: R.S.totalWalletBalance,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                        10.horizontalSpace,
                        Icon(
                          Icons.remove_red_eye_rounded,
                          size: 16,
                          color: theme.caption,
                        ),
                      ],
                    ),
                    PrimaryText(
                      text: R.S.ugxBalance,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    24.verticalSpace,
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            label: R.S.deposit,
                            onPressed: () {},
                            backgroundColor: Colors.white,
                            textColor: theme.primaryBase,
                            borderColor: theme.primaryBase,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomButton(
                            label: R.S.withdraw,
                            onPressed: () {},
                            backgroundColor: theme.primaryBase,
                            textColor: Colors.white,
                            borderColor: theme.primaryBase,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              32.verticalSpace,

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: Mock.quickActions(context).map((action) {
                  return Expanded(
                    child: _quickAction(
                      action['icon'],
                      action['label'],
                      action['bgColor'],
                      action['iconColor'],
                      onTap: () {
                        if (action['label'] == R.S.contribute) {
                          showContributeSheet(context);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
              32.verticalSpace,

              PrimaryText(
                text: R.S.urgentActions,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.foundationColorBlack,
              ),
              20.verticalSpace,
              ...Mock.urgentActions(context).map(
                (action) => _urgentActionCard(
                  theme,
                  action['title'],
                  action['subtitle'],
                  action['amount'],
                  action['status'],
                  statusColor: action['statusColor'],
                ),
              ),

              32.verticalSpace,

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  PrimaryText(
                    text: R.S.myGroups,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.foundationColorBlack,
                  ),
                  PrimaryText(
                    text: R.S.viewAll,
                    color: theme.primaryBase,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ).rippleClick(() {}),
                ],
              ),
              const SizedBox(height: 16),
              ...Mock.myGroups().map(
                (group) => _groupCard(
                  group['name'],
                  group['type'],
                  group['members'],
                  group['balance'],
                  count: group['count'],
                ),
              ),
              32.verticalSpace,

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  PrimaryText(
                    text: R.S.recentActivity,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.foundationColorBlack,
                  ),
                  PrimaryText(
                    text: R.S.seeAll,
                    color: theme.primaryBase,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ).rippleClick(() {}),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickAction(
    String svgAsset,
    String label,
    Color bgColor,
    Color iconColor, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CustomContainer(
            height: 60,
            width: 60,
            padding: const EdgeInsets.all(16),
            borderRadius: 10,
            color: bgColor,
            border: Border.all(color: Colors.transparent),
            child: SvgPicture.asset(
              svgAsset,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              width: 24,
              height: 24,
            ),
          ),
          10.verticalSpace,
          SecondaryText(
            text: label,
            textAlign: TextAlign.center,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ],
      ),
    );
  }

  Widget _urgentActionCard(
    AppTheme theme,
    String title,
    String subtitle,
    String amount,
    String status, {
    Color? statusColor,
  }) {
    return CustomContainer(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(20),
      child: Column(
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
                      text: title,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: theme.foundationColorBlack,
                    ),
                    4.verticalSpace,
                    SecondaryText(text: subtitle, fontSize: 13),
                  ],
                ),
              ),
              PrimaryText(
                text: amount,
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: theme.secondaryTxt,
              ),
            ],
          ),
          16.verticalSpace,
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 16,
                color: theme.secondaryTxt, //statusColor ?? theme.secondaryTxt,
              ),
              const SizedBox(width: 6),
              SecondaryText(
                text: status,
                color: theme.secondaryTxt, //statusColor ?? theme.secondaryTxt,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ],
          ),
          16.verticalSpace,
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              label: R.S.takeAction,
              onPressed: () {},
              backgroundColor: theme.primaryBase,
              textColor: theme.whiteBackground,
              padding: const EdgeInsets.symmetric(vertical: 14),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupCard(
    String name,
    String type,
    String members,
    String balance, {
    int? count,
  }) {
    return CustomContainer(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PrimaryText(
                      text: name,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: const Color(0xFF1E293B),
                    ),
                    if (count != null) ...[
                      8.horizontalSpace,
                      CustomContainer(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        borderRadius: 10,
                        color: const Color(0xFFF59E0B),
                        border: Border.all(color: Colors.transparent),
                        child: PrimaryText(
                          text: count.toString(),
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
                19.verticalSpace,
                CustomContainer(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  borderRadius: 8,
                  color: const Color(0xFFEFF6FF),
                  border: Border.all(color: Colors.transparent),
                  child: PrimaryText(
                    text: type,
                    color: const Color(0xFF3B82F6),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                12.verticalSpace,
                Row(
                  // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.group_rounded,
                          size: 16,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 6),
                        SecondaryText(
                          text: members,
                          color: const Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ],
                    ),
                    Spacer(),
                    PrimaryText(
                      text: R.S.balanceText,
                      // color: const Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                    5.horizontalSpace,
                    PrimaryText(
                      text: balance,
                      // color: const Color(0xFF1E293B),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ],
                ),
              ],
            ),
          ),
          12.horizontalSpace,
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
        ],
      ),
    );
  }
}
