import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'live_sharing_service.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthAccount {
  final String uid;
  final String email;

  /// Whether the user has confirmed their email via the verification link.
  final bool emailVerified;
  const AuthAccount(this.uid, this.email, {this.emailVerified = true});
}

abstract class AuthService {
  Stream<AuthAccount?> authStateChanges();
  Future<void> signIn(String email, String password);

  /// Creates the account and sends the email verification link.
  Future<void> register(String email, String password);
  Future<void> sendPasswordResetEmail(String email);
  Future<void> signOut();
  Future<bool> hasProfile(String uid);
  Future<void> saveProfile(String uid, String name, String phone);

  /// (Re)sends the verification link to the signed-in user's email.
  Future<void> sendEmailVerification();

  /// When a verification link was last sent to [uid] from this phone, or
  /// null if never (e.g. an account created before verification existed).
  Future<DateTime?> verificationSentAt(String uid);

  /// Reloads the signed-in user and returns whether the email is verified.
  Future<bool> refreshEmailVerified();
}

class FirebaseAuthService implements AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  FirebaseAuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  /// Uses `userChanges` so a reload after the user taps the verification link
  /// immediately updates [AuthAccount.emailVerified].
  @override
  Stream<AuthAccount?> authStateChanges() => _auth.userChanges().map(
    (user) => user == null
        ? null
        : AuthAccount(
            user.uid,
            user.email ?? '',
            emailVerified: user.emailVerified,
          ),
  );

  @override
  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> register(String email, String password) async {
    // Profile setup is a recoverable second step after Firebase signs in.
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    // Send the verification link straight away. If this fails (e.g. offline),
    // the verify screen sends it again because no send time was recorded.
    final user = credential.user;
    if (user == null) return;
    try {
      await user.sendEmailVerification();
      await _recordVerificationSent(user.uid);
    } catch (_) {}
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in first.');
    await user.sendEmailVerification();
    await _recordVerificationSent(user.uid);
  }

  static String _sentKey(String uid) => 'verification_sent_$uid';

  Future<void> _recordVerificationSent(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_sentKey(uid), DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  @override
  Future<DateTime?> verificationSentAt(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_sentKey(uid));
      return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> refreshEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  @override
  Future<void> signOut() async {
    await LiveSharingService.stop();
    await _auth.signOut();
  }

  @override
  Future<bool> hasProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return (doc.data()?['name'] as String? ?? '').trim().isNotEmpty;
  }

  @override
  Future<void> saveProfile(String uid, String name, String phone) async {
    if (_auth.currentUser?.uid != uid) {
      throw StateError('The signed-in account changed. Please sign in again.');
    }
    // Merge identity fields only: never overwrite medical information or tokens.
    await _db.collection('users').doc(uid).set({
      'userId': uid,
      'name': name.trim(),
      'phone': phone.trim(),
    }, SetOptions(merge: true));
  }
}

String authErrorMessage(Object error) {
  if (error is PlatformException && error.code == 'sharing_stop_pending') {
    return error.message ?? 'Reconnect to finish stopping location sharing.';
  }
  if (error is FirebaseException) {
    return switch (error.code) {
      'invalid-credential' ||
      'wrong-password' => 'The email or password is incorrect.',
      'user-not-found' => 'No account was found with that email address.',
      'invalid-email' => 'Enter a valid email address.',
      'email-already-in-use' =>
        'An account already uses this email. Please sign in.',
      'weak-password' =>
        'Choose a stronger password: at least 8 characters with upper and lower case letters, a number and a symbol.',
      'user-disabled' =>
        'This account has been disabled. Contact the project team.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      'network-request-failed' || 'unavailable' =>
        'Unable to connect. Check your internet connection and try again.',
      'permission-denied' =>
        'Database access was denied. Contact the team to check account and database permissions.',
      'operation-not-allowed' =>
        'Email/password sign-in is not enabled for this app.',
      _ => 'Something went wrong. Please try again.',
    };
  }
  return 'Something went wrong. Please try again.';
}
