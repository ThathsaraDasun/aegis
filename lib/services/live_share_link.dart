/// Builds and parses `aegis://live/<shareToken>` deep links.
///
/// Android hands Flutter either the full URI or only its path, depending on
/// how the app was launched, so [tokenFromRoute] accepts all of:
/// `aegis://live/<token>`, `/live/<token>` and `/<token>`.
class LiveShareLink {
  LiveShareLink._();

  static const String scheme = 'aegis';
  static const String host = 'live';

  /// The deep link a guardian taps to open the live viewer.
  static String build(String shareToken) => '$scheme://$host/$shareToken';

  /// Extracts the token from a route or URI, or returns null when [route] is
  /// not a live-share link. The token itself is not validated here.
  static String? tokenFromRoute(String? route) {
    if (route == null || route.isEmpty) return null;
    final uri = Uri.tryParse(route);
    if (uri == null) return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (uri.scheme == scheme) {
      if (uri.host != host || segments.length != 1) return null;
      return segments.single;
    }
    if (uri.hasScheme) return null;
    if (segments.length == 2 && segments.first == host) return segments.last;
    if (segments.length == 1 && segments.single != host) return segments.single;
    return null;
  }
}
