import 'package:material_ui/material_ui.dart';

/// How the cover is announced to the media session (and therefore the head
/// unit). The bitmap is always carried in the session; these options add a URI
/// a unit can fetch for itself, for units that do not read the bitmap.
enum CoverBroadcastMode {
  /// Only `artCacheFile` (the session's bitmap).
  bitmap,

  /// The server's own cover URL, sized down.
  server,

  /// This phone's cover relay on the LAN, serving the broadcast-sized copy.
  relay,

  /// A content:// URI served by the app's provider.
  content,
}

final coverBroadcastModeNotifier = ValueNotifier<CoverBroadcastMode>(
  CoverBroadcastMode.server,
);
