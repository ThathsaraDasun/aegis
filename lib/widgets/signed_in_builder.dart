import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Rebuilds whenever the Firebase user signs in or out, so screens kept alive
/// in the bottom-navigation IndexedStack never show a stale signed-out state.
class SignedInBuilder extends StatelessWidget {
  const SignedInBuilder({super.key, required this.signedIn, required this.signedOut});

  /// Built with the current user once someone is signed in.
  final Widget Function(BuildContext context, User user) signedIn;

  /// Shown while nobody is signed in.
  final Widget signedOut;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        return user == null ? signedOut : signedIn(context, user);
      },
    );
  }
}
