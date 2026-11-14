import 'package:aegis/screens/auth/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpRegister(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
  await tester.pump(const Duration(milliseconds: 700));
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('register_submit')));
  await tester.tap(find.byKey(const Key('register_submit')));
  await tester.pump();
}

void main() {
  testWidgets('shows all registration fields and the Sign In link', (tester) async {
    await _pumpRegister(tester);

    expect(find.text('Create Account'), findsNWidgets(2)); // title + button
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.text('Already have an account?'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('empty form shows validation errors', (tester) async {
    await _pumpRegister(tester);
    await _submit(tester);

    expect(find.text('Please enter your full name'), findsOneWidget);
    expect(find.text('Please enter your email address'), findsOneWidget);
    expect(find.text('Please create a password'), findsOneWidget);
    expect(find.text('Please confirm your password'), findsOneWidget);
  });

  testWidgets('rejects bad email, weak password and mismatched confirm', (tester) async {
    await _pumpRegister(tester);

    await tester.enterText(find.byKey(const Key('register_name')), 'Jane Doe');
    await tester.enterText(find.byKey(const Key('register_email')), 'not-an-email');
    await tester.enterText(find.byKey(const Key('register_password')), 'abcdefgh');
    await tester.enterText(find.byKey(const Key('register_confirm')), 'different1');
    await _submit(tester);

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Include at least one letter and one number'), findsOneWidget);
    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('password visibility toggles', (tester) async {
    await _pumpRegister(tester);

    final passwordField = find.descendant(
      of: find.byKey(const Key('register_password')),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(passwordField).obscureText, isTrue);

    await tester.tap(find.byTooltip('Show password').first);
    await tester.pump();
    expect(tester.widget<EditableText>(passwordField).obscureText, isFalse);
  });

  testWidgets('shows a strength meter while typing a password', (tester) async {
    await _pumpRegister(tester);

    await tester.enterText(find.byKey(const Key('register_password')), 'abc');
    await tester.pump();
    expect(find.text('Weak'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('register_password')), 'Secure#Pass2026');
    await tester.pump();
    expect(find.text('Strong'), findsOneWidget);
  });
}
