import 'dart:io';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/transition_planner.dart';

MyAudioMetadata song(String id, int seconds) {
  return MyAudioMetadata(
    AudioMetadata(
      title: id,
      artist: 'A',
      album: 'B',
      duration: Duration(seconds: seconds),
    ),
    id: id,
    path: 'test-$id',
  );
}

void main() {
  setUpAll(() {
    appSupportDir = Directory.systemTemp.createTempSync('lain_test');
  });

  test('an adaptive plan stays positive and inside the shorter track', () {
    final plan = planTrackTransition(
      from: song('a', 240),
      to: song('b', 180),
      fixedTotalSeconds: 6,
    );
    expect(plan.outSeconds, greaterThan(0));
    expect(plan.inSeconds, greaterThan(0));
    expect(plan.totalSeconds, lessThanOrEqualTo(60));
  });

  test('very short tracks do not spend most of themselves on a fade', () {
    final plan = planTrackTransition(
      from: song('a', 24),
      to: song('b', 30),
      fixedTotalSeconds: 12,
    );
    expect(plan.totalSeconds, lessThanOrEqualTo(10));
  });
}
