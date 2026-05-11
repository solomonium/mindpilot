import 'package:mindpilot/export.dart';

class PersonalInformationScreen extends StatelessWidget {
  const PersonalInformationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: PrimaryText(text: 'Personal Information', color: theme.accentTxt, fontSize: 18, fontWeight: FontWeight.bold),
        leading: Icon(Icons.arrow_back_ios, color: theme.accentTxt).clickable(() => context.pop()),
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
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.accentTxt.withOpacity(0.1),
                          image: user?.photoURL != null 
                            ? DecorationImage(image: NetworkImage(user!.photoURL!), fit: BoxFit.cover)
                            : null,
                        ),
                        child: user?.photoURL == null 
                          ? Center(child: Icon(Icons.person, color: theme.accentTxt, size: 40)) 
                          : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: theme.primaryBase, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                32.verticalSpace,
                _infoTile(context, 'Full Name', user?.displayName ?? 'User Name'),
                _infoTile(context, 'Email Address', user?.email ?? 'user@example.com'),
                _infoTile(context, 'Phone Number', user?.phoneNumber ?? 'Not set'),
                _infoTile(context, 'Location', 'Not set'),
                32.verticalSpace,
                CustomButton(
                  label: 'Save Changes',
                  onPressed: () => context.pop(),
                  fullWidth: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(BuildContext context, String label, String value) {
    AppTheme theme = context.watch();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: theme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: theme.primaryBase.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SecondaryText(text: label, fontSize: 12, color: theme.accentTxt.withOpacity(0.7)),
          8.verticalSpace,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PrimaryText(text: value, fontSize: 15, fontWeight: FontWeight.w600, color: theme.accentTxt),
              Icon(Icons.edit_outlined, color: theme.accentTxt, size: 18),
            ],
          ),
        ],
      ),
    );
  }
}
