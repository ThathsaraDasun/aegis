import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:latlong2/latlong.dart';

class DestinationPlace {
  final String name;
  final LatLng position;
  const DestinationPlace(this.name, this.position);
}

/// Explicit searches only: never call this from onChanged/autocomplete.
/// Public Nominatim is best-effort and suitable only for light demo usage.
class DestinationSearchService {
  static final instance = DestinationSearchService();
  static const _endpoint = String.fromEnvironment(
    'DESTINATION_SEARCH_URL',
    defaultValue: 'https://nominatim.openstreetmap.org/search',
  );
  final _cache = <String, List<DestinationPlace>>{};
  DateTime? _lastRequest;
  bool _busy = false;

  Future<List<DestinationPlace>> search(String input) async {
    final query = input.trim();
    if (query.length < 3) {
      throw const FormatException('Enter at least 3 characters.');
    }
    final key = query.toLowerCase();
    if (_cache.containsKey(key)) return _cache[key]!;
    if (_busy) {
      throw const FormatException('Please wait for the current search.');
    }
    _busy = true;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final elapsed = _lastRequest == null
          ? 1100
          : DateTime.now().difference(_lastRequest!).inMilliseconds;
      if (elapsed < 1100) {
        await Future<void>.delayed(Duration(milliseconds: 1100 - elapsed));
      }
      _lastRequest = DateTime.now();
      final uri = Uri.parse(_endpoint).replace(
        queryParameters: {'q': query, 'format': 'jsonv2', 'limit': '5'},
      );
      final places = await (() async {
        final request = await client.getUrl(uri);
        request.headers.set(
          HttpHeaders.userAgentHeader,
          'AegisSafeWalk/1.0 (https://github.com/ThathsaraDasun/aegis)',
        );
        final response = await request.close();
        if (response.statusCode == 429 || response.statusCode == 403) {
          throw const FormatException(
            'Search is temporarily limited. Try later or select a pin on the map.',
          );
        }
        if (response.statusCode != 200) {
          throw const FormatException(
            'Search is unavailable. Try again or tap the map.',
          );
        }
        final data = jsonDecode(await utf8.decoder.bind(response).join());
        if (data is! List) {
          throw const FormatException(
            'Unexpected search response. Please retry.',
          );
        }
        final results = <DestinationPlace>[];
        for (final item in data) {
          if (item is! Map) continue;
          final lat = double.tryParse('${item['lat']}');
          final lon = double.tryParse('${item['lon']}');
          final name = item['display_name'];
          if (lat == null ||
              lon == null ||
              !lat.isFinite ||
              !lon.isFinite ||
              lat.abs() > 90 ||
              lon.abs() > 180 ||
              name is! String ||
              name.isEmpty) {
            continue;
          }
          results.add(DestinationPlace(name, LatLng(lat, lon)));
        }
        return List<DestinationPlace>.unmodifiable(results);
      })().timeout(const Duration(seconds: 15));
      if (_cache.length >= 100) _cache.remove(_cache.keys.first);
      _cache[key] = places;
      return places;
    } finally {
      client.close(force: true);
      _busy = false;
    }
  }
}
