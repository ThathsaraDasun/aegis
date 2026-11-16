import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/contact_model.dart';
import '../../models/medical_profile_model.dart';
import '../../services/contacts_service.dart';
import '../../theme/aegis_theme.dart';
import '../../widgets/aegis_empty_state.dart';
import '../../widgets/contact_card.dart';
import 'add_edit_contact_screen.dart';
import 'medical_profile_screen.dart';
import 'widgets/medical_summary_card.dart';

/// Guardians tab: trusted contacts + emergency medical profile (Member 3).
class TrustedContactsListScreen extends StatefulWidget {
  const TrustedContactsListScreen({super.key});

  @override
  State<TrustedContactsListScreen> createState() =>
      _TrustedContactsListScreenState();
}

class _TrustedContactsListScreenState extends State<TrustedContactsListScreen> {
  final ContactsService _contactsService = ContactsService();

  /// Ids swiped away but not yet removed by the Firestore stream – hidden so
  /// the Dismissible leaves the tree immediately.
  final Set<String> _hidden = {};

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _openEditor([ContactModel? contact]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddEditContactScreen(contact: contact)),
    );
  }

  Future<void> _openMedical(MedicalProfile current) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MedicalProfileScreen(initial: current)),
    );
  }

  Future<void> _call(ContactModel c) async {
    final uri = Uri(scheme: 'tel', path: c.phone);
    final ok = await canLaunchUrl(uri) && await launchUrl(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the dialer for ${c.phone}')),
      );
    }
  }

  Future<bool> _confirmDelete(ContactModel c) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove guardian?'),
        content: Text('${c.name} will no longer receive your SOS alerts.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AegisColors.textSecondary),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AegisColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _delete(ContactModel c) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _hidden.add(c.id));
    try {
      await _contactsService.deleteContact(_uid, c.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text('${c.name} removed'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () async {
              await _contactsService.restoreContact(_uid, c);
              if (mounted) setState(() => _hidden.remove(c.id));
            },
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _hidden.remove(c.id));
      messenger.showSnackBar(
        SnackBar(content: Text('Could not remove contact: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    return Scaffold(
      backgroundColor: AegisColors.background,
      body: uid.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(AegisSpacing.lg),
              child: Center(
                child: AegisEmptyState(
                  icon: Icons.lock_outline,
                  title: 'Sign in to manage guardians',
                  message:
                      'Trusted contacts and medical info are saved to your account so they can be '
                      'alerted during an SOS. Demo mode has no account – sign in to add them.',
                ),
              ),
            )
          : StreamBuilder<List<ContactModel>>(
              stream: _contactsService.streamContacts(uid),
              builder: (context, contactSnap) {
                return StreamBuilder<MedicalProfile>(
                  stream: _contactsService.streamMedicalProfile(uid),
                  builder: (context, medSnap) {
                    if (contactSnap.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(AegisSpacing.lg),
                        child: Center(
                          child: AegisEmptyState(
                            icon: Icons.cloud_off,
                            iconColor: AegisColors.danger,
                            title: 'Couldn\'t load guardians',
                            message:
                                'Check your connection and try again.\n${contactSnap.error}',
                          ),
                        ),
                      );
                    }
                    if (!contactSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return _buildBody(
                      contactSnap.data!,
                      medSnap.data ?? MedicalProfile.empty,
                    );
                  },
                );
              },
            ),
      floatingActionButton: uid.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              backgroundColor: AegisColors.azure,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: const StadiumBorder(),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(
                'Add guardian',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
            ),
    );
  }

  Widget _buildBody(List<ContactModel> all, MedicalProfile medical) {
    final contacts = all.where((c) => !_hidden.contains(c.id)).toList();
    final primary = contacts.where((c) => c.isPrimary).toList();
    final others = contacts.where((c) => !c.isPrimary).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AegisSpacing.lg,
        AegisSpacing.lg,
        AegisSpacing.lg,
        96,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Guardians',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AegisColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your SOS network and medical info',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AegisColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Material(
              color: Colors.white,
              shape: const CircleBorder(
                side: BorderSide(color: AegisColors.surfaceContainerHighest),
              ),
              child: IconButton(
                tooltip: 'Add guardian',
                icon: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: AegisColors.azure,
                ),
                onPressed: () => _openEditor(),
              ),
            ),
          ],
        ),
        const SizedBox(height: AegisSpacing.lg),
        _GuardianSummaryCard(
          total: contacts.length,
          primary: primary.length,
          medicalReady: medical.isNotEmpty,
        ),
        const SizedBox(height: AegisSpacing.xl),
        if (contacts.isEmpty)
          AegisEmptyState(
            icon: Icons.people_outline,
            title: 'No guardians yet',
            message:
                'Add at least one primary guardian – they get your live location and an '
                'alert the moment an SOS or fall is detected.',
            actionLabel: 'Add your first guardian',
            actionIcon: Icons.person_add_alt_1,
            onAction: () => _openEditor(),
          )
        else ...[
          if (primary.isEmpty)
            const _InlineWarning(
              text:
                  'No primary guardian set. Mark someone as primary so they are alerted first.',
            ),
          if (primary.isNotEmpty) ...[
            const AegisSectionHeader(
              'Primary guardians · alerted first',
              color: AegisColors.primary,
            ),
            ...primary.map(_buildContactTile),
            const SizedBox(height: AegisSpacing.lg),
          ],
          if (others.isNotEmpty) ...[
            const AegisSectionHeader(
              'Other contacts',
              color: AegisColors.secondary,
            ),
            ...others.map(_buildContactTile),
          ],
          Padding(
            padding: const EdgeInsets.only(top: AegisSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.touch_app_outlined,
                  size: 14,
                  color: AegisColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Tap a guardian to edit · swipe left to remove',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AegisColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AegisSpacing.xl),
        AegisSectionHeader(
          'Emergency medical profile',
          trailing: TextButton.icon(
            onPressed: () => _openMedical(medical),
            icon: Icon(
              medical.isEmpty ? Icons.add : Icons.edit_outlined,
              size: 16,
            ),
            label: Text(medical.isEmpty ? 'Add' : 'Edit'),
          ),
        ),
        if (medical.isEmpty)
          AegisEmptyState(
            compact: true,
            icon: Icons.medical_information_outlined,
            iconColor: AegisColors.danger,
            title: 'No medical info added',
            message:
                'Optional – blood type, allergies and conditions are shown to your '
                'guardians only during an active SOS.',
            actionLabel: 'Add medical info',
            actionIcon: Icons.add,
            onAction: () => _openMedical(medical),
          )
        else
          MedicalSummaryCard(
            profile: medical,
            onTap: () => _openMedical(medical),
          ),
      ],
    );
  }

  Widget _buildContactTile(ContactModel c) {
    return Dismissible(
      key: ValueKey('contact-${c.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(c),
      onDismissed: (_) => _delete(c),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: AegisSpacing.xl),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AegisColors.danger,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white),
            SizedBox(width: 6),
            Text(
              'Remove',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      child: ContactCard(
        contact: c,
        onTap: () => _openEditor(c),
        actionIcon: Icons.call_outlined,
        onActionTap: () => _call(c),
      ),
    );
  }
}

class _GuardianSummaryCard extends StatelessWidget {
  final int total;
  final int primary;
  final bool medicalReady;

  const _GuardianSummaryCard({
    required this.total,
    required this.primary,
    required this.medicalReady,
  });

  @override
  Widget build(BuildContext context) {
    final ready = primary > 0;
    return Container(
      padding: const EdgeInsets.all(AegisSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AegisColors.azure, AegisColors.dodgerBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AegisColors.azure.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  ready ? Icons.verified_user_rounded : Icons.shield_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AegisSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ready ? 'SOS network ready' : 'Set up your SOS network',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ready
                          ? 'Your guardians will be alerted automatically.'
                          : 'Add a primary guardian to receive alerts.',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AegisSpacing.lg),
          Row(
            children: [
              _metric(
                Icons.people_alt_outlined,
                'Guardians',
                '$total/${ContactsService.maxContacts}',
                ok: total > 0,
              ),
              _metric(
                Icons.star_rounded,
                'Primary',
                '$primary',
                ok: primary > 0,
              ),
              _metric(
                Icons.medical_information_outlined,
                'Medical',
                medicalReady ? 'Added' : 'Missing',
                ok: medicalReady,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(
    IconData icon,
    String label,
    String value, {
    required bool ok,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              ok ? icon : Icons.error_outline_rounded,
              size: 18,
              color: ok ? AegisColors.azure : AegisColors.warning,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: ok ? AegisColors.textPrimary : AegisColors.warning,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                color: AegisColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  final String text;
  const _InlineWarning({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AegisSpacing.lg),
      padding: const EdgeInsets.all(AegisSpacing.md),
      decoration: BoxDecoration(
        color: AegisColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AegisColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AegisColors.warning, size: 18),
          const SizedBox(width: AegisSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AegisColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
