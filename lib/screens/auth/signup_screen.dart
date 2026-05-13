import 'package:mindpilot/export.dart';

class Country {
  final String name;
  final String flag;
  final String dialCode;

  const Country({
    required this.name,
    required this.flag,
    required this.dialCode,
  });
}

const List<Country> countries = [
  Country(name: 'Uganda', flag: '🇺🇬', dialCode: '+256'),
  Country(name: 'Kenya', flag: '🇰🇪', dialCode: '+254'),
  Country(name: 'Nigeria', flag: '🇳🇬', dialCode: '+234'),
  Country(name: 'Ghana', flag: '🇬🇭', dialCode: '+233'),
  Country(name: 'South Africa', flag: '🇿🇦', dialCode: '+27'),
  Country(name: 'United States', flag: '🇺🇸', dialCode: '+1'),
  Country(name: 'United Kingdom', flag: '🇬🇧', dialCode: '+44'),
];

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  Country selectedCountry = countries[0];

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();

    return Scaffold(
      backgroundColor: theme.brandDark,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.4,
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  40.verticalSpace,
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(R.png.mindpilot.png, height: 30),
                        10.horizontalSpace,
                        PrimaryText(
                          text: 'Mind Pilot',
                          color: theme.accentTxt,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ],
                    ),
                  ),
                  40.verticalSpace,
                  PrimaryText(
                    text: 'Create Account',
                    color: theme.accentTxt,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  8.verticalSpace,
                  Row(
                    children: [
                      SecondaryText(
                        text: 'Already have an account?',
                        color: theme.accentTxt.withOpacity(0.7),
                      ),
                      8.horizontalSpace,
                      PrimaryText(
                        text: 'Sign in',
                        color: theme.primaryBase,
                        fontWeight: FontWeight.bold,
                      ).rippleClick(() {
                        context.pushOff(const LoginScreen());
                      }),
                    ],
                  ),
                  32.verticalSpace,
                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          context,
                          'First Name',
                          firstName,
                          Icons.person_outline,
                        ),
                      ),
                      16.horizontalSpace,
                      Expanded(
                        child: _buildField(
                          context,
                          'Last Name',
                          lastName,
                          Icons.person_outline,
                        ),
                      ),
                    ],
                  ),
                  20.verticalSpace,
                  _buildField(
                    context,
                    'Email address',
                    email,
                    Icons.email_outlined,
                  ),
                  20.verticalSpace,
                  _buildField(
                    context,
                    'Password',
                    password,
                    Icons.lock_outline,
                    isPassword: true,
                  ),
                  20.verticalSpace,
                  _buildField(
                    context,
                    'Confirm Password',
                    confirmPassword,
                    Icons.lock_outline,
                    isPassword: true,
                  ),
                  32.verticalSpace,
                  SecondaryText(
                    text:
                        'By signing up, you agree to our Terms of Service and Privacy Policy.',
                    color: theme.accentTxt.withOpacity(0.54),
                    fontSize: 12,
                  ),
                  24.verticalSpace,
                  CustomButton(
                    label: 'Create Account',
                    onPressed: () {},
                    // =>
                    //     context.pushOff(const PersonalizationScreen()),
                    backgroundColor: theme.primaryBase,
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

  Widget _buildField(
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
        SecondaryText(
          text: label,
          color: theme.accentTxt.withOpacity(0.7),
          fontSize: 13,
        ),
        8.verticalSpace,
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.accentTxt.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.accentTxt.withOpacity(0.1)),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            style: TextStyle(color: theme.accentTxt, fontSize: 14),
            decoration: InputDecoration(
              icon: Icon(
                icon,
                color: theme.accentTxt.withOpacity(0.54),
                size: 18,
              ),
              border: InputBorder.none,
              hintText: label,
              hintStyle: TextStyle(
                color: theme.accentTxt.withOpacity(0.24),
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class CountryPickerSheet extends StatefulWidget {
  final Function(Country) onSelect;

  const CountryPickerSheet({super.key, required this.onSelect});

  @override
  State<CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<CountryPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Country> _filteredCountries = countries;

  void _filterCountries(String query) {
    setState(() {
      _filteredCountries = countries
          .where(
            (country) =>
                country.name.toLowerCase().contains(query.toLowerCase()) ||
                country.dialCode.contains(query),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();

    return Column(
      children: [
        CustomTextField(
          textController: _searchController,
          hintText: 'Search country or dial code',
          autoFocus: true,
          textInputType: TextInputType.text,
          textInputAction: TextInputAction.search,
          prefixIcon: const Icon(Icons.search, size: 20),
          onChanged: (val) => _filterCountries(val ?? ''),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 400,
          child: ListView.separated(
            itemCount: _filteredCountries.length,
            separatorBuilder: (context, index) =>
                Divider(color: theme.dividerAndBorderColor, height: 1),
            itemBuilder: (context, index) {
              final country = _filteredCountries[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(
                  country.flag,
                  style: const TextStyle(fontSize: 24),
                ),
                title: PrimaryText(
                  text: country.name,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                trailing: PrimaryText(
                  text: country.dialCode,
                  fontSize: 14,
                  color: theme.secondaryTxt,
                ),
                onTap: () => widget.onSelect(country),
              );
            },
          ),
        ),
      ],
    );
  }
}
