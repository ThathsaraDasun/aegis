import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/profile_photo_avatar.dart';
import '../safety/safety_shell.dart';

/// Colour palette shared with the Login / Register / Profile screens.
class _P {
  static const Color azure = Color(0xFF007FFF);
  static const Color sky = Color(0xFF66CCFF);
  static const Color mist = Color(0xFFF0F8FF);
  static const Color ink = Color(0xFF0B2545);
  static const Color muted = Color(0xFF6B7A90);
  static const Color line = Color(0xFFD6ECFF);
  static const Color danger = Color(0xFFD93025);
}

/// A screen allowing the user to update their personal identity and safety-critical
/// medical profile used by first responders and trusted guardians during an SOS emergency.
/// Automatically pauses global floating SOS button during active form editing.
class EditProfileScreen extends StatefulWidget {
  final UserModel initialUser;

  const EditProfileScreen({super.key, required this.initialUser});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _allergiesController;
  late final TextEditingController _emergencyNoteController;

  late String _selectedBloodType;
  bool _isSaving = false;

  static const List<String> _bloodTypeOptions = [
    'Not Set',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialUser.name);
    _phoneController = TextEditingController(text: widget.initialUser.phone);
    _allergiesController = TextEditingController(
      text: widget.initialUser.allergies,
    );
    _emergencyNoteController = TextEditingController(
      text: widget.initialUser.emergencyNote,
    );

    final rawBlood = widget.initialUser.bloodType.trim();
    if (_bloodTypeOptions.contains(rawBlood)) {
      _selectedBloodType = rawBlood;
    } else {
      _selectedBloodType = 'Not Set';
    }

    _nameController.addListener(() => setState(() {}));

    // The global SOS button is not needed while editing the profile.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => SafetyShell.sosButtonHiders.value++,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => SafetyShell.sosButtonHiders.value--,
    );
    _nameController.dispose();
    _phoneController.dispose();
    _allergiesController.dispose();
    _emergencyNoteController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    final String updatedName = _nameController.text.trim();
    final String updatedPhone = _phoneController.text.trim();
    final String updatedBlood = _selectedBloodType == 'Not Set'
        ? ''
        : _selectedBloodType;
    final String updatedAllergies = _allergiesController.text.trim();
    final String updatedNote = _emergencyNoteController.text.trim();

    final String targetUid = widget.initialUser.userId.isNotEmpty
        ? widget.initialUser.userId
        : (FirebaseAuth.instance.currentUser?.uid ?? 'demo_user');

    final updatedModel = widget.initialUser.copyWith(
      userId: targetUid,
      name: updatedName,
      phone: updatedPhone,
      bloodType: updatedBlood,
      allergies: updatedAllergies,
      emergencyNote: updatedNote,
    );

    try {
      // Persist to Cloud Firestore via typed FirestoreService
      await FirestoreService.instance.saveUserProfile(updatedModel);

      // Optionally update Firebase Auth display name if signed in
      try {
        final currentAuthUser = FirebaseAuth.instance.currentUser;
        if (currentAuthUser != null && updatedName.isNotEmpty) {
          await currentAuthUser.updateDisplayName(updatedName);
        }
      } catch (_) {
        // Non-critical if Auth profile sync is skipped in test/mock environment
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profile and medical details updated successfully!',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
            ),
            backgroundColor: _P.azure,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update profile: $e',
              style: GoogleFonts.outfit(),
            ),
            backgroundColor: _P.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData prefixIcon,
    String? hintText,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      labelStyle: GoogleFonts.outfit(color: _P.muted, fontSize: 14),
      floatingLabelStyle: GoogleFonts.outfit(
        color: _P.azure,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: GoogleFonts.outfit(
        color: _P.muted.withValues(alpha: 0.7),
        fontSize: 13.5,
      ),
      prefixIcon: Icon(prefixIcon, color: _P.azure, size: 20),
      filled: true,
      fillColor: _P.mist,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      errorStyle: GoogleFonts.outfit(color: _P.danger, fontSize: 12),
      border: border(_P.line),
      enabledBorder: border(_P.line),
      disabledBorder: border(_P.line),
      focusedBorder: border(_P.azure, 1.6),
      errorBorder: border(_P.danger),
      focusedErrorBorder: border(_P.danger, 1.6),
    );
  }

  TextStyle get _fieldText => GoogleFonts.outfit(color: _P.ink, fontSize: 15);

  @override
  Widget build(BuildContext context) {
    final String currentName = _nameController.text.trim();
    final String initials = currentName.isNotEmpty
        ? currentName
              .split(RegExp(r'\s+'))
              .map((e) => e.isNotEmpty ? e[0] : '')
              .take(2)
              .join()
              .toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: _P.mist,
      appBar: AppBar(
        backgroundColor: _P.azure,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Edit Profile & Medical Info',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Soft blue glow, matching the Profile page.
            Positioned(
              top: -120,
              right: -80,
              child: _glow(280, _P.sky.withValues(alpha: 0.28)),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Live avatar preview
                        _Card(
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                          child: Column(
                            children: [
                              ProfilePhotoAvatar(
                                uid: widget.initialUser.userId,
                                initials: initials,
                                size: 76,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                currentName.isNotEmpty
                                    ? currentName
                                    : 'User Name',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  color: _P.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Aegis Safety Profile',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: _P.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),

                        // SECTION 1: Personal Information
                        const _SectionLabel(
                          icon: Icons.person_outline_rounded,
                          text: 'Personal information',
                        ),
                        _Card(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _nameController,
                                style: _fieldText,
                                cursorColor: _P.azure,
                                decoration: _buildInputDecoration(
                                  label: 'Full Name',
                                  hintText: 'e.g. Elena Vance',
                                  prefixIcon: Icons.person_outline,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your full name.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                style: _fieldText,
                                cursorColor: _P.azure,
                                decoration: _buildInputDecoration(
                                  label: 'Phone Number',
                                  hintText: 'e.g. +1 555-019-2834',
                                  prefixIcon: Icons.phone_outlined,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),

                        // SECTION 2: Emergency Medical Profile
                        const _SectionLabel(
                          icon: Icons.medical_services_outlined,
                          text: 'Emergency medical profile',
                        ),
                        _Card(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _P.azure.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.info_outline_rounded,
                                      size: 18,
                                      color: _P.azure,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'This vital information is broadcasted to primary guardians and first responders during an active SOS emergency or unconfirmed fall event.',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12.5,
                                          color: _P.muted,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Blood Type Dropdown
                              DropdownButtonFormField<String>(
                                // ignore: deprecated_member_use
                                value: _selectedBloodType,
                                dropdownColor: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: _P.azure,
                                ),
                                style: _fieldText,
                                decoration: _buildInputDecoration(
                                  label: 'Blood Type',
                                  prefixIcon: Icons.bloodtype_outlined,
                                ),
                                items: _bloodTypeOptions.map((type) {
                                  return DropdownMenuItem<String>(
                                    value: type,
                                    child: Text(
                                      type,
                                      style: GoogleFonts.outfit(
                                        color: type == 'Not Set'
                                            ? _P.muted
                                            : _P.ink,
                                        fontWeight: type == 'Not Set'
                                            ? FontWeight.normal
                                            : FontWeight.w700,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedBloodType = val);
                                  }
                                },
                              ),
                              const SizedBox(height: 14),

                              // Allergies and Medical Conditions
                              TextFormField(
                                controller: _allergiesController,
                                style: _fieldText,
                                cursorColor: _P.azure,
                                decoration: _buildInputDecoration(
                                  label: 'Allergies / Critical Conditions',
                                  hintText: 'e.g. Penicillin, Peanuts, Asthma',
                                  prefixIcon: Icons.warning_amber_rounded,
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Emergency Note
                              TextFormField(
                                controller: _emergencyNoteController,
                                maxLines: 3,
                                style: _fieldText,
                                cursorColor: _P.azure,
                                decoration: _buildInputDecoration(
                                  label: 'Emergency Instructions / Notes',
                                  hintText:
                                      'e.g. Keep inhaler in backpack side pouch. Contact primary guardian immediately.',
                                  prefixIcon: Icons.notes_outlined,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Save Action Button
                        SizedBox(
                          height: 54,
                          child: FilledButton(
                            onPressed: _isSaving ? null : _handleSave,
                            style: FilledButton.styleFrom(
                              backgroundColor: _P.azure,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: _P.azure.withValues(
                                alpha: 0.55,
                              ),
                              disabledForegroundColor: Colors.white,
                              elevation: 0,
                              shape: const StadiumBorder(),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Save Profile & Medical Info',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Cancel Button
                        SizedBox(
                          height: 50,
                          child: TextButton(
                            onPressed: _isSaving
                                ? null
                                : () => Navigator.of(context).pop(false),
                            style: TextButton.styleFrom(
                              foregroundColor: _P.azure,
                              shape: const StadiumBorder(),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _glow(double size, Color color) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}

/// White rounded card with a soft blue shadow.
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Card({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: _P.azure.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: child,
  );
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SectionLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Row(
      children: [
        Icon(icon, size: 16, color: _P.azure),
        const SizedBox(width: 8),
        Text(
          text.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: _P.azure,
          ),
        ),
      ],
    ),
  );
}
