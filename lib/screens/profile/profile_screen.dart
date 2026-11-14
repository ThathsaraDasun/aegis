import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/activity_service.dart';
import '../../theme/aegis_theme.dart';
import '../../widgets/contact_card.dart';
import '../../widgets/signed_in_builder.dart';
import '../../widgets/state_views.dart';
import '../activity/trip_history_screen.dart';
import 'edit_profile_screen.dart';

/// Displays the profile and safety-critical medical information of the user.
///
/// Streams the user document live from Firestore 'users/{uid}' and links to
/// the Edit Profile screen and Trip History.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.service});

  /// Injected for tests; defaults to the Firestore-backed service.
  final ActivityService? service;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SignedInBuilder(
        signedOut: const EmptyStateView(
          icon: Icons.person_off_outlined,
          message: 'No user signed in. Sign in to view your profile.',
        ),
        signedIn: (context, firebaseUser) => StreamBuilder<UserModel?>(
              stream: (service ?? ActivityService()).watchUser(firebaseUser.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorStateView(error: snapshot.error.toString());
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingView();
                }

                final user = snapshot.data;
                final email = firebaseUser.email ?? 'No email provided';

                if (user == null) {
                  return EmptyStateView(
                    icon: Icons.person_add_alt_1_outlined,
                    message: 'Your profile is not set up yet.\nAdd your details and medical info '
                        'so guardians see them during an SOS.',
                    actionLabel: 'Set Up Profile',
                    onAction: () => EditProfileScreen.open(
                      context,
                      UserModel(userId: firebaseUser.uid, name: firebaseUser.displayName ?? '', phone: ''),
                    ),
                  );
                }

                return _ProfileContent(user: user, email: email);
              },
            ),
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.user, required this.email});

  final UserModel user;
  final String email;

  Future<void> _handleSignOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AegisSpacing.screen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          Card(
            margin: EdgeInsets.zero,
            elevation: AegisElevation.none,
            child: Padding(
              padding: const EdgeInsets.all(AegisSpacing.xl),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AegisColors.avatarFor(user.name),
                    child: Text(
                      ContactCard.initialsFor(user.name),
                      style: AegisText.headline.copyWith(fontSize: 26, color: AegisColors.onPrimary),
                    ),
                  ),
                  const SizedBox(width: AegisSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name.isNotEmpty ? user.name : 'Aegis User',
                          style: AegisText.headline.copyWith(fontSize: 20),
                        ),
                        const SizedBox(height: AegisSpacing.xs),
                        Text(email, style: AegisText.caption),
                        const SizedBox(height: AegisSpacing.xxs),
                        Text(
                          user.phone.isNotEmpty ? user.phone : 'No phone added',
                          style: AegisText.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AegisSpacing.xl),

          const SectionHeader('Emergency Medical Profile', color: AegisColors.primary),
          Card(
            margin: EdgeInsets.zero,
            elevation: AegisElevation.none,
            shape: RoundedRectangleBorder(
              borderRadius: AegisRadius.lgAll,
              side: BorderSide(color: AegisColors.primary.withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AegisSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _MedicalDetailTile(
                          label: 'Blood Type',
                          value: user.bloodType.isNotEmpty ? user.bloodType : 'Not Set',
                          icon: Icons.bloodtype_outlined,
                          valueColor: AegisColors.tertiary,
                        ),
                      ),
                      const SizedBox(width: AegisSpacing.md),
                      Expanded(
                        child: _MedicalDetailTile(
                          label: 'Allergies',
                          value: user.allergies.isNotEmpty ? user.allergies : 'None Reported',
                          icon: Icons.medical_services_outlined,
                          valueColor: AegisColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AegisSpacing.lg),
                  const Divider(),
                  const SizedBox(height: AegisSpacing.lg),
                  Text('Emergency Note for First Responders', style: AegisText.small),
                  const SizedBox(height: 6),
                  Text(
                    user.emergencyNote.isNotEmpty ? user.emergencyNote : 'No emergency notes specified.',
                    style: AegisText.body,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AegisSpacing.xl),

          const SectionHeader('Activity'),
          Card(
            margin: EdgeInsets.zero,
            elevation: AegisElevation.none,
            child: ListTile(
              shape: AegisRadius.lgShape,
              leading: const Icon(Icons.history_outlined, color: AegisColors.tertiary),
              title: Text('Trip History', style: AegisText.bodyStrong),
              subtitle: Text('Past walks and their routes', style: AegisText.small),
              trailing: const Icon(Icons.chevron_right, color: AegisColors.textSecondary),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TripHistoryScreen()),
              ),
            ),
          ),
          const SizedBox(height: AegisSpacing.xxl),

          SizedBox(
            width: double.infinity,
            height: AegisSizes.buttonHeight,
            child: OutlinedButton.icon(
              onPressed: () => EditProfileScreen.open(context, user),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Profile & Medical Info'),
            ),
          ),
          const SizedBox(height: AegisSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: AegisSizes.buttonHeight,
            child: ElevatedButton.icon(
              onPressed: () => _handleSignOut(context),
              style: ElevatedButton.styleFrom(backgroundColor: AegisColors.primaryContainer),
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicalDetailTile extends StatelessWidget {
  const _MedicalDetailTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: valueColor, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AegisText.small.copyWith(fontSize: 11)),
              const SizedBox(height: AegisSpacing.xxs),
              Text(
                value,
                style: AegisText.bodyStrong.copyWith(fontSize: 15, fontWeight: FontWeight.bold, color: valueColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
