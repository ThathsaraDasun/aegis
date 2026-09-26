import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user_model.dart';
import '../../theme/aegis_theme.dart';

/// Toggle this to [true] to test the UI with hardcoded data without Firestore.
const bool _useDummyData = true;

/// A screen that displays the user's profile and safety-critical medical information.
/// 
/// Streams user data live from the Firestore 'users' collection and provides
/// quick access to edit profile and sign-out functionality.
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
        title: Text(
          'Profile',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AegisColors.surfaceContainerLow,
        elevation: 0,
        centerTitle: true,
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

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .snapshots(),
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

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _ErrorOrEmptyState(
            message: 'User profile not found in database.',
            icon: Icons.person_search_outlined,
            onAction: () => _handleSignOut(context),
            actionLabel: 'Sign Out',
          );
        }

        final userModel = UserModel.fromFirestore(snapshot.data!);
        final email = firebaseUser.email ?? 'No email provided';

        return _buildProfileContent(context, userModel, email);
      },
    );
  }

  Widget _buildProfileContent(BuildContext context, UserModel user, String email) {
    final String initials = user.name.isNotEmpty
        ? user.name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
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
              borderRadius: BorderRadius.circular(20),
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
              fontSize: 12,
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
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AegisColors.primary.withOpacity(0.3),
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
                  style: GoogleFonts.outfit(
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
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Edit Profile feature coming soon!',
                      style: GoogleFonts.outfit(),
                    ),
                    backgroundColor: AegisColors.surfaceContainerHighest,
                  ),
                );
              },
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
                backgroundColor: Colors.redAccent.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
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
      // AuthWrapper or Navigator will handle returning to LoginScreen
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e', style: GoogleFonts.outfit()),
            backgroundColor: Colors.redAccent,
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
              color: AegisColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: AegisColors.textSecondary,
                fontSize: 16,
              ),
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AegisColors.primary,
                ),
                child: Text(
                  actionLabel!,
                  style: GoogleFonts.outfit(color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
