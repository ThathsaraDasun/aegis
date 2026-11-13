import 'package:flutter/material.dart';
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

  /// Up to two initials for an avatar, e.g. "Jane Doe" -> "JD".
  static String initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.map((p) => p[0]).take(2).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AegisElevation.none,
      child: InkWell(
        onTap: onTap,
        borderRadius: AegisRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AegisSpacing.lg, vertical: AegisSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AegisColors.avatarFor(contact.name),
                child: Text(
                  initialsFor(contact.name),
                  style: AegisText.title.copyWith(color: AegisColors.onPrimary),
                ),
              ),
              const SizedBox(width: AegisSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contact.name, style: AegisText.bodyStrong),
                    const SizedBox(height: AegisSpacing.xxs),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: AegisSpacing.xxs,
                          ),
                          decoration: const BoxDecoration(
                            color: AegisColors.surfaceContainerHighest,
                            borderRadius: AegisRadius.xsAll,
                          ),
                          child: Text(
                            contact.relation,
                            style: AegisText.small.copyWith(fontSize: 10, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: AegisSpacing.sm),
                        Flexible(
                          child: Text(
                            contact.phone,
                            style: AegisText.small,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (contact.isPrimary)
                const Padding(
                  padding: EdgeInsets.only(right: AegisSpacing.sm),
                  child: Icon(Icons.star, color: AegisColors.primary, size: AegisSizes.iconMd),
                ),
              if (actionIcon != null)
                IconButton(
                  icon: Icon(actionIcon, color: AegisColors.textSecondary),
                  onPressed: onActionTap,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
