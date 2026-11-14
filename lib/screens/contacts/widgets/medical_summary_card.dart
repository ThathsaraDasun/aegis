import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/contact_model.dart';
import '../../../models/medical_profile_model.dart';
import '../../../services/contacts_service.dart';
import '../../../theme/aegis_theme.dart';

/// Read-only card showing the user's medical profile.
class MedicalSummaryCard extends StatelessWidget {
  final MedicalProfile profile;
  final VoidCallback? onTap;

  const MedicalSummaryCard({super.key, required this.profile, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AegisColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AegisRadius.xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AegisRadius.xl),
        child: Padding(
          padding: const EdgeInsets.all(AegisSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _BloodBadge(bloodType: profile.bloodType),
                  const SizedBox(width: AegisSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Shared during SOS only',
                            style: GoogleFonts.outfit(
                                fontSize: 12, color: AegisColors.textSecondary)),
                        Text(
                          profile.bloodType.isEmpty
                              ? 'Blood type not set'
                              : 'Blood type ${profile.bloodType}',
                          style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AegisColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null)
                    const Icon(Icons.chevron_right, color: AegisColors.textSecondary),
                ],
              ),
              const SizedBox(height: AegisSpacing.md),
              _row(Icons.warning_amber_rounded, 'Allergies', profile.allergies, AegisColors.warning),
              _row(Icons.healing_outlined, 'Conditions', profile.conditions, AegisColors.secondary),
              _row(Icons.sticky_note_2_outlined, 'Emergency note', profile.emergencyNote,
                  AegisColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: AegisSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AegisSpacing.sm),
          SizedBox(
            width: 100,
            child: Text(label,
                style: GoogleFonts.outfit(fontSize: 13, color: AegisColors.textSecondary)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: GoogleFonts.outfit(fontSize: 13, color: AegisColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _BloodBadge extends StatelessWidget {
  final String bloodType;
  const _BloodBadge({required this.bloodType});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AegisColors.danger.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AegisRadius.md),
        border: Border.all(color: AegisColors.danger.withValues(alpha: 0.5)),
      ),
      child: bloodType.isEmpty
          ? const Icon(Icons.bloodtype_outlined, color: AegisColors.danger)
          : Text(bloodType,
              style: GoogleFonts.outfit(
                  fontSize: 18, fontWeight: FontWeight.bold, color: AegisColors.danger)),
    );
  }
}

/// Drop-in panel for the SOS / "Are you OK?" screens (Member 1): shows who is
/// being alerted and the medical info they receive.
///
/// ```dart
/// EmergencyInfoPanel(uid: FirebaseAuth.instance.currentUser!.uid)
/// ```
class EmergencyInfoPanel extends StatelessWidget {
  final String uid;
  const EmergencyInfoPanel({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final service = ContactsService();
    return StreamBuilder<List<ContactModel>>(
      stream: service.streamContacts(uid),
      builder: (context, contactsSnap) {
        return StreamBuilder<MedicalProfile>(
          stream: service.streamMedicalProfile(uid),
          builder: (context, medSnap) {
            final contacts = contactsSnap.data ?? const <ContactModel>[];
            final medical = medSnap.data ?? MedicalProfile.empty;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('ALERTING',
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.bold,
                        color: AegisColors.textSecondary)),
                const SizedBox(height: AegisSpacing.sm),
                if (contacts.isEmpty)
                  Text('No trusted contacts saved',
                      style: GoogleFonts.outfit(color: AegisColors.warning))
                else
                  Wrap(
                    spacing: AegisSpacing.sm,
                    runSpacing: AegisSpacing.sm,
                    children: contacts
                        .map((c) => Chip(
                              avatar: Icon(c.isPrimary ? Icons.star : Icons.person,
                                  size: 16,
                                  color: c.isPrimary
                                      ? AegisColors.primary
                                      : AegisColors.textSecondary),
                              label: Text('${c.name} · ${c.relation}'),
                            ))
                        .toList(),
                  ),
                if (medical.isNotEmpty) ...[
                  const SizedBox(height: AegisSpacing.lg),
                  MedicalSummaryCard(profile: medical),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
