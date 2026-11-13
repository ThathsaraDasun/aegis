import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/activity_service.dart';
import '../../theme/aegis_theme.dart';
import '../../widgets/state_views.dart';

/// Form for editing the profile and emergency medical info of the user.
/// Saves to Firestore 'users/{uid}'.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.user, this.service});

  final UserModel user;
  final ActivityService? service;

  static Future<void> open(BuildContext context, UserModel user) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditProfileScreen(user: user)),
    );
  }

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const List<String> _bloodTypes = ['', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _allergies;
  late final TextEditingController _note;
  late String _bloodType;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.name);
    _phone = TextEditingController(text: widget.user.phone);
    _allergies = TextEditingController(text: widget.user.allergies);
    _note = TextEditingController(text: widget.user.emergencyNote);
    _bloodType = _bloodTypes.contains(widget.user.bloodType) ? widget.user.bloodType : '';
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _allergies.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await (widget.service ?? ActivityService()).saveUser(UserModel(
        userId: widget.user.userId,
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        bloodType: _bloodType,
        allergies: _allergies.text.trim(),
        emergencyNote: _note.text.trim(),
      ));
      messenger.showSnackBar(const SnackBar(content: Text('Profile saved.')));
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save profile: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AegisSpacing.screen,
          children: [
            const SectionHeader('Personal Details'),
            TextFormField(
              controller: _name,
              style: AegisText.body,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
            ),
            const SizedBox(height: AegisSpacing.lg),
            TextFormField(
              controller: _phone,
              style: AegisText.body,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: '+94771234567',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return null;
                return RegExp(r'^\+?[0-9 ]{7,15}$').hasMatch(value) ? null : 'Enter a valid phone number';
              },
            ),
            const SizedBox(height: AegisSpacing.xxl),
            const SectionHeader('Emergency Medical Info', color: AegisColors.primary),
            DropdownButtonFormField<String>(
              initialValue: _bloodType,
              style: AegisText.body,
              dropdownColor: AegisColors.surfaceContainerHigh,
              decoration: const InputDecoration(
                labelText: 'Blood Type',
                prefixIcon: Icon(Icons.bloodtype_outlined),
              ),
              items: _bloodTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.isEmpty ? 'Not set' : t)))
                  .toList(),
              onChanged: (v) => setState(() => _bloodType = v ?? ''),
            ),
            const SizedBox(height: AegisSpacing.lg),
            TextFormField(
              controller: _allergies,
              style: AegisText.body,
              decoration: const InputDecoration(
                labelText: 'Allergies',
                hintText: 'e.g. Penicillin, Peanuts',
                prefixIcon: Icon(Icons.medical_services_outlined),
              ),
            ),
            const SizedBox(height: AegisSpacing.lg),
            TextFormField(
              controller: _note,
              style: AegisText.body,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Emergency Note',
                hintText: 'e.g. Contact mother first',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
            ),
            const SizedBox(height: AegisSpacing.xs),
            Text(
              'This information is shared with your trusted contacts during an active SOS.',
              style: AegisText.small,
            ),
            const SizedBox(height: AegisSpacing.xxxl),
            SizedBox(
              width: double.infinity,
              height: AegisSizes.buttonHeight,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AegisColors.onPrimary),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Save Profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
