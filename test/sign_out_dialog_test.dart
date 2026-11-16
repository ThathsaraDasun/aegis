import 'package:aegis/widgets/sign_out_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<List<bool>> pumpAndTap(WidgetTester tester, String button) async {
    final results = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(await confirmSignOut(context)),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.text(button));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsNothing);
    return results;
  }

  testWidgets('confirming returns true', (tester) async {
    expect(await pumpAndTap(tester, 'Sign out'), [true]);
  });

  testWidgets('cancel returns false', (tester) async {
    expect(await pumpAndTap(tester, 'Cancel'), [false]);
  });

  testWidgets('dismissing outside the dialog returns false', (tester) async {
    final results = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(await confirmSignOut(context)),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(results, [false]);
  });
}
