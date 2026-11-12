import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

/// The song row's "this one is cached" mark, for a streamed source only: a
/// local library has nothing to download.
///
/// It follows [MyAudioMetadata.cacheExist], which changes while the app runs
/// (the song playing right now is cached once it is mostly listened to, a
/// download finishes, the cache is cleared), so the row is rebuilt on the
/// library's notifier instead of reading the flag once.
class CachedBadge extends StatelessWidget {
  final MyAudioMetadata song;
  final double size;

  const CachedBadge({super.key, required this.song, this.size = 12});

  @override
  Widget build(BuildContext context) {
    if (isNotStreamSource) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder(
      valueListenable: library.changeNotifier,
      builder: (context, _, _) {
        if (!song.cacheExist) {
          return const SizedBox.shrink();
        }
        final l10n = AppLocalizations.of(context);
        return Tooltip(
          message: l10n.cached,
          child: Icon(
            Icons.offline_pin_rounded,
            size: size,
            // Deliberately faint: on a streamed library this marks most rows,
            // and it must not compete with the title.
            color: colorManager.getSpecificTextColor().withAlpha(110),
          ),
        );
      },
    );
  }
}

/// What one song has on disk. Null when nothing of it is cached.
class SongCacheParts {
  final bool audio;
  final bool cover;
  final bool lyric;

  /// The sizes actually found, when they could be read.
  final int bytes;

  const SongCacheParts({
    required this.audio,
    required this.cover,
    required this.lyric,
    this.bytes = 0,
  });

  bool get isEmpty => !audio && !cover && !lyric;
}

/// Reads what is cached for [song] from the files themselves.
///
/// The cache listing ([cacheEntriesNotifier]) is only rebuilt when the cache
/// screen is opened, so a song cached since the last refresh would be missed;
/// the audio file, the cover and the lyric file are cheap to stat.
Future<SongCacheParts> readSongCache(MyAudioMetadata song) async {
  var audio = false;
  var cover = false;
  var lyric = false;
  var bytes = 0;

  Future<int> sizeOf(String? path) async {
    if (path == null || path.isEmpty) {
      return 0;
    }
    final file = File(path);
    if (!await file.exists()) {
      return 0;
    }
    return file.length();
  }

  final audioPath = song.cachePath;
  if (audioPath != null && await File(audioPath).exists()) {
    audio = true;
    bytes += await sizeOf(audioPath);
  }
  final coverSize = await sizeOf(song.picture.path);
  if (coverSize > 0) {
    cover = true;
    bytes += coverSize;
  }
  final lyricPath = song.lrcPath;
  final lyricSize = await sizeOf(lyricPath);
  if (lyricSize > 0) {
    lyric = true;
    bytes += lyricSize;
  }
  return SongCacheParts(
    audio: audio,
    cover: cover,
    lyric: lyric,
    bytes: bytes,
  );
}

/// Opens what is cached for [song]: which parts, the cover, the lyric file and
/// how much disk they take. Says so instead when nothing is cached.
Future<void> showSongCacheDialog(
  BuildContext context,
  MyAudioMetadata song,
) async {
  final l10n = AppLocalizations.of(context);
  final parts = await readSongCache(song);
  if (!context.mounted) {
    return;
  }
  if (parts.isEmpty) {
    showCenterMessage(l10n.cacheEmpty);
    return;
  }

  final lyricPath = song.lrcPath;
  var lyrics = '';
  if (lyricPath != null && parts.lyric) {
    final file = File(lyricPath);
    if (await file.exists()) {
      lyrics = await file.readAsString();
    }
  }
  final coverPath = song.picture.path;
  if (!context.mounted) {
    return;
  }

  final tags = <String>[
    if (parts.cover) l10n.cacheTagCover,
    if (parts.lyric) l10n.cacheTagLyric,
    if (parts.audio) l10n.cacheTagAudio,
  ];
  final sizeText = parts.bytes > 0
      ? '${(parts.bytes / (1024 * 1024)).toStringAsFixed(1)}MB'
      : '';

  showAnimationDialog(
    context: context,
    child: SizedBox(
      width: 340,
      height: 440,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              getTitle(song),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${getArtist(song)} - ${getAlbum(song)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              sizeText.isEmpty
                  ? tags.join(' · ')
                  : '${tags.join(' · ')} · $sizeText',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            if (parts.cover && coverPath.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(coverPath),
                  height: 150,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => const SizedBox(
                    height: 150,
                    child: Icon(Icons.broken_image),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  lyrics.isEmpty ? l10n.noLyrics : lyrics,
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
