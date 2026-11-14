import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/contact_model.dart';
import '../../services/contacts_service.dart';
import '../../theme/aegis_theme.dart';
import '../../widgets/aegis_empty_state.dart';

/// Add a new trusted contact, or edit / remove an existing one.
class AddEditContactScreen extends StatefulWidget {
  /// Pass an existing contact to edit it; null to add a new one.
  final ContactModel? contact;

  const AddEditContactScreen({super.key, this.contact});

  @override
  State<AddEditContactScreen> createState() => _AddEditContactScreenState();
}

class _AddEditContactScreenState extends State<AddEditContactScreen> {
  static const _relations = ['Mother', 'Father', 'Spouse', 'Sibling', 'Friend', 'Partner', 'Colleague'];

  final _formKey = GlobalKey<FormState>();
  final ContactsService _contactsService = ContactsService();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _relationController;
  late bool _isPrimary;
  bool _isSaving = false;

  bool get _isEditing => widget.contact != null;

  @override
  void initState() {
    super.initState();
    final c = widget.contact;
    _nameController = TextEditingController(text: c?.name ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _relationController = TextEditingController(text: c?.relation ?? '');
    _isPrimary = c?.isPrimary ?? true;
    _relationController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationController.dispose();
    super.dispose();
  }

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_uid.isEmpty) {
      _snack('Sign in to save guardians.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    final contact = ContactModel(
      id: widget.contact?.id ?? '',
      name: _nameController.text.trim().replaceAll(RegExp(r'\s+'), ' '),
      phone: ContactsService.normalizePhone(_phoneController.text),
      relation: _relationController.text.trim().isEmpty ? 'Contact' : _relationController.text.trim(),
      isPrimary: _isPrimary,
    );

    try {
      if (_isEditing) {
        await _contactsService.updateContact(_uid, contact);
      } else {
        await _contactsService.addContact(_uid, contact);
      }
      if (!mounted) return;
      _snack(_isEditing ? '${contact.name} updated' : '${contact.name} added as a guardian');
      Navigator.pop(context, true);
    } catch (e) {
      _snack('Could not save contact: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final c = widget.contact;
    if (c == null) return;
    final confirm = await showDialog<bool>(
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
    if (confirm != true) return;
    setState(() => _isSaving = true);
    try {
      await _contactsService.deleteContact(_uid, c.id);
      if (!mounted) return;
      _snack('${c.name} removed');
      Navigator.pop(context, true);
    } catch (e) {
      _snack('Could not remove contact: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Guardian' : 'Add Guardian'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.delete_outline, color: AegisColors.danger),
              onPressed: _isSaving ? null : _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AegisSpacing.xl),
            children: [
              Center(child: _AvatarPreview(name: _nameController.text)),
              const SizedBox(height: AegisSpacing.xl),
              const AegisSectionHeader('Contact details'),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  hintText: 'e.g. Nimali Perera',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().length < 2) ? 'Enter the contact\'s name' : null,
              ),
              const SizedBox(height: AegisSpacing.lg),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '+94 77 123 4567',
                  helperText: 'Local numbers (07…) are saved as +94',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: ContactsService.validatePhone,
              ),
              const SizedBox(height: AegisSpacing.lg),
              TextFormField(
                controller: _relationController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Relationship',
                  hintText: 'Pick below or type your own',
                  prefixIcon: Icon(Icons.people_outline),
                ),
              ),
              const SizedBox(height: AegisSpacing.md),
              Wrap(
                spacing: AegisSpacing.sm,
                runSpacing: AegisSpacing.sm,
                children: _relations
                    .map((r) => ChoiceChip(
                          label: Text(r),
                          selected: _relationController.text.trim() == r,
                          onSelected: (_) => _relationController.text = r,
                        ))
                    .toList(),
              ),
              const SizedBox(height: AegisSpacing.xl),
              Container(
                decoration: BoxDecoration(
                  color: AegisColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AegisRadius.lg),
                  border: Border.all(
                    color: _isPrimary
                        ? AegisColors.primary.withValues(alpha: 0.6)
                        : AegisColors.surfaceContainerHighest,
                  ),
                ),
                child: SwitchListTile(
                  value: _isPrimary,
                  onChanged: (v) => setState(() => _isPrimary = v),
                  secondary: Icon(Icons.star_rounded,
                      color: _isPrimary ? AegisColors.primary : AegisColors.textSecondary),
                  title: Text('Primary guardian',
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold, color: AegisColors.textPrimary)),
                  subtitle: Text('Alerted first with your live location during an SOS.',
                      style: GoogleFonts.outfit(fontSize: 12, color: AegisColors.textSecondary)),
                ),
              ),
              const SizedBox(height: AegisSpacing.xxl),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(_isEditing ? Icons.check : Icons.person_add_alt_1),
                  label: Text(_isEditing ? 'Save changes' : 'Add guardian'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarPreview extends StatelessWidget {
  final String name;
  const _AvatarPreview({required this.name});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty ? '' : parts.take(2).map((p) => p[0]).join().toUpperCase();
    return CircleAvatar(
      radius: 40,
      backgroundColor: AegisColors.primary.withValues(alpha: 0.2),
      child: initials.isEmpty
          ? const Icon(Icons.person_add_alt_1, color: AegisColors.primary, size: 32)
          : Text(initials,
              style: GoogleFonts.outfit(
                  fontSize: 28, fontWeight: FontWeight.bold, color: AegisColors.primary)),
    );
  }
}
