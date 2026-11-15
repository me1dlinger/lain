import 'package:flutter_test/flutter_test.dart';
import 'package:lain/base/data/library_naming.dart';
import 'package:path/path.dart' as p;

NamingInput example({
  String? title = 'Song',
  String? artist = 'Artist',
  String? album = 'Album',
  String? albumArtist,
  int? track = 3,
  int? disc,
  int? year,
  String ext = '.mp3',
  String fileName = 'song',
}) {
  return NamingInput(
    title: title,
    artist: artist,
    album: album,
    albumArtist: albumArtist,
    track: track,
    disc: disc,
    year: year,
    ext: ext,
    fileName: fileName,
  );
}

void main() {
  group('default naming format', () {
    test('builds Artist/Album/03. Song.mp3', () {
      final plan = buildLibraryNamingPlan(
        const LibraryNamingFormat(),
        example(),
      );
      expect(plan, isNotNull);
      expect(plan!.relativeDir, p.join('Artist', 'Album'));
      expect(plan.fileName, '03. Song.mp3');
    });

    test('uses defaults for empty tags', () {
      final plan = buildLibraryNamingPlan(
        const LibraryNamingFormat(),
        example(title: null, artist: null, album: null, fileName: 'whatever'),
      );
      expect(plan!.relativeDir, p.join('Unknown Artist', 'Unknown Album'));
      expect(plan.fileName, '03. whatever.mp3');
    });

    test('albumArtist falls back to artist', () {
      final plan = buildLibraryNamingPlan(
        const LibraryNamingFormat(dirTemplate: '{albumArtist}/{album}'),
        example(),
      );
      expect(plan!.relativeDir, p.join('Artist', 'Album'));
    });
  });

  group('feat credit', () {
    test('is moved to the end when kept', () {
      final plan = buildLibraryNamingPlan(
        const LibraryNamingFormat(keepFeat: true),
        example(title: 'Song (feat. X)'),
      );
      expect(plan!.fileName, '03. Song - feat. X.mp3');
    });

    test('is left in place when not kept', () {
      final plan = buildLibraryNamingPlan(
        const LibraryNamingFormat(keepFeat: false),
        example(title: 'Song (feat. X)'),
      );
      expect(plan!.fileName, '03. Song (feat. X).mp3');
    });

    test('handles full-width parentheses', () {
      final plan = buildLibraryNamingPlan(
        const LibraryNamingFormat(keepFeat: true),
        example(title: 'Song（feat. Y）'),
      );
      expect(plan!.fileName, '03. Song - feat. Y.mp3');
    });
  });

  group('template placeholders', () {
    test('pads the track only when asked', () {
      final padded = buildLibraryNamingPlan(
        const LibraryNamingFormat(fileTemplate: '{track:02}. {title}'),
        example(track: 7),
      );
      final plain = buildLibraryNamingPlan(
        const LibraryNamingFormat(fileTemplate: '{track}. {title}'),
        example(track: 7),
      );
      expect(padded!.fileName, '07. Song.mp3');
      expect(plain!.fileName, '7. Song.mp3');
    });

    test('renders year and disc', () {
      final plan = buildLibraryNamingPlan(
        const LibraryNamingFormat(
          dirTemplate: '{artist}/{year} - {album}',
          fileTemplate: '{disc:02}-{track:02}. {title}',
        ),
        example(year: 2026, disc: 2, track: 3),
      );
      expect(plan!.relativeDir, p.join('Artist', '2026 - Album'));
      expect(plan.fileName, '02-03. Song.mp3');
    });

    test('appends the extension when the template lacks ext', () {
      final plan = buildLibraryNamingPlan(
        const LibraryNamingFormat(fileTemplate: '{title}'),
        example(ext: '.flac'),
      );
      expect(plan!.fileName, 'Song.flac');
    });

    test('rejects an absolute template', () {
      expect(
        validateNamingTemplate('/music/{artist}', directory: true),
        NamingTemplateError.absolutePath,
      );
      expect(
        validateNamingTemplate(r'C:\music', directory: true),
        NamingTemplateError.absolutePath,
      );
    });

    test('rejects a parent segment', () {
      expect(
        validateNamingTemplate('../{artist}', directory: true),
        NamingTemplateError.parentSegment,
      );
    });

    test('requires the title placeholder in a file name', () {
      expect(
        validateNamingTemplate('{artist}', directory: false),
        NamingTemplateError.missingTitle,
      );
      expect(validateNamingTemplate('{title}', directory: false), isNull);
    });

    test('rejects unknown placeholders', () {
      expect(
        validateNamingTemplate('{artist}/{foo}', directory: true),
        NamingTemplateError.unknownPlaceholder,
      );
    });

    test('rejects an empty template', () {
      expect(
        validateNamingTemplate('   ', directory: true),
        NamingTemplateError.empty,
      );
    });
  });

  group('path safety', () {
    test('replaces characters no platform accepts', () {
      expect(sanitizePathSegment('A/B:C*D?"<>|'), 'A_B_C_D_____');
    });

    test('replaces dots that mean a directory', () {
      expect(sanitizePathSegment('..'), '_');
      expect(sanitizePathSegment('.'), '_');
    });

    test('suffixes Windows reserved names', () {
      expect(sanitizePathSegment('con'), 'con_');
      expect(sanitizePathSegment('NUL'), 'NUL_');
      expect(sanitizePathSegment('com1'), 'com1_');
    });

    test('does not let a dot at the end through', () {
      expect(sanitizePathSegment('name.'), 'name_');
    });

    test('avoids a leading dash', () {
      expect(sanitizePathSegment('-option'), '_-option');
    });

    test('caps a overlong segment at 120 characters', () {
      expect(sanitizePathSegment('a' * 200).length, 120);
    });

    test('a slash inside a tag value never adds a folder level', () {
      final plan = buildLibraryNamingPlan(
        const LibraryNamingFormat(dirTemplate: '{artist}'),
        example(artist: 'A/B'),
      );
      expect(plan!.relativeDir, 'A_B');
    });
  });
}
