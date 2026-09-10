import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/contact_model.dart';
import '../../services/contacts_service.dart';
import '../../theme/aegis_theme.dart';
import 'add_edit_contact_screen.dart';

class TrustedContactsListScreen extends StatefulWidget {
  const TrustedContactsListScreen({super.key});

  @override
  State<TrustedContactsListScreen> createState() => _TrustedContactsListScreenState();
}

class _TrustedContactsListScreenState extends State<TrustedContactsListScreen> {
  bool _autoDialMom = true;
  bool _audioStreamMom = true;
  final ContactsService _contactsService = ContactsService();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AegisColors.background,
      appBar: AppBar(
        backgroundColor: AegisColors.surfaceContainerLow,
        title: Text("Guardian Network", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: AegisColors.primary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddEditContactScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<ContactModel>>(
        stream: uid.isNotEmpty ? _contactsService.streamContacts(uid) : Stream.value([]),
        builder: (context, snapshot) {
          final contacts = snapshot.data ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Guardian Circle Active Header Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AegisColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AegisColors.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.shield, color: AegisColors.tertiary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Guardian Circle",
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AegisColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    "${contacts.length} Guardians active in network",
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: AegisColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AegisColors.primaryContainer,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const AddEditContactScreen()),
                            ),
                            icon: const Icon(Icons.person_add, size: 16, color: Colors.white),
                            label: Text(
                              "Invite",
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildMetricTile("Avg Response", "14s", AegisColors.tertiary),
                          _buildMetricTile("Live Pings", "Optimal", AegisColors.primary),
                          _buildMetricTile("Escalation", "Auto 911", AegisColors.textPrimary),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Contacts list / Empty State
                Text(
                  "TIER 1 • PRIMARY RESPONDER",
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AegisColors.secondary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),

                if (contacts.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AegisColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.people_outline, color: AegisColors.textSecondary, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          "No contacts added yet",
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AegisColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Add primary emergency contacts to receive instant SOS alerts.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(fontSize: 12, color: AegisColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: contacts.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AegisColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 26,
                                  backgroundColor: AegisColors.primaryContainer,
                                  child: Icon(Icons.face, color: Colors.white, size: 30),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            "${contact.name} (${contact.relation})",
                                            style: GoogleFonts.outfit(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AegisColors.textPrimary,
                                            ),
                                          ),
                                          if (contact.isPrimary) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AegisColors.tertiaryContainer,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                "PRIMARY",
                                                style: GoogleFonts.outfit(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: AegisColors.tertiary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      Text(
                                        "${contact.phone} • ${contact.relation}",
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: AegisColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AegisColors.primary),
                                  onPressed: () {
                                    if (uid.isNotEmpty) {
                                      _contactsService.deleteContact(uid, contact.id);
                                    }
                                  },
                                ),
                              ],
                            ),
                            const Divider(color: AegisColors.surfaceContainerHighest, height: 24),
                            SwitchListTile(
                              title: Text(
                                "Instant SOS Auto-Dial",
                                style: GoogleFonts.outfit(fontSize: 13, color: AegisColors.textPrimary),
                              ),
                              value: _autoDialMom,
                              activeThumbColor: AegisColors.primary,
                              onChanged: (val) => setState(() => _autoDialMom = val),
                              contentPadding: EdgeInsets.zero,
                            ),
                            SwitchListTile(
                              title: Text(
                                "Ambient Audio Stream",
                                style: GoogleFonts.outfit(fontSize: 13, color: AegisColors.textPrimary),
                              ),
                              value: _audioStreamMom,
                              activeThumbColor: AegisColors.primary,
                              onChanged: (val) => setState(() => _audioStreamMom = val),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 24),
                // Emergency Medical Profile Summary
                Text(
                  "EMERGENCY MEDICAL PROFILE",
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AegisColors.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AegisColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Blood Type: O+",
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: AegisColors.primary,
                            ),
                          ),
                          Text(
                            "Allergies: Penicillin",
                            style: GoogleFonts.outfit(color: AegisColors.secondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Emergency Note: Contact primary responders first during automated SOS escalation.",
                        style: GoogleFonts.outfit(fontSize: 12, color: AegisColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color valueColor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AegisColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.outfit(fontSize: 10, color: AegisColors.textSecondary)),
            const SizedBox(height: 2),
            Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor)),
          ],
        ),
      ),
    );
  }
}
