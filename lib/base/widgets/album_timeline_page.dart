import 'package:material_ui/material_ui.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/data/album_timeline.dart';
import 'package:lain/base/data/artist_album.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/widgets/apple_form.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/base/widgets/local_music_page.dart';
import 'package:lain/base/widgets/my_divider.dart';
import 'package:lain/base/widgets/settings_page_route.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

/// The date each song was placed under last time, keyed by its id.
///
/// Creating and classifying the library can leave a song without a created
/// time for a while; the fallback makes the timeline show data immediately, and
/// a later created time replaces the cached modified one.
final Map<String, DateTime> albumTimelineSongDateCache = {};

DateTime? albumTimelineDateOf(MyAudioMetadata song) {
  final resolved = resolveAlbumTimelineDate(
    created: song.created,
    modified: song.modified,
    cached: albumTimelineSongDateCache[song.id],
  );
  if (resolved != null) {
    albumTimelineSongDateCache[song.id] = resolved;
  }
  return resolved;
}

/// Reads the current library into the timeline's own input shape. An album can
/// produce more than one entry: one per day its songs were added.
({List<AlbumTimelineDay> days, int missing}) buildAlbumTimelineFromLibrary({
  required AlbumTimelineRange range,
  DateTime? now,
}) {
  final songs = <AlbumTimelineSong>[];
  var missing = 0;
  for (final album in artistAlbumManager.albumList) {
    var hasCreated = false;
    for (final song in album.songList) {
      final created = albumTimelineDateOf(song);
      if (created == null) {
        continue;
      }
      hasCreated = true;
      songs.add(
        AlbumTimelineSong(
          albumKey: albumKeyOf(song),
          albumName: album.name,
          artistName: getArtists(getArtist(song)).first,
          year: album.year,
          songId: song.id,
          created: created,
        ),
      );
    }
    if (!hasCreated) {
      missing++;
    }
  }
  return (
    days: groupAlbumTimeline(songs, now: now ?? DateTime.now(), range: range),
    missing: missing,
  );
}

/// The full timeline: a range switch and one card per day.
class AlbumTimelinePage extends StatefulWidget {
  const AlbumTimelinePage({super.key});

  @override
  State<AlbumTimelinePage> createState() => _AlbumTimelinePageState();
}

class _AlbumTimelinePageState extends State<AlbumTimelinePage> {
  AlbumTimelineRange _range = AlbumTimelineRange.month;

  @override
  Widget build(BuildContext context) {
    assert(isLocalLibrary);
    final l10n = AppLocalizations.of(context);
    return opaqueSettingsPage(
      context: context,
      title: l10n.albumTimeline,
      body: ListenableBuilder(
        listenable: Listenable.merge([
          artistAlbumManager.updateNotifier,
          library.changeNotifier,
        ]),
        builder: (context, child) {
          // The library is still being classified; the list would look empty
          // rather than loading.
          if (!artistAlbumManager.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final result = buildAlbumTimelineFromLibrary(range: _range);
          final days = result.days;
          return Column(
            children: [
              AppleFormSection(
                divided: false,
                children: [
                  appleSegmented<AlbumTimelineRange>(
                    AlbumTimelineRange.values,
                    (value) => switch (value) {
                      .month => l10n.lastMonth,
                      .quarter => l10n.lastQuarter,
                      .all => l10n.allTime,
                    },
                    _range,
                    (value) => setState(() => _range = value),
                  ),
                ],
              ),
              Expanded(
                child: days.isEmpty
                    ? Center(
                        child: Text(
                          l10n.noAlbumsInRange,
                          style: TextStyle(
                            fontSize: 14,
                            color: colorManager
                                .getSpecificTextColor()
                                .withAlpha(150),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: days.length + 1,
                        itemBuilder: (context, index) {
                          if (index == days.length) {
                            return result.missing == 0
                                ? const SizedBox.shrink()
                                : Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      12,
                                      20,
                                      0,
                                    ),
                                    child: Text(
                                      l10n.albumsMissingCreated(
                                        result.missing,
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorManager
                                            .getSpecificTextColor()
                                            .withAlpha(150),
                                      ),
                                    ),
                                  );
                          }
                          return _day(context, days[index]);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _day(BuildContext context, AlbumTimelineDay day) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Row(
            children: [
              Text(
                albumTimelineDayLabel(day.date),
                style: TextStyle(fontSize: 15, color: textColor.withAlpha(160)),
              ),
              const Spacer(),
              Text(
                l10n.albumTimelineAddedCount(day.songCount),
                style: TextStyle(fontSize: 12, color: textColor.withAlpha(150)),
              ),
            ],
          ),
        ),
        AppleFormSection(
          children: [
            for (final entry in day.entries) _albumRow(context, entry),
          ],
        ),
      ],
    );
  }

  Widget _albumRow(BuildContext context, AlbumTimelineEntry entry) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();
    final album = artistAlbumManager.albumMap[entry.albumKey];
    return ListTile(
      leading: CoverArtWidget(
        size: 44,
        borderRadius: 6,
        picture: album?.picture,
      ),
      title: Text(
        entry.albumName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        entry.year == null
            ? entry.artistName
            : '${entry.artistName} · ${entry.year}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: textColor.withAlpha(150)),
      ),
      trailing: Text(
        l10n.albumTimelineSongCount(entry.count),
        style: TextStyle(fontSize: 12, color: textColor.withAlpha(180)),
      ),
      onTap: album == null
          ? null
          : () {
              if (album.songList.isNotEmpty) {
                goToAlbum(album.songList.first, context: context);
              }
            },
    );
  }
}

/// The compact block on the listening report: the three most recently added
/// albums and a way into the full page.
class AlbumTimelinePreview extends StatelessWidget {
  const AlbumTimelinePreview({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();
    return ValueListenableBuilder(
      valueListenable: artistAlbumManager.updateNotifier,
      builder: (context, _, _) {
        return ListenableBuilder(
          listenable: library.changeNotifier,
          builder: (context, child) {
            if (!artistAlbumManager.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 26),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final result = buildAlbumTimelineFromLibrary(
              range: AlbumTimelineRange.all,
            );
            final recent = <AlbumTimelineEntry>[];
            for (final day in result.days) {
              for (final entry in day.entries) {
                if (recent.length >= 3) {
                  break;
                }
                recent.add(entry);
              }
              if (recent.length >= 3) {
                break;
              }
            }
            if (recent.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 26),
                child: Center(
                  child: Text(
                    l10n.noData,
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor.withAlpha(150),
                    ),
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final entry in recent) _previewRow(context, entry),
                MyDivider(thickness: 0.5, height: 1, color: dividerColor),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _openPage(context),
                    child: Text(
                      l10n.viewAll,
                      style: TextStyle(fontSize: 13, color: textColor),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _previewRow(BuildContext context, AlbumTimelineEntry entry) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();
    final album = artistAlbumManager.albumMap[entry.albumKey];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CoverArtWidget(
            size: 40,
            borderRadius: 6,
            picture: album?.picture,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.albumName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, color: textColor),
                ),
                Text(
                  albumTimelineDayLabel(entry.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withAlpha(150),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            l10n.albumTimelineSongCount(entry.count),
            style: TextStyle(fontSize: 13, color: textColor.withAlpha(180)),
          ),
        ],
      ),
    );
  }

  void _openPage(BuildContext context) {
    pushSettingsPage<void>(
      context,
      settingsPageRoute<void>(() => const AlbumTimelinePage()),
    );
  }
}
