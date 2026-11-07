import 'package:material_ui/material_ui.dart';

/// Quality requested from servers that can transcode on the fly.
///
/// [original] sends no transcode parameters at all, which is what the app did
/// before this option existed - the server decides (usually a direct play of the
/// stored file).
enum StreamQuality {
  /// up to 128 kbps
  standard,

  /// up to 192 kbps
  high,

  /// 256 kbps
  hq,

  /// 320 kbps
  sq,

  /// no transcode
  original;

  /// Bitrate cap in kbps, or null when the stream must not be transcoded.
  int? get maxBitRate => switch (this) {
    StreamQuality.standard => 128,
    StreamQuality.high => 192,
    StreamQuality.hq => 256,
    StreamQuality.sq => 320,
    StreamQuality.original => null,
  };

  bool get transcodes => maxBitRate != null;

  static StreamQuality fromName(Object? name) =>
      values.asNameMap()[name] ?? StreamQuality.original;
}

/// Container format requested from servers that transcode.
enum StreamFormat {
  aac,
  mp3,
  ogg;

  /// What Subsonic-compatible servers (Navidrome) expect for `format=`.
  String get subsonicValue => name;

  /// What Emby expects for `AudioCodec=`.
  String get embyValue => switch (this) {
    StreamFormat.aac => 'aac',
    StreamFormat.mp3 => 'mp3',
    StreamFormat.ogg => 'vorbis',
  };

  String get display => name.toUpperCase();

  static StreamFormat fromName(Object? name) =>
      values.asNameMap()[name] ?? StreamFormat.aac;
}
/// Transcoding requested from online sources. Kept here (rather than in
/// setting.dart) so the stream clients can read it without importing the UI
/// layer; Setting persists both values.
final streamQualityNotifier = ValueNotifier(StreamQuality.original);
final streamFormatNotifier = ValueNotifier(StreamFormat.aac);
