import 'package:flutter/material.dart';
import '../theme/aegis_theme.dart';

/// Shared empty-state view used by list screens (no trips, no alerts, etc).
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AegisSpacing.xxxl),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: AegisSizes.iconXl,
              color: AegisColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AegisSpacing.lg),
            Text(message, textAlign: TextAlign.center, style: AegisText.bodySecondary),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AegisSpacing.xxl),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shared error view with an optional retry button.
class ErrorStateView extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;

  const ErrorStateView({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AegisSpacing.xxxl),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: AegisSizes.iconXl, color: AegisColors.primary),
            const SizedBox(height: AegisSpacing.lg),
            Text('Oops! Something went wrong.', style: AegisText.title),
            const SizedBox(height: AegisSpacing.sm),
            Text(error, textAlign: TextAlign.center, style: AegisText.bodySecondary),
            if (onRetry != null) ...[
              const SizedBox(height: AegisSpacing.xxl),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Centered loading spinner in the brand colour.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(color: AegisColors.primary));
  }
}

/// Uppercase section header ("RECENT TRIPS", "EMERGENCY MEDICAL PROFILE").
class SectionHeader extends StatelessWidget {
  final String text;
  final Color? color;

  const SectionHeader(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AegisSpacing.md),
      child: Text(
        text.toUpperCase(),
        style: color == null ? AegisText.sectionHeader : AegisText.sectionHeader.copyWith(color: color),
      ),
    );
  }
}

/// Small coloured status pill ("COMPLETED", "ESCALATED").
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const StatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: AegisSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AegisRadius.pillAll,
      ),
      child: Text(label.toUpperCase(), style: AegisText.chip(color)),
    );
  }
}
