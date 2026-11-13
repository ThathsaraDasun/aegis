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

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.outfit(color: AegisColors.textSecondary),
      prefixIcon: Icon(icon, color: AegisColors.textSecondary, size: 20),
      filled: true,
      fillColor: AegisColors.surfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AegisColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AegisColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("Add Guardian & Medical Info", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Guardian Contact Details", 
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AegisColors.primary)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              style: GoogleFonts.outfit(color: Colors.white),
              decoration: _buildInputDecoration("Full Name (e.g. Elena Vance)", Icons.person_outline),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.outfit(color: Colors.white),
              decoration: _buildInputDecoration("Phone Number (+1 555-019-2834)", Icons.phone_outlined),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _relationController,
              style: GoogleFonts.outfit(color: Colors.white),
              decoration: _buildInputDecoration("Relationship (e.g. Mother, Spouse)", Icons.people_outline),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text("Set as Primary Tier 1 Guardian", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
              subtitle: Text("Primary guardians receive immediate SOS alerts.", style: GoogleFonts.outfit(fontSize: 12, color: AegisColors.textSecondary)),
              value: _isPrimaryGuardian,
              activeColor: AegisColors.primary,
              onChanged: (val) => setState(() => _isPrimaryGuardian = val),
            ),
            const SizedBox(height: 32),
            Text("Medical Info Profile (Optional)", 
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AegisColors.primary)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _bloodType,
              dropdownColor: AegisColors.surfaceContainerHigh,
              style: GoogleFonts.outfit(color: Colors.white),
              decoration: _buildInputDecoration("Blood Type", Icons.bloodtype_outlined),
              items: ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"]
                  .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (val) => setState(() => _bloodType = val!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _allergiesController,
              style: GoogleFonts.outfit(color: Colors.white),
              decoration: _buildInputDecoration("Allergies / Conditions", Icons.medical_services_outlined),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emergencyNoteController,
              maxLines: 3,
              style: GoogleFonts.outfit(color: Colors.white),
              decoration: _buildInputDecoration("Emergency Note", Icons.note_alt_outlined),
            ),
            const SizedBox(height: 40),
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
                label: Text("SAVE GUARDIAN & MEDICAL PROFILE", 
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AegisColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
