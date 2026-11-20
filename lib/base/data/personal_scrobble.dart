import 'package:material_ui/material_ui.dart';
import 'package:lain/base/app.dart';

/// Per-service choice for Last.fm and ListenBrainz.
///
/// `localOnly` means the on-device library. Navidrome/Emby/Feiniu already
/// report their own plays, and WebDAV belongs to its server, so this is the
/// mode that limits personal scrobbling to files on this phone.
enum PersonalScrobbleMode { off, localOnly, all }

PersonalScrobbleMode personalScrobbleModeFromName(String? name) =>
    PersonalScrobbleMode.values.asNameMap()[name ?? ''] ??
    PersonalScrobbleMode.off;

bool personalScrobbleAllows(PersonalScrobbleMode mode) {
  switch (mode) {
    case PersonalScrobbleMode.off:
      return false;
    case PersonalScrobbleMode.localOnly:
      return sourceType == SourceType.local;
    case PersonalScrobbleMode.all:
      return true;
  }
}

final lastFmScrobbleModeNotifier = ValueNotifier<PersonalScrobbleMode>(
  PersonalScrobbleMode.off,
);

final listenBrainzScrobbleModeNotifier = ValueNotifier<PersonalScrobbleMode>(
  PersonalScrobbleMode.off,
);
