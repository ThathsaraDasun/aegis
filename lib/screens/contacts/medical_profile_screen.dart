import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/medical_profile_model.dart';
import '../../services/contacts_service.dart';
import '../../theme/aegis_theme.dart';
import '../../widgets/aegis_empty_state.dart';
import 'widgets/medical_summary_card.dart';

/// Edit the optional medical info that guardians see during an SOS.
class MedicalProfileScreen extends StatefulWidget {
  final MedicalProfile initial;

  const MedicalProfileScreen({super.key, this.initial = MedicalProfile.empty});

  @override
  State<MedicalProfileScreen> createState() => _MedicalProfileScreenState();
}

class _MedicalProfileScreenState extends State<MedicalProfileScreen> {
  final ContactsService _service = ContactsService();
  late final TextEditingController _allergies;
  late final TextEditingController _conditions;
  late final TextEditingController _note;
  late String _bloodType;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _allergies = TextEditingController(text: widget.initial.allergies);
    _conditions = TextEditingController(text: widget.initial.conditions);
    _note = TextEditingController(text: widget.initial.emergencyNote);
    _bloodType = widget.initial.bloodType;
    for (final c in [_allergies, _conditions, _note]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _allergies.dispose();
    _conditions.dispose();
    _note.dispose();
    super.dispose();
  }

  MedicalProfile get _draft => MedicalProfile(
        bloodType: _bloodType,
        allergies: _allergies.text.trim(),
        conditions: _conditions.text.trim(),
        emergencyNote: _note.text.trim(),
      );

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save your medical profile.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.saveMedicalProfile(uid, _draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medical profile saved')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medical Info')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AegisSpacing.xl),
          children: [
            Container(
              padding: const EdgeInsets.all(AegisSpacing.md),
              decoration: BoxDecoration(
                color: AegisColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AegisRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, color: AegisColors.secondary, size: 18),
                  const SizedBox(width: AegisSpacing.sm),
                  Expanded(
                    child: Text(
                      'All fields are optional. Guardians only see this while an SOS is active.',
                      style: GoogleFonts.outfit(fontSize: 12, color: AegisColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AegisSpacing.xl),
            const AegisSectionHeader('Blood type'),
            Wrap(
              spacing: AegisSpacing.sm,
              runSpacing: AegisSpacing.sm,
              children: [
                ...MedicalProfile.bloodTypes.map((t) => ChoiceChip(
                      label: Text(t),
                      selected: _bloodType == t,
                      onSelected: (sel) => setState(() => _bloodType = sel ? t : ''),
                    )),
                ChoiceChip(
                  label: const Text("Don't know"),
                  selected: _bloodType.isEmpty,
                  onSelected: (_) => setState(() => _bloodType = ''),
                ),
              ],
            ),
            const SizedBox(height: AegisSpacing.xl),
            const AegisSectionHeader('Details'),
            TextField(
              controller: _allergies,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Allergies',
                hintText: 'e.g. Penicillin, peanuts',
                prefixIcon: Icon(Icons.warning_amber_rounded),
              ),
            ),
            const SizedBox(height: AegisSpacing.lg),
            TextField(
              controller: _conditions,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Medical conditions',
                hintText: 'e.g. Asthma, diabetes (insulin)',
                prefixIcon: Icon(Icons.healing_outlined),
              ),
            ),
            const SizedBox(height: AegisSpacing.lg),
            TextField(
              controller: _note,
              maxLines: 3,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Emergency note',
                hintText: 'e.g. Contact mother first. Inhaler in left pocket.',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 48),
                  child: Icon(Icons.sticky_note_2_outlined),
                ),
              ),
            ),
            const SizedBox(height: AegisSpacing.lg),
            const AegisSectionHeader('Preview · what guardians see'),
            _draft.isEmpty
                ? const AegisEmptyState(
                    compact: true,
                    icon: Icons.visibility_off_outlined,
                    title: 'Nothing to share yet',
                    message: 'Guardians will only receive your live location.',
                  )
                : MedicalSummaryCard(profile: _draft),
            const SizedBox(height: AegisSpacing.xl),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Save medical info'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
