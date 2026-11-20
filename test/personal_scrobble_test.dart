import 'package:flutter_test/flutter_test.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/data/personal_scrobble.dart';

void main() {
  test('local-only scrobbling follows the on-device source', () {
    final previousSource = sourceType;
    final previousStream = isStreamSource;
    final previousNotStream = isNotStreamSource;

    sourceType = SourceType.local;
    isStreamSource = false;
    isNotStreamSource = true;
    expect(
      personalScrobbleAllows(PersonalScrobbleMode.localOnly),
      isTrue,
    );

    sourceType = SourceType.navidrome;
    isStreamSource = true;
    isNotStreamSource = false;
    expect(
      personalScrobbleAllows(PersonalScrobbleMode.localOnly),
      isFalse,
    );
    expect(personalScrobbleAllows(PersonalScrobbleMode.all), isTrue);
    expect(personalScrobbleAllows(PersonalScrobbleMode.off), isFalse);

    sourceType = previousSource;
    isStreamSource = previousStream;
    isNotStreamSource = previousNotStream;
  });
}
