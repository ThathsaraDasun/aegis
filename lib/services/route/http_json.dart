import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Tiny JSON-over-HTTP helper built on dart:io so the route layer needs no
/// extra package. Android only (the app's sole target platform).
class HttpJson {
  HttpJson._();

  static const _userAgent = 'AegisSafeWalk/1.0 (com.aegis.safewalk; student project)';

  static Future<Map<String, dynamic>> get(
    Uri uri, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(uri).timeout(timeout);
      request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(timeout);
      return _decode(response, timeout);
    } finally {
      client.close(force: true);
    }
  }

  static Future<Map<String, dynamic>> postForm(
    Uri uri,
    Map<String, String> fields, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.postUrl(uri).timeout(timeout);
      request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.contentType =
          ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
      final body = fields.entries
          .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
          .join('&');
      request.write(body);
      final response = await request.close().timeout(timeout);
      return _decode(response, timeout);
    } finally {
      client.close(force: true);
    }
  }

  static Future<Map<String, dynamic>> _decode(
      HttpClientResponse response, Duration timeout) async {
    final text = await response.transform(utf8.decoder).join().timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('Unexpected JSON payload');
  }
}
