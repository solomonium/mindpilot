import 'package:mindpilot/export.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with FormMixin {
  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();

    return Scaffold(
      backgroundColor: theme.background,
      resizeToAvoidBottomInset: true,
      body: Consumer<HomeProvider>(
        builder: (context, home, _) {
          return Form(
            key: formKey,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [],
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
