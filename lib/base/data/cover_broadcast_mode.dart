import 'package:material_ui/material_ui.dart';

/// How the cover is announced to the media session (and therefore the head
/// unit). The bitmap is always carried in the session; these options add a URI
/// a unit can fetch for itself, for units that do not read the bitmap.
enum CoverBroadcastMode {
  /// Pick per source: a streamed source uses the server's cover URL, a local
  /// library uses this phone's relay.
  auto,

  /// Only `artCacheFile` (the session's bitmap).
  bitmap,

  /// The server's own cover URL, sized down.
  server,

  /// This phone's cover relay on the LAN, serving the broadcast-sized copy.
  relay,

  /// This phone's cover relay, serving the original cover file.
  relayOriginal,

  /// A content:// URI served by the app's provider.
  content,
}

final coverBroadcastModeNotifier = ValueNotifier<CoverBroadcastMode>(
  CoverBroadcastMode.auto,
);

/// The address the relay should advertise, or empty for automatic selection.
/// A phone can have several private addresses (Wi-Fi, hotspot, VPN); the one a
/// head unit can reach is not always the first one.
final relayAddressNotifier = ValueNotifier<String>('');
