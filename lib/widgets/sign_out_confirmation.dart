import 'package:flutter/material.dart';

/// Dismissing the dialog (including Android Back) keeps the account signed in.
Future<bool> confirmSignOut(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Sign out?'),
          content: const Text('Are you sure you want to sign out of your account?'),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ) ==
      true;
}
