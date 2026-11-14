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
  State<TrustedContactsListScreen> createState() => _TrustedContactsListScreenState();
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
            child: const Text('Cancel', style: TextStyle(color: AegisColors.textSecondary)),
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
      messenger.showSnackBar(SnackBar(content: Text('Could not remove contact: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardian Network'),
        actions: [
          if (uid.isNotEmpty)
            IconButton(
              tooltip: 'Add guardian',
              icon: const Icon(Icons.person_add_alt_1, color: AegisColors.primary),
              onPressed: () => _openEditor(),
            ),
        ],
      ),
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
                            message: 'Check your connection and try again.\n${contactSnap.error}',
                          ),
                        ),
                      );
                    }
                    if (!contactSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return _buildBody(contactSnap.data!, medSnap.data ?? MedicalProfile.empty);
                  },
                );
              },
            ),
      floatingActionButton: uid.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.person_add_alt_1),
              label: Text('Add guardian', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ),
    );
  }

  Widget _buildBody(List<ContactModel> all, MedicalProfile medical) {
    final contacts = all.where((c) => !_hidden.contains(c.id)).toList();
    final primary = contacts.where((c) => c.isPrimary).toList();
    final others = contacts.where((c) => !c.isPrimary).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(AegisSpacing.lg, AegisSpacing.lg, AegisSpacing.lg, 96),
      children: [
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
            message: 'Add at least one primary guardian – they get your live location and an '
                'alert the moment an SOS or fall is detected.',
            actionLabel: 'Add your first guardian',
            actionIcon: Icons.person_add_alt_1,
            onAction: () => _openEditor(),
          )
        else ...[
          if (primary.isEmpty)
            const _InlineWarning(
              text: 'No primary guardian set. Mark someone as primary so they are alerted first.',
            ),
          if (primary.isNotEmpty) ...[
            const AegisSectionHeader('Primary guardians · alerted first', color: AegisColors.primary),
            ...primary.map(_buildContactTile),
            const SizedBox(height: AegisSpacing.lg),
          ],
          if (others.isNotEmpty) ...[
            const AegisSectionHeader('Other contacts', color: AegisColors.secondary),
            ...others.map(_buildContactTile),
          ],
          Padding(
            padding: const EdgeInsets.only(top: AegisSpacing.sm),
            child: Text(
              'Tip: tap a guardian to edit · swipe left to remove',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 11, color: AegisColors.textSecondary),
            ),
          ),
        ],
        const SizedBox(height: AegisSpacing.xl),
        AegisSectionHeader(
          'Emergency medical profile',
          trailing: TextButton.icon(
            onPressed: () => _openMedical(medical),
            icon: Icon(medical.isEmpty ? Icons.add : Icons.edit_outlined, size: 16),
            label: Text(medical.isEmpty ? 'Add' : 'Edit'),
          ),
        ),
        if (medical.isEmpty)
          AegisEmptyState(
            compact: true,
            icon: Icons.medical_information_outlined,
            iconColor: AegisColors.danger,
            title: 'No medical info added',
            message: 'Optional – blood type, allergies and conditions are shown to your '
                'guardians only during an active SOS.',
            actionLabel: 'Add medical info',
            actionIcon: Icons.add,
            onAction: () => _openMedical(medical),
          )
        else
          MedicalSummaryCard(profile: medical, onTap: () => _openMedical(medical)),
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
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        padding: const EdgeInsets.only(right: AegisSpacing.xl),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AegisColors.danger.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(AegisRadius.lg),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
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
        gradient: LinearGradient(
          colors: [
            (ready ? AegisColors.tertiaryContainer : AegisColors.primaryContainer)
                .withValues(alpha: 0.55),
            AegisColors.surfaceContainerHigh,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AegisRadius.xl),
        border: Border.all(
          color: (ready ? AegisColors.tertiary : AegisColors.primary).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (ready ? AegisColors.tertiary : AegisColors.primary)
                      .withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AegisRadius.md),
                ),
                child: Icon(
                  ready ? Icons.verified_user : Icons.shield_outlined,
                  color: ready ? AegisColors.tertiary : AegisColors.primary,
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
                          fontSize: 17, fontWeight: FontWeight.bold, color: AegisColors.textPrimary),
                    ),
                    Text(
                      ready
                          ? 'Your guardians will be alerted automatically.'
                          : 'Add a primary guardian to receive alerts.',
                      style: GoogleFonts.outfit(fontSize: 12, color: AegisColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AegisSpacing.lg),
          Row(
            children: [
              _metric('Guardians', '$total/${ContactsService.maxContacts}', AegisColors.textPrimary),
              _metric('Primary', '$primary', primary > 0 ? AegisColors.tertiary : AegisColors.warning),
              _metric('Medical', medicalReady ? 'Added' : 'Missing',
                  medicalReady ? AegisColors.tertiary : AegisColors.warning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AegisColors.surfaceContainerLow.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(AegisRadius.md),
        ),
        child: Column(
          children: [
            Text(value,
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.outfit(fontSize: 11, color: AegisColors.textSecondary)),
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
        color: AegisColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AegisRadius.md),
        border: Border.all(color: AegisColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AegisColors.warning, size: 18),
          const SizedBox(width: AegisSpacing.sm),
          Expanded(
            child: Text(text,
                style: GoogleFonts.outfit(fontSize: 12, color: AegisColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
