import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthAccount {
  final String uid;
  final String email;
  const AuthAccount(this.uid, this.email);
}

abstract class AuthService {
  Stream<AuthAccount?> authStateChanges();
  Future<void> signIn(String email, String password);
  Future<void> register(String email, String password);
  Future<void> signOut();
  Future<bool> hasProfile(String uid);
  Future<void> saveProfile(String uid, String name, String phone);
}

class FirebaseAuthService implements AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  FirebaseAuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<AuthAccount?> authStateChanges() => _auth.authStateChanges().map(
    (user) => user == null ? null : AuthAccount(user.uid, user.email ?? ''),
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
    await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> signOut() => _auth.signOut();

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
  if (error is FirebaseException) {
    return switch (error.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'The email or password is incorrect.',
      'invalid-email' => 'Enter a valid email address.',
      'email-already-in-use' =>
        'An account already uses this email. Please sign in.',
      'weak-password' =>
        'Choose a stronger password with at least 6 characters.',
      'user-disabled' =>
        'This account has been disabled. Contact the project team.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      'network-request-failed' || 'unavailable' =>
        'Unable to connect. Check your internet connection and try again.',
      'permission-denied' =>
        'Your profile could not be accessed. Contact the team to check database permissions.',
      'operation-not-allowed' =>
        'Email/password sign-in is not enabled for this app.',
      _ => 'Something went wrong. Please try again.',
    };
  }
  return 'Something went wrong. Please try again.';
}
