import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/profile_photo_avatar.dart';
import 'edit_profile_screen.dart';

/// Toggle this to [true] to test the UI with hardcoded data without Firestore.
const bool _useDummyData = false;

/// Colour palette shared with the Login / Register screens.
class _P {
  static const Color azure = Color(0xFF007FFF);
  static const Color sky = Color(0xFF66CCFF);
  static const Color mist = Color(0xFFF0F8FF);
  static const Color ink = Color(0xFF0B2545);
  static const Color muted = Color(0xFF6B7A90);
  static const Color line = Color(0xFFD6ECFF);
  static const Color danger = Color(0xFFD93025);
}

/// A screen that displays the user's profile and safety-critical medical information.
///
/// Streams user data live from the Firestore 'users' collection via [FirestoreService].
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? firebaseUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _P.mist,
      body: _useDummyData
          ? _buildProfileContent(
              context,
              _dummyUser,
              firebaseUser?.email ?? 'demo@aegis.safe',
            )
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
            child: CircularProgressIndicator(color: _P.azure),
          );
        }

        final userModel = snapshot.data;

        if (userModel == null) {
          return _ErrorOrEmptyState(
            message: 'User profile not found in database.',
            icon: Icons.person_search_outlined,
            onAction: () => _handleSignOut(context),
            actionLabel: 'Sign Out',
          );
        }

        final email = firebaseUser.email ?? 'No email provided';

        return _buildProfileContent(context, userModel, email);
      },
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    UserModel user,
    String email,
  ) {
    final String initials = user.name.isNotEmpty
        ? user.name
              .trim()
              .split(RegExp(r'\s+'))
              .map((e) => e[0])
              .take(2)
              .join()
              .toUpperCase()
        : '?';

    void openEdit() => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditProfileScreen(initialUser: user)),
    );

    return Stack(
      children: [
        // Soft blue glow at the top, as in the reference design.
        Positioned(
          top: -120,
          right: -80,
          child: _glow(280, _P.sky.withValues(alpha: 0.28)),
        ),
        Positioned(
          top: 60,
          left: -110,
          child: _glow(220, _P.azure.withValues(alpha: 0.10)),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Profile',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: _P.ink,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ------------------------------------------------ header
                  _Card(
                    padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
                    child: Column(
                      children: [
                        ProfilePhotoAvatar(
                          uid:
                              FirebaseAuth.instance.currentUser?.uid ??
                              user.userId,
                          initials: initials,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          user.name.isNotEmpty ? user.name : 'Aegis User',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: _P.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: _P.muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _MetaChip(
                              icon: Icons.phone_outlined,
                              text: user.phone.isNotEmpty
                                  ? user.phone
                                  : 'No phone added',
                            ),
                            _MetaChip(
                              icon: Icons.bloodtype_outlined,
                              text: user.bloodType.isNotEmpty
                                  ? user.bloodType
                                  : 'Blood type not set',
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: openEdit,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit Profile'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _P.azure,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 26,
                              vertical: 14,
                            ),
                            shape: const StadiumBorder(),
                            textStyle: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ------------------------------------- medical profile
                  const _SectionLabel('Emergency medical profile'),
                  _InfoRow(
                    icon: Icons.bloodtype_outlined,
                    label: 'Blood Type',
                    value: user.bloodType.isNotEmpty
                        ? user.bloodType
                        : 'Not Set',
                  ),
                  _InfoRow(
                    icon: Icons.medical_services_outlined,
                    label: 'Allergies',
                    value: user.allergies.isNotEmpty
                        ? user.allergies
                        : 'None Reported',
                  ),
                  _InfoRow(
                    icon: Icons.sticky_note_2_outlined,
                    label: 'Emergency Note for First Responders',
                    value: user.emergencyNote.isNotEmpty
                        ? user.emergencyNote
                        : 'No emergency notes specified.',
                    stacked: true,
                  ),
                  const SizedBox(height: 16),

                  // ------------------------------------------- account
                  const _SectionLabel('Account'),
                  _ActionRow(
                    icon: Icons.manage_accounts_outlined,
                    label: 'Edit Profile & Medical Info',
                    onTap: openEdit,
                  ),
                  _ActionRow(
                    icon: Icons.logout_rounded,
                    label: 'Sign Out',
                    color: _P.danger,
                    showChevron: false,
                    onTap: () => _handleSignOut(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _glow(double size, Color color) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );

  Future<void> _handleSignOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e', style: GoogleFonts.outfit()),
            backgroundColor: _P.danger,
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
  emergencyNote:
      'Asthma patient. Keeps inhaler in primary bag pocket. Contact emergency response immediately on SOS.',
);

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

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: _P.mist,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _P.line),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _P.azure),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(fontSize: 12.5, color: _P.muted),
          ),
        ),
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Text(
      text.toUpperCase(),
      style: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: _P.azure,
      ),
    ),
  );
}

/// Light-blue rounded icon tile used at the start of each row.
class _IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconTile(this.icon, {this.color = _P.azure});

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, color: color, size: 20),
  );
}

/// Read-only information row (label + value).
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool stacked;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.stacked = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = GoogleFonts.outfit(
      fontSize: stacked ? 13 : 15,
      fontWeight: stacked ? FontWeight.w500 : FontWeight.w600,
      color: stacked ? _P.muted : _P.ink,
    );
    final valueStyle = GoogleFonts.outfit(
      fontSize: stacked ? 15 : 14.5,
      fontWeight: stacked ? FontWeight.w500 : FontWeight.w700,
      color: stacked ? _P.ink : _P.azure,
      height: 1.35,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Card(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: stacked
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            _IconTile(icon),
            const SizedBox(width: 14),
            Expanded(
              child: stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: labelStyle),
                        const SizedBox(height: 4),
                        Text(value, style: valueStyle),
                      ],
                    )
                  : Row(
                      children: [
                        Text(label, style: labelStyle),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            value,
                            textAlign: TextAlign.end,
                            style: valueStyle,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tappable row with a trailing chevron, as in the reference settings list.
class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool showChevron;
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = _P.azure,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                _IconTile(icon, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: color == _P.azure ? _P.ink : color,
                    ),
                  ),
                ),
                if (showChevron)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _P.muted,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

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
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: _P.azure.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: _P.azure),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: _P.muted, fontSize: 15),
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: _P.azure,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  actionLabel!,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
