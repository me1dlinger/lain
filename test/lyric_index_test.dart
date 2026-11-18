import 'dart:io';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/lyric.dart';
import 'package:lain/base/services/lyric_index.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    appSupportDir = Directory.systemTemp.createTempSync('lain_test');
  });

  test('indexes lyric lines and finds a short Chinese phrase', () async {
    final service = LyricIndexService();
    final song = MyAudioMetadata(
      AudioMetadata(
        title: 'Test',
        artist: 'Artist',
        album: 'Album',
        duration: const Duration(minutes: 3),
      ),
      id: 'lyric-test',
      path: 'lyric-test.mp3',
    );
    song.parsedLyrics = ParsedLyrics()
      ..lines.add(LyricLine(Duration.zero, 'Hello world', const []))
      ..lines.add(
        LyricLine(const Duration(seconds: 10), '这是月光', const []),
      );
    await service.indexSong(song);
    final hits = await service.search('月光');
    expect(hits.map((hit) => hit.songId), contains('lyric-test'));
  });
}
