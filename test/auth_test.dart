import 'dart:async';
import 'package:aegis/screens/auth/auth_gate.dart';
import 'package:aegis/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthService implements AuthService {
  final changes = StreamController<AuthAccount?>.broadcast();
  AuthAccount? account;
  bool profile = true;
  bool failSignIn = false;
  bool failProfile = false;
  bool failCheck = false;
  int signInCalls = 0;
  int registerCalls = 0;
  int verificationEmails = 0;
  DateTime? sentAt;
  bool verified = true;
  int resetPasswordCalls = 0;
  String? resetPasswordEmail;
  bool failResetPassword = false;
  String? passwordReceived;
  String? nameSaved;
  @override
  Stream<AuthAccount?> authStateChanges() async* {
    yield account;
    yield* changes.stream;
  }

  @override
  Future<void> signIn(String email, String password) async {
    signInCalls++;
    passwordReceived = password;
    if (failSignIn) throw FirebaseAuthException(code: 'invalid-credential');
    account = AuthAccount('user-1', email, emailVerified: verified);
    changes.add(account);
  }

  @override
  Future<void> register(String email, String password) async {
    registerCalls++;
    profile = false;
    verified = false;
    verificationEmails++;
    sentAt = DateTime.now();
    await signIn(email, password);
  }

  @override
  Future<void> sendEmailVerification() async {
    verificationEmails++;
    sentAt = DateTime.now();
  }

  @override
  Future<DateTime?> verificationSentAt(String uid) async => sentAt;

  @override
  Future<bool> refreshEmailVerified() async {
    final current = account;
    if (current != null && current.emailVerified != verified) {
      account = AuthAccount(
        current.uid,
        current.email,
        emailVerified: verified,
      );
      changes.add(account);
    }
    return verified;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    resetPasswordCalls++;
    resetPasswordEmail = email;
    if (failResetPassword) {
      throw FirebaseAuthException(code: 'user-not-found');
    }
  }

  @override
  Future<void> signOut() async {
    account = null;
    changes.add(null);
  }

  @override
  Future<bool> hasProfile(String uid) async {
    if (failCheck) {
      throw FirebaseException(plugin: 'firestore', code: 'permission-denied');
    }
    return profile;
  }

  @override
  Future<void> saveProfile(String uid, String name, String phone) async {
    if (failProfile) {
      throw FirebaseException(plugin: 'firestore', code: 'unavailable');
    }
    profile = true;
    nameSaved = name;
  }
}

Future<void> mount(WidgetTester tester, FakeAuthService service) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AuthGate(
        service: service,
        signedInBuilder: (context) => Scaffold(
          body: Column(
            children: [
              const Text('Protected dashboard'),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const Scaffold(body: Text('Private detail')),
                  ),
                ),
                child: const Text('Open detail'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const strongPassword = 'Safe#Walk2026';

Future<void> credentials(
  WidgetTester tester, {
  String password = 'secret123',
}) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Email address'),
    'test@example.com',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password'),
    password,
  );
}

void main() {
  testWidgets('invalid input does not call authentication', (tester) async {
    final service = FakeAuthService();
    addTearDown(service.changes.close);
    await mount(tester, service);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(service.signInCalls, 0);
    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('failed login stays signed out; passwords are not trimmed', (
    tester,
  ) async {
    final service = FakeAuthService()..failSignIn = true;
    addTearDown(service.changes.close);
    await mount(tester, service);
    await credentials(tester, password: ' secret123 ');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(service.passwordReceived, ' secret123 ');
    expect(find.text('The email or password is incorrect.'), findsOneWidget);
    expect(find.text('Protected dashboard'), findsNothing);
    service.failSignIn = false;
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Protected dashboard'), findsOneWidget);
  });

  testWidgets(
    'registration validates confirmation and recovers a failed profile save',
    (tester) async {
      final service = FakeAuthService()..failProfile = true;
      addTearDown(service.changes.close);
      await mount(tester, service);
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      await credentials(tester, password: strongPassword);
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(service.registerCalls, 0);
      expect(find.text('Passwords do not match.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'),
        strongPassword,
      );
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pump();
      await tester.pump();
      // The app stays locked until the email is verified.
      expect(find.text('Verify your email'), findsOneWidget);
      expect(service.verificationEmails, 1);
      expect(find.text('Complete your profile'), findsNothing);
      await tester.tap(find.text("I've verified my email"));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Not verified yet'), findsOneWidget);
      service.verified = true;
      await tester.tap(find.text("I've verified my email"));
      await tester.pumpAndSettle();
      expect(find.text('Complete your profile'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'),
        'Test User',
      );
      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();
      expect(find.text('Protected dashboard'), findsNothing);
      expect(
        find.text(
          'Unable to connect. Check your internet connection and try again.',
        ),
        findsOneWidget,
      );
      service.failProfile = false;
      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();
      expect(find.text('Protected dashboard'), findsOneWidget);
      expect(service.registerCalls, 1);
      expect(service.nameSaved, 'Test User');
    },
  );

  testWidgets(
    'restored session enters app; sign out removes pushed protected routes',
    (tester) async {
      final service = FakeAuthService()
        ..account = const AuthAccount('existing', 'test@example.com');
      addTearDown(service.changes.close);
      await mount(tester, service);
      expect(find.text('Protected dashboard'), findsOneWidget);
      await tester.tap(find.text('Open detail'));
      await tester.pumpAndSettle();
      expect(find.text('Private detail'), findsOneWidget);
      await service.signOut();
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Private detail'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Private detail'), findsNothing);
    },
  );

  testWidgets('console account without profile resumes setup after restart', (
    tester,
  ) async {
    final service = FakeAuthService()
      ..account = const AuthAccount('console-user', 'test@example.com')
      ..profile = false;
    addTearDown(service.changes.close);
    await mount(tester, service);
    expect(find.text('Complete your profile'), findsOneWidget);
    expect(find.text('Protected dashboard'), findsNothing);
  });

  testWidgets('weak passwords are rejected when creating an account', (
    tester,
  ) async {
    final service = FakeAuthService();
    addTearDown(service.changes.close);
    await mount(tester, service);
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    for (final weak in [
      'secret123',
      'Short1!',
      'NoSymbol123',
      'nosymbol#123',
    ]) {
      await credentials(tester, password: weak);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'),
        weak,
      );
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Password needs:'),
        findsOneWidget,
        reason: weak,
      );
    }
    expect(service.registerCalls, 0);
  });

  testWidgets('unverified accounts cannot enter the app', (tester) async {
    final service = FakeAuthService()
      ..account = const AuthAccount(
        'existing',
        'test@example.com',
        emailVerified: false,
      )
      ..verified = false;
    addTearDown(service.changes.close);
    await mount(tester, service);
    expect(find.text('Verify your email'), findsOneWidget);
    expect(find.text('Protected dashboard'), findsNothing);
    // An older account that never got a link is sent one automatically.
    expect(service.verificationEmails, 1);
    service.verified = true;
    await tester.tap(find.text("I've verified my email"));
    await tester.pumpAndSettle();
    expect(find.text('Protected dashboard'), findsOneWidget);
  });

  testWidgets('profile read error blocks app and can retry', (tester) async {
    final service = FakeAuthService()
      ..account = const AuthAccount('existing', 'test@example.com')
      ..failCheck = true;
    addTearDown(service.changes.close);
    await mount(tester, service);
    expect(find.text('Protected dashboard'), findsNothing);
    expect(find.text('Retry profile check'), findsOneWidget);
    service.failCheck = false;
    await tester.tap(find.text('Retry profile check'));
    await tester.pumpAndSettle();
    expect(find.text('Protected dashboard'), findsOneWidget);
  });

  testWidgets(
    'forgot password opens dialog, pre-fills email, validates, and sends reset link',
    (tester) async {
      final service = FakeAuthService();
      addTearDown(service.changes.close);
      await mount(tester, service);

      expect(find.text('Forgot password?'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email address'),
        'reset-test@example.com',
      );
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      expect(find.text('Reset password'), findsOneWidget);
      expect(
        find.text('reset-test@example.com'),
        findsNWidgets(2),
      ); // main field and dialog field

      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();

      expect(service.resetPasswordCalls, 1);
      expect(service.resetPasswordEmail, 'reset-test@example.com');
      expect(find.text('Reset password'), findsNothing); // Dialog dismissed
      expect(
        find.textContaining(
          'Password reset link sent to reset-test@example.com',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'forgot password handles invalid email, service error, and dialog cancellation',
    (tester) async {
      final service = FakeAuthService()..failResetPassword = true;
      addTearDown(service.changes.close);
      await mount(tester, service);

      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      // Submit empty email in dialog
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();
      expect(service.resetPasswordCalls, 0);
      expect(find.text('Enter a valid email address.'), findsOneWidget);

      // Enter valid email but service fails
      final dialogEmailFinder = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(dialogEmailFinder, 'notfound@example.com');
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();

      expect(service.resetPasswordCalls, 1);
      expect(
        find.text('No account was found with that email address.'),
        findsOneWidget,
      );

      // Cancel dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Reset password'), findsNothing);
    },
  );

  testWidgets('forgot password button is hidden in registration mode', (
    tester,
  ) async {
    final service = FakeAuthService();
    addTearDown(service.changes.close);
    await mount(tester, service);

    expect(find.text('Forgot password?'), findsOneWidget);
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    expect(find.text('Forgot password?'), findsNothing);
  });
}
