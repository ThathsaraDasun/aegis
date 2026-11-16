import 'package:flutter/material.dart';

import '../../services/live_share_link.dart';
import 'live_location_viewer_screen.dart';

/// Route for an `aegis://live/<shareToken>` deep link, or null when [name]
/// is not a live-share link. The viewer itself reports malformed tokens.
Route<void>? liveShareRoute(String? name) {
  final token = LiveShareLink.tokenFromRoute(name);
  if (token == null) return null;
  return MaterialPageRoute<void>(
    settings: RouteSettings(name: name),
    builder: (_) => LiveLocationViewerScreen.shared(shareToken: token),
  );
}

/// Fallback for any unexpected deep link: the viewer's "not valid" state.
Route<void> invalidLiveShareRoute(RouteSettings settings) =>
    MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const LiveLocationViewerScreen.shared(shareToken: ''),
    );
