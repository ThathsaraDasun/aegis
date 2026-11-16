import 'package:aegis/screens/trip/destination_search_sheet.dart';
import 'package:aegis/services/destination_search_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('DestinationSearchService unit tests', () {
    test('DestinationPlace stores name and position correctly', () {
      const place = DestinationPlace('Galle Face Green', LatLng(6.9271, 79.8450));
      expect(place.name, 'Galle Face Green');
      expect(place.position.latitude, 6.9271);
      expect(place.position.longitude, 79.8450);
    });

    test('query with fewer than 3 characters throws FormatException', () async {
      expect(
        () => DestinationSearchService.instance.search('ab'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('DestinationSearchSheet widget tests', () {
    testWidgets('renders search text field and action button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DestinationSearchSheet(),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
    });

    testWidgets('entering less than 3 characters and searching shows validation message',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DestinationSearchSheet(),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'ab');
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(find.text('Enter at least 3 characters.'), findsOneWidget);
    });
  });
}
