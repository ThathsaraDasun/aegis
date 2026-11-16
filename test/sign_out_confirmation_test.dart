import 'package:aegis/widgets/sign_out_confirmation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('confirmSignOut returns true when Sign out is tapped',
      (tester) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await confirmSignOut(context);
            },
            child: const Text('Trigger'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Trigger'));
    await tester.pumpAndSettle();

    expect(find.text('Sign out?'), findsOneWidget);
    expect(
      find.text('Are you sure you want to sign out of your account?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('confirmSignOut returns false when Cancel is tapped',
      (tester) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await confirmSignOut(context);
            },
            child: const Text('Trigger'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Trigger'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });
}
