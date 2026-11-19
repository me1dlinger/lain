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


/// How a classic Bluetooth (AVRCP) head unit is offered the cover. AVRCP
/// metadata itself has no image field; Android's stack reads the media
/// session, and different units/stacks pick a bitmap, a URI, or neither.
/// These are testable variants of the same session item.
enum ClassicCoverMode {
  /// The complete shape, for units that do not read the bitmap: the cover
  /// file as `artUri`, a URI the unit can fetch itself (a streamed source's
  /// server URL or this phone's LAN relay), and the broadcast-sized bitmap.
  full,

  /// The session bitmap only, at the broadcast thumbnail size.
  bitmap,

  /// The session bitmap plus a content:// URI from the app's provider.
  bitmapUri,

  /// The session bitmap made from the original cover file.
  largeBitmap,

  /// The session bitmap plus the LAN relay / server cover URI.
  relayUri,
}

/// The default is [ClassicCoverMode.full]: a classic Bluetooth route gets
/// every artwork route at once, so a unit that reads a bitmap and one that
/// fetches a URI both have something to use.
final classicCoverModeNotifier = ValueNotifier<ClassicCoverMode>(
  ClassicCoverMode.full,
);
