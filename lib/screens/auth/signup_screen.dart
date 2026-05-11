import 'package:mindpilot/export.dart';

class Country {
  final String name;
  final String flag;
  final String dialCode;

  const Country({required this.name, required this.flag, required this.dialCode});
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

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  Country _selectedCountry = countries[0];

  void _showCountryPicker() {
    CustomBottomSheet.show(
      context,
      title: 'Select Country',
      pages: [
        CountryPickerSheet(
          onSelect: (country) {
            setState(() => _selectedCountry = country);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    firstName.dispose();
    lastName.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              12.verticalSpace,
              Center(child: SvgPicture.asset(R.png.twezi.svg, height: 40)),
              20.verticalSpace,
              PrimaryText(
                text: R.S.createAccount,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.foundationColor,
              ),
              4.verticalSpace,
              Row(
                children: [
                  SecondaryText(
                    text: R.S.alreadyHaveAcct,
                    color: theme.secondaryTxt,
                    fontSize: 14,
                  ),
                  PrimaryText(
                    text: "Sign In",
                    color: theme.primaryBase,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ).rippleClick(() => context.pushOff(const LoginScreen())),
                ],
              ),
              24.verticalSpace,
              CustomTextField(
                labelText: R.S.firstName,
                textController: firstName,
                hintText: R.S.enterFirstName,
                textInputType: TextInputType.name,
                textInputAction: TextInputAction.done,
                autoFocus: false,
              ),
              16.verticalSpace,
              CustomTextField(
                labelText: R.S.lastName,
                textController: lastName,
                hintText: R.S.enterLastName,
                textInputType: TextInputType.name,
                textInputAction: TextInputAction.done,
                autoFocus: false,
              ),
              16.verticalSpace,
              CustomTextField(
                labelText: R.S.email,
                textInputType: TextInputType.emailAddress,
                textController: email,
                hintText: 'example@gmail.com',
                textInputAction: TextInputAction.done,
                autoFocus: false,
              ),
              16.verticalSpace,
              CustomTextField(
                labelText: R.S.phoneNumber,
                textInputType: TextInputType.phone,
                textController: phone,
                hintText: R.S.enterPhoneNumber,
                textInputAction: TextInputAction.done,
                autoFocus: false,
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomDropdown<Country>(
                        items: countries,
                        value: _selectedCountry,
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCountry = val);
                        },
                        onTap: _showCountryPicker,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_selectedCountry.flag, style: const TextStyle(fontSize: 20)),
                            const Icon(Icons.arrow_drop_down, color: Colors.grey),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 1,
                        height: 24,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
              ),
              16.verticalSpace,
              CustomTextField(
                labelText: R.S.createPasswordLbl,
                isPassword: true,
                textController: password,
                hintText: R.S.enterCreatePassword,
                obscure: _obscurePassword,
                autoFocus: false,
                textInputAction: TextInputAction.done,
                textInputType: TextInputType.name,

                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              16.verticalSpace,
              CustomTextField(
                labelText: R.S.confirmPassword,
                isPassword: true,
                textController: confirmPassword,
                autoFocus: false,
                hintText: R.S.enterConfirmPassword,
                obscure: _obscureConfirmPassword,
                textInputType: TextInputType.name,
                textInputAction: TextInputAction.done,

                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
                ),
              ),
              20.verticalSpace,
              SecondaryText(
                text: R.S.termsAndPrivacy,
                fontSize: 12,
                color: theme.foundationColor,
                maxLines: 3,
                textAlign: TextAlign.start,
              ),
              20.verticalSpace,
              CustomButton(
                label: R.S.createAccount,
                onPressed: () => context.pushOff(const MainScreen()),
              ),
              40.verticalSpace,
            ],
          ),
        ),
      ),
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
          .where((country) =>
              country.name.toLowerCase().contains(query.toLowerCase()) ||
              country.dialCode.contains(query))
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
            separatorBuilder: (context, index) => Divider(color: theme.dividerAndBorderColor, height: 1),
            itemBuilder: (context, index) {
              final country = _filteredCountries[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(country.flag, style: const TextStyle(fontSize: 24)),
                title: PrimaryText(text: country.name, fontSize: 14, fontWeight: FontWeight.w600),
                trailing: PrimaryText(text: country.dialCode, fontSize: 14, color: theme.secondaryTxt),
                onTap: () => widget.onSelect(country),
              );
            },
          ),
        ),
      ],
    );
  }
}
