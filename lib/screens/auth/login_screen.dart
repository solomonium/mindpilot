import 'package:mindpilot/export.dart';
import 'package:mindpilot/screens/auth/signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with FormMixin {
  final email = TextEditingController();
  final password = TextEditingController();
  bool passwordVisible = false;
  bool obscurePassword = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                87.verticalSpace,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SvgPicture.asset(R.png.twezi.svg, height: 50),
                    8.verticalSpace,
                    SecondaryText(
                      text: R.S.welcomeSignIn,
                      color: theme.secondaryTxt,
                    ),
                  ],
                ),
                55.verticalSpace,
                CustomTextField(
                  textInputType: TextInputType.emailAddress,
                  labelText: R.S.email,
                  textController: email,
                  hintText: R.S.invalidEmail,
                  autoFocus: false,
                  validate: Validator.email,
                  textInputAction: TextInputAction.next,
                  onChanged: (newValue) {},
                ),
                24.verticalSpace,
                CustomTextField(
                  isPassword: true,
                  textInputType: TextInputType.visiblePassword,
                  labelText: R.S.password,
                  hintText: R.S.enterPwd,
                  textController: password,
                  suffixIcon: GestureDetector(
                    onTap: () => setState(() {
                      obscurePassword = !obscurePassword;
                    }),
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: 15,
                        left: 0,
                        right: 17,
                        bottom: 10,
                      ),
                      child: Icon(
                        obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: theme.secondaryTxt,
                      ),
                    ),
                  ),
                  obscure: !obscurePassword,
                  autoFocus: false,
                  // validate: Validator.password(minLength: 8),
                  validate: (String? value) {
                    if (value!.isEmpty) {
                      return "Password is required";
                    }
                    if (value.length < 8) {
                      return "Password must be at least ${8} characters";
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.done,
                ),
                40.verticalSpace,
                Align(
                  alignment: Alignment.centerRight,
                  child: PrimaryText(
                    text: 'Forgot Password?',
                    color: theme.primaryBase,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ).rippleClick(() {}),
                ),
                CustomButton(
                  label: R.S.login,
                  onPressed: () {
                    validate(() {
                      context.push(MainScreen());
                    });
                  },
                ),
                40.verticalSpace,
                Row(
                  children: [
                    Expanded(
                      child: Divider(color: theme.dividerAndBorderColor),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SecondaryText(
                        text: 'or sign in with',
                        color: theme.secondaryTxt,
                        fontSize: 13,
                      ),
                    ),
                    Expanded(
                      child: Divider(color: theme.dividerAndBorderColor),
                    ),
                  ],
                ),
                30.verticalSpace,
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _socialButton(R.png.google.imgPng, () {}),
                    20.horizontalSpace,
                    _socialButton(R.png.facebook.svg, () {}),
                  ],
                ),
                40.verticalSpace,
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SecondaryText(
                      text: R.S.dontHaveAcct,
                      color: theme.secondaryTxt,
                      fontSize: 15,
                    ),
                    PrimaryText(
                      text: R.S.signUp,
                      color: theme.primaryBase,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    SecondaryText(
                      text: "now",
                      color: theme.secondaryTxt,
                      fontSize: 15,
                    ),
                  ],
                ).rippleClick(() {
                  context.pushOff(const SignupScreen());
                }),
                40.verticalSpace,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _socialButton(String assetPath, VoidCallback onTap) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: assetPath.endsWith('.svg')
          ? SvgPicture.asset(assetPath, width: 38, height: 38)
          : Image.asset(assetPath, width: 38, height: 38),
    ).rippleClick(onTap);
  }
}
