import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/contact_model.dart';
import '../theme/aegis_theme.dart';

/// A list item widget representing a guardian or emergency contact.
class ContactCard extends StatelessWidget {
  /// The contact data to display.
  final ContactModel contact;
  
  /// Callback when the card is tapped.
  final VoidCallback? onTap;
  
  /// Optional callback for the trailing action (e.g. call button).
  final VoidCallback? onActionTap;
  
  /// The icon to show as a trailing action.
  final IconData? actionIcon;

  const ContactCard({
    super.key,
    required this.contact,
    this.onTap,
    this.onActionTap,
    this.actionIcon,
  });

  /// Generates a consistent background color for the avatar based on the name.
  Color _getAvatarColor(String name) {
    final int hash = name.hashCode;
    final List<Color> colors = [
      Colors.blueAccent,
      Colors.orangeAccent,
      Colors.greenAccent,
      Colors.purpleAccent,
      Colors.redAccent,
      Colors.tealAccent,
      Colors.indigoAccent,
    ];
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final String initials = contact.name.isNotEmpty 
        ? contact.name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: AegisColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _getAvatarColor(contact.name),
                  child: Text(
                    initials,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: GoogleFonts.outfit(
                          color: AegisColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AegisColors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              contact.relation,
                              style: GoogleFonts.inter(
                                color: AegisColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            contact.phone,
                            style: GoogleFonts.inter(
                              color: AegisColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (actionIcon != null || contact.isPrimary)
                  Row(
                    children: [
                      if (contact.isPrimary)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.star,
                            color: AegisColors.primary,
                            size: 18,
                          ),
                        ),
                      if (actionIcon != null)
                        IconButton(
                          icon: Icon(actionIcon, color: AegisColors.textSecondary),
                          onPressed: onActionTap,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
