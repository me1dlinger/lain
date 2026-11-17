/// Snapshot of a music server and its library, shared by the home stats card
/// and the server status page.
///
/// Every field is what the server reported; a value the server does not give
/// stays null and the pages show a dash for it. Both Navidrome and Emby fill
/// the same shape, so the UI does not need to know which source it came from.
class ServerLibraryStats {
  /// How long the ping took, measured while the snapshot was fetched.
  final Duration latency;

  /// Which kind of server answered: `navidrome` or `emby`.
  final String sourceType;

  /// The server software's own name/type, e.g. `navidrome` or `Emby`.
  final String? serverType;

  /// The server's display name, when it reports one (Emby: MAGI-EMBY).
  final String? serverName;

  /// The server's own version, e.g. `0.6.4.1 (285dc4f3)` or `4.9.5.0`.
  final String? serverVersion;

  /// The Subsonic API version the server speaks, e.g. `1.16.1`. Emby has none.
  final String? subsonicVersion;

  /// Whether the server answered with the OpenSubsonic flag. Emby has none.
  final bool openSubsonic;

  /// The host OS the server runs on, when it reports one.
  final String? operatingSystem;

  /// Whether the server reports an update it has not installed.
  final bool? hasUpdate;

  /// Songs visible through the source's music library.
  final int? songCount;

  final int? artistCount;
  final int? albumCount;
  final int? folderCount;

  /// Sum of every song's file size, in bytes.
  final int? totalSize;

  /// Sum of every song's duration, in seconds.
  final int? totalDuration;

  /// Whether a scan was running when the snapshot was taken.
  final bool? scanning;

  /// When the last scan finished.
  final DateTime? lastScan;

  /// Sessions playing right now, and how many of them are transcoding.
  final int? activeStreams;
  final int? transcodeStreams;

  /// Whether the source can start a library scan on request.
  final bool canScan;

  /// What the server says it can do: OpenSubsonic extension names for
  /// Navidrome, a fixed set of endpoints for Emby. Empty when it reports
  /// nothing.
  final List<String> extensions;

  const ServerLibraryStats({
    required this.latency,
    required this.sourceType,
    this.serverType,
    this.serverName,
    this.serverVersion,
    this.subsonicVersion,
    this.openSubsonic = false,
    this.operatingSystem,
    this.hasUpdate,
    this.songCount,
    this.artistCount,
    this.albumCount,
    this.folderCount,
    this.totalSize,
    this.totalDuration,
    this.scanning,
    this.lastScan,
    this.activeStreams,
    this.transcodeStreams,
    this.canScan = true,
    this.extensions = const [],
  });
}

/// `108.4 GB`-style formatting of a byte count for the stats display.
String formatLibrarySize(int bytes) {
  if (bytes <= 0) {
    return '0';
  }
  final gb = bytes / (1024 * 1024 * 1024);
  if (gb >= 1) {
    return gb >= 100
        ? gb.round().toString()
        : gb.toStringAsFixed(gb >= 10 ? 1 : 2);
  }
  final mb = bytes / (1024 * 1024);
  return mb >= 1 ? '${mb.round()} MB' : '${(bytes / 1024).round()} KB';
}

/// `273.4`-style hour value of a duration in seconds; larger libraries are
/// shown in whole days plus hours instead, with the unit chosen by the
/// caller through [inDays].
String formatLibraryDuration(int seconds, {required bool inDays}) {
  if (inDays) {
    return '${seconds ~/ 86400}';
  }
  final hours = seconds / 3600;
  return hours >= 100 ? hours.round().toString() : hours.toStringAsFixed(1);
}
