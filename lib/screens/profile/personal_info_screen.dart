import 'package:mindpilot/export.dart';
import 'package:flutter/services.dart';

class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  State<PersonalInformationScreen> createState() => _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  late TextEditingController _phoneController;
  late TextEditingController _locationController;
  bool _isEditingPhone = false;
  bool _isFetchingLocation = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AppAuthProvider>();
    _phoneController = TextEditingController(text: auth.phoneNumber ?? '');
    _locationController = TextEditingController(text: auth.location ?? '');
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      final location = await LocationService.getCurrentLocation();
      if (location != null) {
        setState(() => _locationController.text = location);
        context.showInAppNotification('Location updated!', type: InAppNotificationType.success);
      }
    } catch (e) {
      context.showInAppNotification(e.toString());
    } finally {
      setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _saveChanges() async {
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    try {
      await context.read<AppAuthProvider>().updateUserProfile(
            phoneNumber: _phoneController.text.trim(),
            location: _locationController.text.trim(),
          );
      if (mounted) {
        context.showInAppNotification('Profile updated successfully!',
            type: InAppNotificationType.success);
        setState(() => _isEditingPhone = false);
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: PrimaryText(
            text: 'Personal Information',
            color: theme.accentTxt,
            fontSize: 18,
            fontWeight: FontWeight.bold),
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
                              ? DecorationImage(
                                  image: NetworkImage(user!.photoURL!), fit: BoxFit.cover)
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
                _infoTile(context, 'Full Name', user?.displayName ?? 'User Name', isEditable: false),
                _infoTile(context, 'Email Address', user?.email ?? 'user@example.com',
                    isEditable: false),
                _editableInfoTile(
                  context,
                  'Phone Number',
                  _phoneController,
                  isEditing: _isEditingPhone,
                  onEditTap: () => setState(() => _isEditingPhone = !_isEditingPhone),
                ),
                _locationTile(
                  context,
                  'Location',
                  _locationController.text.isEmpty ? 'Not set' : _locationController.text,
                  isFetching: _isFetchingLocation,
                  onEditTap: _fetchLocation,
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

  Widget _infoTile(BuildContext context, String label, String value, {bool isEditable = true}) {
    AppTheme theme = context.watch();
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      gradient: theme.glassGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SecondaryText(text: label, fontSize: 12, color: theme.accentTxt.withOpacity(0.7)),
          8.verticalSpace,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PrimaryText(
                  text: value, fontSize: 15, fontWeight: FontWeight.w600, color: theme.accentTxt),
              if (isEditable) Icon(Icons.edit_outlined, color: theme.accentTxt, size: 18),
            ],
          ),
        ],
      ),
    );
  }

  Widget _editableInfoTile(BuildContext context, String label, TextEditingController controller,
      {required bool isEditing, required VoidCallback onEditTap}) {
    AppTheme theme = context.watch();
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      gradient: theme.glassGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SecondaryText(text: label, fontSize: 12, color: theme.accentTxt.withOpacity(0.7)),
          8.verticalSpace,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: isEditing
                    ? TextField(
                        controller: controller,
                        autofocus: true,
                        keyboardType: label.toLowerCase().contains('phone') ? TextInputType.phone : TextInputType.text,
                        inputFormatters: label.toLowerCase().contains('phone') 
                            ? [FilteringTextInputFormatter.digitsOnly] 
                            : null,
                        style: GoogleFonts.inter(
                          color: theme.accentTxt,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter $label',
                          hintStyle: TextStyle(color: theme.accentTxt.withOpacity(0.3)),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      )
                    : PrimaryText(
                        text: controller.text.isEmpty ? 'Not set' : controller.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.accentTxt),
              ),
              Icon(isEditing ? Icons.check_circle_outline : Icons.edit_outlined,
                      color: isEditing ? theme.primaryBase : theme.accentTxt, size: 20)
                  .rippleClick(onEditTap),
            ],
          ),
        ],
      ),
    );
  }

  Widget _locationTile(BuildContext context, String label, String value,
      {required bool isFetching, required VoidCallback onEditTap}) {
    AppTheme theme = context.watch();
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      gradient: theme.glassGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SecondaryText(text: label, fontSize: 12, color: theme.accentTxt.withOpacity(0.7)),
          8.verticalSpace,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: PrimaryText(
                    text: value, fontSize: 15, fontWeight: FontWeight.w600, color: theme.accentTxt),
              ),
              isFetching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                    )
                  : Icon(Icons.my_location, color: theme.accentTxt, size: 18).rippleClick(onEditTap),
            ],
          ),
        ],
      ),
    );
  }
}
