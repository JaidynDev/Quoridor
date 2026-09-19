import 'package:flutter/foundation.dart' show kIsWeb;

/// Where the app lives when the running platform cannot tell us, which is
/// every build except web.
const String kAppHomeUrl = 'https://quoridor-440a4.web.app';

/// A link that drops whoever opens it straight into a match.
///
/// The web build uses hash routing, so the route belongs after the `#`. The
/// host part comes from the page the sharer is already on, which keeps
/// preview channels, GitHub Pages and local servers pointing at themselves
/// instead of sending testers to production.
String buildGameLink(String gameId, {Uri? pageUrl}) {
  final candidate = pageUrl ?? (kIsWeb ? Uri.base : Uri.parse(kAppHomeUrl));
  final base = (candidate.scheme == 'http' || candidate.scheme == 'https')
      ? candidate
      : Uri.parse(kAppHomeUrl);

  return '${base.origin}${_directoryOf(base.path)}#/game/$gameId';
}

/// The folder the app is served from, so a build hosted under a sub-path
/// keeps that sub-path.
String _directoryOf(String path) {
  if (path.isEmpty || path == '/') return '/';

  final segments = path.split('/');
  final last = segments.last;
  if (last.isEmpty) return path;

  // A trailing `index.html` is a page, not a folder.
  if (last.contains('.')) {
    segments[segments.length - 1] = '';
    return segments.join('/');
  }
  return '$path/';
}
