import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/aegis_theme.dart';

/// A screen allowing the user to update their personal identity and safety-critical
/// medical profile used by first responders and trusted guardians during an SOS emergency.
class EditProfileScreen extends StatefulWidget {
  final UserModel initialUser;

  const EditProfileScreen({
    super.key,
    required this.initialUser,
  });

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
    _allergiesController = TextEditingController(text: widget.initialUser.allergies);
    _emergencyNoteController = TextEditingController(text: widget.initialUser.emergencyNote);

    final rawBlood = widget.initialUser.bloodType.trim();
    if (_bloodTypeOptions.contains(rawBlood)) {
      _selectedBloodType = rawBlood;
    } else {
      _selectedBloodType = 'Not Set';
    }

    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _allergiesController.dispose();
    _emergencyNoteController.dispose();
    super.dispose();
  }

  Color _getAvatarColor(String name) {
    final int hash = name.hashCode;
    const List<Color> colors = [
      Colors.blueAccent,
      Colors.orangeAccent,
      Colors.greenAccent,
      Colors.purpleAccent,
      Colors.redAccent,
      Colors.tealAccent,
      Colors.indigoAccent,
    ];
    return colors[hash.abs() % colors.length];
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    final String updatedName = _nameController.text.trim();
    final String updatedPhone = _phoneController.text.trim();
    final String updatedBlood = _selectedBloodType == 'Not Set' ? '' : _selectedBloodType;
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
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            backgroundColor: AegisColors.tertiary,
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
              style: GoogleFonts.inter(),
            ),
            backgroundColor: AegisColors.primaryContainer,
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
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      labelStyle: GoogleFonts.inter(color: AegisColors.textSecondary, fontSize: 14),
      hintStyle: GoogleFonts.inter(color: AegisColors.textSecondary.withValues(alpha: 0.5), fontSize: 13),
      prefixIcon: Icon(prefixIcon, color: AegisColors.textSecondary, size: 20),
      filled: true,
      fillColor: AegisColors.surfaceContainerHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AegisColors.surfaceContainerHighest, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AegisColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String currentName = _nameController.text.trim();
    final String initials = currentName.isNotEmpty
        ? currentName.split(RegExp(r'\s+')).map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: AegisColors.background,
      appBar: AppBar(
        title: Text(
          'Edit Profile & Medical Info',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live Avatar Preview Header
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundColor: _getAvatarColor(currentName),
                        child: Text(
                          initials,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 30,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        currentName.isNotEmpty ? currentName : 'User Name',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AegisColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Aegis Safety Profile',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AegisColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // SECTION 1: Personal Information
                Text(
                  'PERSONAL INFORMATION',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: AegisColors.primary,
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _nameController,
                  style: GoogleFonts.inter(color: AegisColors.textPrimary),
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
                  style: GoogleFonts.inter(color: AegisColors.textPrimary),
                  decoration: _buildInputDecoration(
                    label: 'Phone Number',
                    hintText: 'e.g. +1 555-019-2834',
                    prefixIcon: Icons.phone_outlined,
                  ),
                ),
                const SizedBox(height: 28),

                // SECTION 2: Emergency Medical Profile
                Row(
                  children: [
                    const Icon(Icons.medical_services_outlined, size: 16, color: AegisColors.secondary),
                    const SizedBox(width: 8),
                    Text(
                      'EMERGENCY MEDICAL PROFILE',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: AegisColors.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'This vital information is broadcasted to primary guardians and first responders during an active SOS emergency or unconfirmed fall event.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AegisColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // Blood Type Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedBloodType,
                  dropdownColor: AegisColors.surfaceContainerHigh,
                  style: GoogleFonts.inter(color: AegisColors.textPrimary, fontSize: 15),
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
                          color: type == 'Not Set' ? AegisColors.textSecondary : AegisColors.textPrimary,
                          fontWeight: type == 'Not Set' ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedBloodType = val);
                  },
                ),
                const SizedBox(height: 14),

                // Allergies and Medical Conditions
                TextFormField(
                  controller: _allergiesController,
                  style: GoogleFonts.inter(color: AegisColors.textPrimary),
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
                  style: GoogleFonts.inter(color: AegisColors.textPrimary),
                  decoration: _buildInputDecoration(
                    label: 'Emergency Instructions / Notes',
                    hintText: 'e.g. Keep inhaler in backpack side pouch. Contact primary guardian immediately.',
                    prefixIcon: Icons.notes_outlined,
                  ),
                ),
                const SizedBox(height: 36),

                // Save Action Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AegisColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
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
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 14),

                // Cancel Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: TextButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: AegisColors.textSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.outfit(fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
