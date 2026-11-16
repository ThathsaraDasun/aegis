import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aegis/models/user_model.dart';
import 'package:aegis/screens/profile/edit_profile_screen.dart';

void main() {
  testWidgets('EditProfileScreen renders initial values and form controls', (WidgetTester tester) async {
    final testUser = UserModel(
      userId: 'test_user_001',
      name: 'Elena Vance',
      phone: '+1 555-019-2834',
      bloodType: 'O+',
      allergies: 'Penicillin',
      emergencyNote: 'Asthma patient',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EditProfileScreen(initialUser: testUser),
      ),
    );

    // Verify App Bar & Title
    expect(find.text('Edit Profile & Medical Info'), findsOneWidget);

    // Verify Personal Info inputs
    expect(find.text('Elena Vance'), findsWidgets);
    expect(find.text('+1 555-019-2834'), findsOneWidget);

    // Verify Medical Profile inputs
    expect(find.text('O+'), findsWidgets);
    expect(find.text('Penicillin'), findsOneWidget);
    expect(find.text('Asthma patient'), findsOneWidget);

    // Verify Buttons
    expect(find.text('Save Profile & Medical Info'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}
