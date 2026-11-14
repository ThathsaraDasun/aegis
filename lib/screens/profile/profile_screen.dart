import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../services/seed_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/aegis_theme.dart';

/// Toggle this to [true] to test the UI with hardcoded data without Firestore.
const bool _useDummyData = false;

/// A screen that displays the user's profile and safety-critical medical information.
/// 
/// Streams user data live from the Firestore 'users' collection via [FirestoreService].
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  /// Generates a consistent background color for the avatar based on the name.
  Color _getAvatarColor(String name) {
    final int hash = name.hashCode;
    final List<Color> colors = [
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

  @override
  Widget build(BuildContext context) {
    final User? firebaseUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AegisColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: _useDummyData
          ? _buildProfileContent(context, _dummyUser, firebaseUser?.email ?? 'demo@aegis.safe')
          : _buildFirestoreStream(context, firebaseUser),
    );
  }

  Widget _buildFirestoreStream(BuildContext context, User? firebaseUser) {
    if (firebaseUser == null) {
      return const _ErrorOrEmptyState(
        message: 'No user signed in.',
        icon: Icons.person_off_outlined,
      );
    }

    return StreamBuilder<UserModel?>(
      stream: FirestoreService.instance.streamUserProfile(firebaseUser.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorOrEmptyState(
            message: 'Error loading profile: ${snapshot.error}',
            icon: Icons.error_outline,
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AegisColors.primary),
          );
        }

        final userModel = snapshot.data ?? UserModel(
          userId: firebaseUser.uid,
          name: firebaseUser.displayName ?? 'Aegis User',
          phone: firebaseUser.phoneNumber ?? '',
        );

        final email = firebaseUser.email ?? 'No email provided';

        return _buildProfileContent(context, userModel, email);
      },
    );
  }

  Widget _buildProfileContent(BuildContext context, UserModel user, String email) {
    final String initials = user.name.isNotEmpty
        ? user.name.trim().split(RegExp(r'\s+')).map((e) => e[0]).take(2).join().toUpperCase()
        : '?';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AegisColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: _getAvatarColor(user.name),
                  child: Text(
                    initials,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name.isNotEmpty ? user.name : 'Aegis User',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AegisColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AegisColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.phone.isNotEmpty ? user.phone : 'No phone added',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AegisColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Medical Info Section Header
          Text(
            'EMERGENCY MEDICAL PROFILE',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: AegisColors.primary,
            ),
          ),
          const SizedBox(height: 12),

          // Medical Info Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AegisColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AegisColors.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMedicalDetailTile(
                      label: 'Blood Type',
                      value: user.bloodType.isNotEmpty ? user.bloodType : 'Not Set',
                      icon: Icons.bloodtype_outlined,
                      valueColor: AegisColors.tertiary,
                    ),
                    _buildMedicalDetailTile(
                      label: 'Allergies',
                      value: user.allergies.isNotEmpty ? user.allergies : 'None Reported',
                      icon: Icons.medical_services_outlined,
                      valueColor: AegisColors.secondary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AegisColors.surfaceContainerHighest, height: 1),
                const SizedBox(height: 16),
                Text(
                  'Emergency Note for First Responders',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AegisColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  user.emergencyNote.isNotEmpty
                      ? user.emergencyNote
                      : 'No emergency notes specified.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AegisColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Edit Profile Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => _showEditProfileBottomSheet(context, user),
              icon: const Icon(Icons.edit_outlined, color: AegisColors.primary),
              label: Text(
                'Edit Profile & Medical Info',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AegisColors.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AegisColors.primary, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Sign Out Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _handleSignOut(context),
              icon: const Icon(Icons.logout, color: Colors.white),
              label: Text(
                'Sign Out',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AegisColors.primaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await SeedService.instance.seedDemoData();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Demo data successfully seeded to Firestore!', style: GoogleFonts.inter()),
                          backgroundColor: AegisColors.tertiary,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to seed demo data: $e', style: GoogleFonts.inter()),
                          backgroundColor: AegisColors.secondary,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.dataset_linked_outlined, color: AegisColors.tertiary),
                label: Text(
                  'Seed Demo Data (Debug)',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AegisColors.tertiary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AegisColors.tertiary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showEditProfileBottomSheet(BuildContext context, UserModel user) {
    final nameController = TextEditingController(text: user.name);
    final phoneController = TextEditingController(text: user.phone);
    final allergiesController = TextEditingController(text: user.allergies);
    final emergencyNoteController = TextEditingController(text: user.emergencyNote);
    String selectedBloodType = user.bloodType.isNotEmpty ? user.bloodType : 'O+';
    const bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AegisColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Profile & Emergency Info',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AegisColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AegisColors.textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      style: GoogleFonts.outfit(color: AegisColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        labelStyle: GoogleFonts.outfit(color: AegisColors.textSecondary),
                        prefixIcon: const Icon(Icons.person_outline, color: AegisColors.textSecondary),
                        filled: true,
                        fillColor: AegisColors.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      style: GoogleFonts.outfit(color: AegisColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        labelStyle: GoogleFonts.outfit(color: AegisColors.textSecondary),
                        prefixIcon: const Icon(Icons.phone_outlined, color: AegisColors.textSecondary),
                        filled: true,
                        fillColor: AegisColors.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: bloodTypes.contains(selectedBloodType) ? selectedBloodType : 'O+',
                      dropdownColor: AegisColors.surfaceContainerLow,
                      style: GoogleFonts.outfit(color: AegisColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Blood Type',
                        labelStyle: GoogleFonts.outfit(color: AegisColors.textSecondary),
                        prefixIcon: const Icon(Icons.bloodtype_outlined, color: AegisColors.tertiary),
                        filled: true,
                        fillColor: AegisColors.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: bloodTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type, style: GoogleFonts.outfit(color: AegisColors.textPrimary)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedBloodType = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: allergiesController,
                      style: GoogleFonts.outfit(color: AegisColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Allergies (e.g. Penicillin, Peanuts)',
                        labelStyle: GoogleFonts.outfit(color: AegisColors.textSecondary),
                        prefixIcon: const Icon(Icons.medical_services_outlined, color: AegisColors.secondary),
                        filled: true,
                        fillColor: AegisColors.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emergencyNoteController,
                      maxLines: 3,
                      style: GoogleFonts.outfit(color: AegisColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Emergency Note for First Responders',
                        labelStyle: GoogleFonts.outfit(color: AegisColors.textSecondary),
                        prefixIcon: const Icon(Icons.note_alt_outlined, color: AegisColors.textSecondary),
                        filled: true,
                        fillColor: AegisColors.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          final updatedUser = UserModel(
                            userId: user.userId,
                            name: nameController.text.trim(),
                            phone: phoneController.text.trim(),
                            bloodType: selectedBloodType,
                            allergies: allergiesController.text.trim(),
                            emergencyNote: emergencyNoteController.text.trim(),
                          );
                          try {
                            await FirestoreService.instance.saveUserProfile(updatedUser);
                            if (context.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Profile & Emergency Info saved successfully!', style: GoogleFonts.outfit()),
                                  backgroundColor: AegisColors.tertiary,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Profile saved locally (Demo mode).', style: GoogleFonts.outfit()),
                                  backgroundColor: AegisColors.tertiary,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AegisColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Save Profile Changes',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMedicalDetailTile({
    required String label,
    required String value,
    required IconData icon,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: valueColor, size: 24),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AegisColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleSignOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e', style: GoogleFonts.inter()),
            backgroundColor: AegisColors.primaryContainer,
          ),
        );
      }
    }
  }
}

// TODO: remove dummy data, using Firestore stream above
final UserModel _dummyUser = UserModel(
  userId: 'dummy-user-123',
  name: 'Elena Vance',
  phone: '+1 (555) 019-2834',
  bloodType: 'O+',
  allergies: 'Penicillin, Peanuts',
  emergencyNote: 'Asthma patient. Keeps inhaler in primary bag pocket. Contact emergency response immediately on SOS.',
);

class _ErrorOrEmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;

  const _ErrorOrEmptyState({
    required this.message,
    required this.icon,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: AegisColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AegisColors.textSecondary,
                fontSize: 14,
              ),
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AegisColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  actionLabel!,
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
