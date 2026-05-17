import 'package:mindpilot/export.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with FormMixin {
  final email = TextEditingController();
  final password = TextEditingController();
  bool rememberMe = false;

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    bool isLoading = context.watch<AppAuthProvider>().isLoading;

    return LoadingOverlay(
      isLoading: isLoading,
      child: Scaffold(
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
                      Colors.transparent,
                      theme.brandDark.withOpacity(0.8),
                      theme.brandDark,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      60.verticalSpace,
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(R.png.mindpilotApp.png, height: 100),
                            10.horizontalSpace,
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                PrimaryText(
                                  text: 'MindPilot',
                                  color: theme.accentTxt,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                SecondaryText(
                                  text: 'Think clearly. Live intentionally.',
                                  color: theme.accentTxt.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      30.verticalSpace,
                      PrimaryText(
                        text: 'Welcome Back',
                        color: theme.accentTxt,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      8.verticalSpace,
                      SecondaryText(
                        text: 'Sign in to continue your journey',
                        color: theme.accentTxt.withOpacity(0.7),
                      ),
                      40.verticalSpace,
                      _socialButton(
                        context,
                        label: 'Google',
                        icon: R.png.google.imgPng,
                        onPressed: () => context
                            .read<AppAuthProvider>()
                            .loginWithGoogle(context),
                      ),
                      16.verticalSpace,
                      _socialButton(
                        context,
                        label: 'Facebook',
                        icon: R.png.facebook.svg,
                        isSvg: true,
                        onPressed: () {
                          context.showInAppNotification(
                            'Facebook login is coming soon!',
                            type: InAppNotificationType.info,
                          );
                        },
                      ),
                      16.verticalSpace,
                      _socialButton(
                        context,
                        label: 'Apple',
                        icon: Icons.apple,
                        onPressed: () {
                          context.showInAppNotification(
                            'Apple login is coming soon!',
                            type: InAppNotificationType.info,
                          );
                        },
                      ),
                      32.verticalSpace,
                      /*
                      Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _showEmailLogin,
                              onChanged: (v) =>
                                  setState(() => _showEmailLogin = v!),
                              side: const BorderSide(color: Colors.white54),
                              activeColor: theme.primaryBase,
                            ),
                          ),
                          8.horizontalSpace,
                          SecondaryText(
                            text: 'Login with Email/Password',
                            color: theme.accentTxt.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ],
                      ),
                      if (_showEmailLogin) ...[
                        32.verticalSpace,
                        _buildTextField(
                          context,
                          'Email address',
                          email,
                          Icons.email_outlined,
                        ),
                        20.verticalSpace,
                        _buildTextField(
                          context,
                          'Password',
                          password,
                          Icons.lock_outline,
                          isPassword: true,
                        ),
                        16.verticalSpace,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: rememberMe,
                                    onChanged: (v) =>
                                        setState(() => rememberMe = v!),
                                    side: BorderSide(
                                      color: theme.accentTxt.withOpacity(0.54),
                                    ),
                                    activeColor: theme.primaryBase,
                                  ),
                                ),
                                8.horizontalSpace,
                                SecondaryText(
                                  text: 'Remember me',
                                  color: theme.accentTxt.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                              ],
                            ),
                            SecondaryText(
                              text: 'Forgot password?',
                              color: theme.accentTxt.withOpacity(0.7),
                              fontSize: 14,
                            ).rippleClick(() {}),
                          ],
                        ),
                        32.verticalSpace,
                        CustomButton(
                          label: 'Sign In',
                          onPressed: () =>
                              context.read<AppAuthProvider>().loginWithEmail(
                                context,
                                email.text,
                                password.text,
                              ),
                          backgroundColor: theme.primaryBase,
                          loading: context.watch<AppAuthProvider>().isLoading,
                        ),
                      ],
                      40.verticalSpace,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SecondaryText(
                            text: "Don't have an account?",
                            color: Colors.white70,
                          ),
                          8.horizontalSpace,
                          PrimaryText(
                            text: R.S.signUp,
                            color: theme.primaryBase,
                            fontWeight: FontWeight.bold,
                          ).rippleClick(() {
                            // context.pushOff(const SignupScreen());
                          }),
                        ],
                      ),
                      */
                      100.verticalSpace, // Extra space to prevent overlap with fixed footer
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Column(
                  children: [
                    SecondaryText(
                      text: 'Developed by SolteQ Innovations Ltd',
                      color: theme.accentTxt.withOpacity(0.5),
                      fontSize: 11,
                    ),
                    4.verticalSpace,
                    SecondaryText(
                      text: 'Version ${ConfigService().currentAppVersion}',
                      color: theme.accentTxt.withOpacity(0.3),
                      fontSize: 10,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTextField(
    BuildContext context,
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isPassword = false,
  }) {
    AppTheme theme = context.watch();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: theme.accentTxt.withOpacity(0.54), size: 20),
            10.horizontalSpace,
            SecondaryText(
              text: label,
              color: theme.accentTxt.withOpacity(0.7),
              fontSize: 14,
            ),
          ],
        ),
        8.verticalSpace,
        Container(
          decoration: BoxDecoration(
            color: theme.accentTxt.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.accentTxt.withOpacity(0.1)),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            style: TextStyle(color: theme.accentTxt),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: InputBorder.none,
              hintText: 'Enter your $label',
              hintStyle: TextStyle(
                color: theme.accentTxt.withOpacity(0.3),
                fontSize: 14,
              ),
              suffixIcon: isPassword
                  ? Icon(
                      Icons.visibility_outlined,
                      color: theme.accentTxt.withOpacity(0.54),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _socialButton(
    BuildContext context, {
    required String label,
    required dynamic icon,
    bool isSvg = false,
    VoidCallback? onPressed,
  }) {
    AppTheme theme = context.watch();
    return CustomButton(
      fontSize: 16,
      label: 'Continue with $label',
      onPressed: onPressed,
      fullWidth: true,
      isOutline: true,
      borderColor: theme.accentTxt.withOpacity(0.1),
      backgroundColor: theme.accentTxt.withOpacity(0.05),
      textColor: theme.accentTxt,
      prefixIcon: icon is IconData
          ? Icon(icon, color: theme.accentTxt, size: 20)
          : isSvg
          ? SvgPicture.asset(icon, width: 20, height: 20)
          : Image.asset(icon, width: 20, height: 20),
    );
  }
}
