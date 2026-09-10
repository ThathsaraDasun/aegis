import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/contact_model.dart';
import '../../services/contacts_service.dart';
import '../../theme/aegis_theme.dart';

class AddEditContactScreen extends StatefulWidget {
  const AddEditContactScreen({super.key});

  @override
  State<AddEditContactScreen> createState() => _AddEditContactScreenState();
}

class _AddEditContactScreenState extends State<AddEditContactScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _relationController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _emergencyNoteController = TextEditingController();
  String _bloodType = "O+";
  bool _isPrimaryGuardian = true;
  bool _isLoading = false;
  final ContactsService _contactsService = ContactsService();

  Future<void> _saveContactAndMedicalProfile() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final relation = _relationController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter full name and phone number.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isNotEmpty) {
        final newContact = ContactModel(
          id: '',
          name: name,
          phone: phone,
          relation: relation.isNotEmpty ? relation : 'Contact',
          bloodType: _bloodType,
          isPrimary: _isPrimaryGuardian,
        );

        await _contactsService.addContact(uid, newContact);

        await _contactsService.updateMedicalProfile(
          uid,
          bloodType: _bloodType,
          allergies: _allergiesController.text.trim(),
          emergencyNote: _emergencyNoteController.text.trim(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Guardian and Medical Profile Saved!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving contact: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AegisColors.background,
      appBar: AppBar(
        title: Text("Add Guardian & Medical Info", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Guardian Contact Details", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AegisColors.textPrimary)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Full Name (e.g. Elena Vance)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Phone Number (+1 555-019-2834)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _relationController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Relationship (e.g. Mother, Spouse, Doctor)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text("Set as Primary Tier 1 Guardian", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
              subtitle: Text("Primary guardians receive immediate phone call & live video stream during SOS.", style: GoogleFonts.outfit(fontSize: 12, color: AegisColors.textSecondary)),
              value: _isPrimaryGuardian,
              activeThumbColor: AegisColors.primary,
              onChanged: (val) => setState(() => _isPrimaryGuardian = val),
            ),
            const SizedBox(height: 24),
            Text("Medical Info Profile (Optional)", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AegisColors.textPrimary)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _bloodType,
              dropdownColor: AegisColors.surfaceContainerHigh,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Blood Type", border: OutlineInputBorder()),
              items: ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"]
                  .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (val) => setState(() => _bloodType = val!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _allergiesController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Allergies / Conditions (e.g. Penicillin, Asthma)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emergencyNoteController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Emergency Note for Responders", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveContactAndMedicalProfile,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save, color: Colors.white),
                label: Text("SAVE GUARDIAN & MEDICAL PROFILE", style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
