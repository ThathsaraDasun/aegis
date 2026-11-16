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

  @override
  Widget build(BuildContext context) {
    final String initials = contact.name.isNotEmpty
        ? contact.name
              .trim()
              .split(' ')
              .where((e) => e.isNotEmpty)
              .map((e) => e[0])
              .take(2)
              .join()
              .toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: contact.isPrimary
              ? AegisColors.azure.withValues(alpha: 0.35)
              : AegisColors.surfaceContainerHigh,
        ),
        boxShadow: [
          BoxShadow(
            color: AegisColors.azure.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AegisColors.azure, AegisColors.dodgerBlue],
                        ),
                      ),
                      child: Text(
                        initials,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    if (contact.isPrimary)
                      Positioned(
                        right: -3,
                        bottom: -3,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AegisColors.surfaceContainerHigh,
                            ),
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            color: AegisColors.azure,
                            size: 15,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: AegisColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (contact.relation.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AegisColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                contact.relation,
                                style: GoogleFonts.outfit(
                                  color: AegisColors.azure,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.phone_outlined,
                                size: 13,
                                color: AegisColors.textSecondary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                contact.phone,
                                style: GoogleFonts.outfit(
                                  color: AegisColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (actionIcon != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Material(
                      color: AegisColors.azure.withValues(alpha: 0.10),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Call ${contact.name}',
                        icon: Icon(actionIcon, color: AegisColors.azure),
                        onPressed: onActionTap,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
