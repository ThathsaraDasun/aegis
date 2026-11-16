import 'package:aegis/widgets/aegis_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AegisNavBar reports the screen index of each item', (
    tester,
  ) async {
    final tapped = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AegisNavBar(
            currentIndex: 0,
            onTap: tapped.add,
            centerItem: const AegisNavItem(
              icon: Icons.shield_outlined,
              activeIcon: Icons.shield,
              label: 'Safety',
              index: 0,
            ),
            leftItems: const [
              AegisNavItem(
                icon: Icons.notifications_outlined,
                activeIcon: Icons.notifications,
                label: 'Activity',
                index: 1,
              ),
              AegisNavItem(
                icon: Icons.people_outline,
                activeIcon: Icons.people,
                label: 'Guardians',
                index: 2,
              ),
            ],
            rightItems: const [
              AegisNavItem(
                icon: Icons.alt_route,
                activeIcon: Icons.alt_route,
                label: 'Routes',
                index: 4,
              ),
              AegisNavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                index: 3,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Activity'));
    await tester.tap(find.text('Guardians'));
    await tester.tap(find.text('Routes'));
    await tester.tap(find.text('Profile'));
    await tester.tap(find.byIcon(Icons.shield));
    expect(tapped, [1, 2, 4, 3, 0]);
  });
}
