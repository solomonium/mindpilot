import 'package:mindpilot/export.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/country_picker_dialog.dart';

class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  late TextEditingController _phoneController;
  late TextEditingController _nameController;
  bool _isEditingPhone = false;
  bool _isEditingName = false;
  bool _isSaving = false;

  String _selectedCountryName = 'Nigeria';
  String _selectedDialCode = '+234';
  String _initialCountryCode = 'NG';

  @override
  void initState() {
    super.initState();
    final auth = context.read<AppAuthProvider>();
    final user = auth.user;

    final email = auth.email ?? user?.email;
    final emailPrefix = (email != null && email.contains('@'))
        ? (email.contains('privaterelay.appleid.com')
              ? 'User'
              : email.split('@').first.capitalize())
        : 'User';

    String displayNameToUse = 'User';
    if (auth.displayName != null && auth.displayName!.trim().isNotEmpty) {
      displayNameToUse = auth.displayName!;
    } else if (user?.displayName != null &&
        user!.displayName!.trim().isNotEmpty) {
      displayNameToUse = user.displayName!;
    } else if (emailPrefix.trim().isNotEmpty) {
      displayNameToUse = emailPrefix;
    }

    _nameController = TextEditingController(text: displayNameToUse);

    String rawPhone = auth.phoneNumber ?? '';
    _phoneController = TextEditingController();

    // Attempt to extract country code and dial code if they exist
    if (rawPhone.isNotEmpty) {
      if (rawPhone.startsWith('+234')) {
        _selectedDialCode = '+234';
        _initialCountryCode = 'NG';
        _selectedCountryName = 'Nigeria';
        _phoneController.text = rawPhone.substring(4);
      } else if (rawPhone.startsWith('+256')) {
        _selectedDialCode = '+256';
        _initialCountryCode = 'UG';
        _selectedCountryName = 'Uganda';
        _phoneController.text = rawPhone.substring(4);
      } else if (rawPhone.startsWith('+254')) {
        _selectedDialCode = '+254';
        _initialCountryCode = 'KE';
        _selectedCountryName = 'Kenya';
        _phoneController.text = rawPhone.substring(4);
      } else if (rawPhone.startsWith('+233')) {
        _selectedDialCode = '+233';
        _initialCountryCode = 'GH';
        _selectedCountryName = 'Ghana';
        _phoneController.text = rawPhone.substring(4);
      } else if (rawPhone.startsWith('+27')) {
        _selectedDialCode = '+27';
        _initialCountryCode = 'ZA';
        _selectedCountryName = 'South Africa';
        _phoneController.text = rawPhone.substring(3);
      } else if (rawPhone.startsWith('+1')) {
        _selectedDialCode = '+1';
        _initialCountryCode = 'US';
        _selectedCountryName = 'United States';
        _phoneController.text = rawPhone.substring(2);
      } else if (rawPhone.startsWith('+44')) {
        _selectedDialCode = '+44';
        _initialCountryCode = 'GB';
        _selectedCountryName = 'United Kingdom';
        _phoneController.text = rawPhone.substring(3);
      } else {
        _phoneController.text = rawPhone;
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    try {
      String cleanPhone = _phoneController.text.trim();
      if (cleanPhone.startsWith('0')) {
        cleanPhone = cleanPhone.substring(1);
      }

      String completePhone = cleanPhone.isEmpty
          ? ''
          : '$_selectedDialCode$cleanPhone';

      await context.read<AppAuthProvider>().updateUserProfile(
        displayName: _nameController.text.trim(),
        phoneNumber: completePhone,
        country: _selectedCountryName,
      );
      if (mounted) {
        context.showInAppNotification(
          'Profile updated successfully!',
          type: InAppNotificationType.success,
        );
        setState(() {
          _isEditingPhone = false;
          _isEditingName = false;
        });
      }
    } catch (e) {
      if (mounted) context.showInAppNotification('Error: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    final auth = context.watch<AppAuthProvider>();
    final user = auth.user;

    final email = auth.email ?? user?.email;
    final emailPrefix = (email != null && email.contains('@'))
        ? (email.contains('privaterelay.appleid.com')
              ? 'User'
              : email.split('@').first.capitalize())
        : 'User';

    String displayNameToUse = 'User';
    if (auth.displayName != null && auth.displayName!.trim().isNotEmpty) {
      displayNameToUse = auth.displayName!;
    } else if (user?.displayName != null &&
        user!.displayName!.trim().isNotEmpty) {
      displayNameToUse = user.displayName!;
    } else if (emailPrefix.trim().isNotEmpty) {
      displayNameToUse = emailPrefix;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: PrimaryText(
          text: 'Personal Information',
          color: theme.accentTxt,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        leading: Icon(
          Icons.arrow_back_ios,
          color: theme.accentTxt,
        ).clickable(() => context.pop()),
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
                    theme.brandDark.withValues(alpha: 0.4),
                    theme.brandDark.withValues(alpha: 0.8),
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
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.accentTxt.withValues(alpha: 0.1),
                      image: user?.photoURL != null
                          ? DecorationImage(
                              image: NetworkImage(user!.photoURL!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: user?.photoURL == null
                        ? Center(
                            child: displayNameToUse.getInitials().isNotEmpty
                                ? PrimaryText(
                                    text: displayNameToUse.getInitials(),
                                    color: theme.accentTxt,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  )
                                : Icon(
                                    Icons.person,
                                    color: theme.accentTxt,
                                    size: 40,
                                  ),
                          )
                        : null,
                  ),
                ),
                32.verticalSpace,
                _editableInfoTile(
                  context,
                  'Full Name',
                  _nameController,
                  isEditing: _isEditingName,
                  onEditTap: () =>
                      setState(() => _isEditingName = !_isEditingName),
                ),
                _infoTile(
                  context,
                  'Email Address',
                  (auth.email != null && auth.email!.trim().isNotEmpty)
                      ? auth.email!
                      : (user?.email ?? 'user@example.com'),
                  isEditable: false,
                ),
                _editableInfoTile(
                  context,
                  'Phone Number',
                  _phoneController,
                  isEditing: _isEditingPhone,
                  onEditTap: () =>
                      setState(() => _isEditingPhone = !_isEditingPhone),
                ),

                32.verticalSpace,
                CustomButton(
                  label: 'Save Changes',
                  loading: _isSaving,
                  onPressed: _saveChanges,
                  fullWidth: true,
                  isGlass: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(
    BuildContext context,
    String label,
    String value, {
    bool isEditable = true,
  }) {
    AppTheme theme = context.watch();
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      gradient: theme.glassGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SecondaryText(
            text: label,
            fontSize: 12,
            color: theme.accentTxt.withValues(alpha: 0.7),
          ),
          8.verticalSpace,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PrimaryText(
                text: value,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.accentTxt,
              ),
              if (isEditable)
                Icon(Icons.edit_outlined, color: theme.accentTxt, size: 18),
            ],
          ),
        ],
      ),
    );
  }

  Widget _editableInfoTile(
    BuildContext context,
    String label,
    TextEditingController controller, {
    required bool isEditing,
    required VoidCallback onEditTap,
  }) {
    AppTheme theme = context.watch();
    final isPhone = label.toLowerCase().contains('phone');
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      gradient: theme.glassGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SecondaryText(
            text: label,
            fontSize: 12,
            color: theme.accentTxt.withValues(alpha: 0.7),
          ),
          8.verticalSpace,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: isEditing
                    ? (isPhone
                          ? IntlPhoneField(
                              controller: controller,
                              initialCountryCode: _initialCountryCode,
                              dropdownTextStyle: TextStyle(
                                color: theme.accentTxt,
                              ),
                              dropdownIcon: Icon(
                                Icons.arrow_drop_down,
                                color: theme.accentTxt,
                              ),
                              style: GoogleFonts.inter(
                                color: theme.accentTxt,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              pickerDialogStyle: PickerDialogStyle(
                                backgroundColor: theme.brandDark,
                                countryCodeStyle: GoogleFonts.inter(
                                  color: theme.accentTxt,
                                  fontSize: 14,
                                ),
                                countryNameStyle: GoogleFonts.inter(
                                  color: theme.accentTxt,
                                  fontSize: 14,
                                ),
                                searchFieldInputDecoration: InputDecoration(
                                  labelText: 'Search Country',
                                  labelStyle: TextStyle(
                                    color: theme.accentTxt.withValues(
                                      alpha: 0.54,
                                    ),
                                  ),
                                  hintText: 'Search Country',
                                  hintStyle: TextStyle(
                                    color: theme.accentTxt.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: theme.accentTxt.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: theme.primaryBase,
                                    ),
                                  ),
                                ),
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter $label',
                                hintStyle: TextStyle(
                                  color: theme.accentTxt.withValues(alpha: 0.3),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onCountryChanged: (country) {
                                _selectedDialCode = '+${country.dialCode}';
                                _selectedCountryName = country.name;
                                _initialCountryCode = country.code;
                              },
                            )
                          : TextField(
                              controller: controller,
                              autofocus: true,
                              style: GoogleFonts.inter(
                                color: theme.accentTxt,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter $label',
                                hintStyle: TextStyle(
                                  color: theme.accentTxt.withValues(alpha: 0.3),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ))
                    : PrimaryText(
                        text: controller.text.isEmpty
                            ? 'Not set'
                            : (isPhone
                                  ? '$_selectedDialCode${controller.text}'
                                  : controller.text),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.accentTxt,
                      ),
              ),
              Icon(
                isEditing ? Icons.check_circle_outline : Icons.edit_outlined,
                color: isEditing ? theme.primaryBase : theme.accentTxt,
                size: 20,
              ).rippleClick(onEditTap),
            ],
          ),
        ],
      ),
    );
  }
}
