import 'package:flutter_test/flutter_test.dart';
import 'package:lain/base/data/playback_mode.dart';
import 'package:lain/base/services/audio_focus.dart';

void main() {
  test('exclusive pauses on interruption and resumes when it ends', () {
    var mode = AudioPlaybackMode.exclusive;
    var playing = true;
    var paused = 0;
    var resumed = 0;
    final controller = InterruptionController(
      modeOf: () => mode,
      isPlaying: () => playing,
      pause: () {
        paused++;
        playing = false;
      },
      resume: () {
        resumed++;
        playing = true;
      },
      duck: () {},
      unduck: () {},
    );

    controller.handle(true);
    expect(paused, 1);
    expect(playing, isFalse);

    controller.handle(false);
    expect(resumed, 1);
    expect(playing, isTrue);

    controller.dispose();
  });

  test('exclusive does not resume an already paused player', () {
    var playing = false;
    var paused = 0;
    var resumed = 0;
    final controller = InterruptionController(
      modeOf: () => AudioPlaybackMode.exclusive,
      isPlaying: () => playing,
      pause: () => paused++,
      resume: () => resumed++,
      duck: () {},
      unduck: () {},
    );

    controller.handle(true);
    controller.handle(false);
    expect(paused, 0);
    expect(resumed, 0);
    controller.dispose();
  });

  test('duck lowers and restores without pausing', () {
    var ducked = 0;
    var unducked = 0;
    final controller = InterruptionController(
      modeOf: () => AudioPlaybackMode.duck,
      isPlaying: () => true,
      pause: () => fail('duck must not pause'),
      resume: () => fail('duck must not resume'),
      duck: () => ducked++,
      unduck: () => unducked++,
    );

    controller.handle(true, canDuck: true);
    controller.handle(false);
    expect(ducked, 1);
    expect(unducked, 1);
    controller.dispose();
  });
}
