import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// The library's file/folder naming templates, and the pure string work of
/// turning one song's tags into a path inside the library root.
///
/// Only this file decides how a template is rendered and what a path segment
/// may contain; the organizer and its page both call in here so a preview and
/// the execution can never disagree.

const String defaultLibraryDirTemplate = '{artist}/{album}';
const String defaultLibraryFileTemplate = '{track:02}. {title}';

/// Placeholder names as they are written in a template, for the hint shown on
/// the naming page.
const List<String> libraryNamingPlaceholderNames = [
  'artist',
  'albumArtist',
  'album',
  'title',
  'track',
  'disc',
  'year',
  'ext',
];

/// The same names in comparison form; template lookup is case-insensitive.
const Set<String> libraryNamingPlaceholders = {
  'artist',
  'albumartist',
  'album',
  'title',
  'track',
  'disc',
  'year',
  'ext',
};

final libraryDirTemplateNotifier = ValueNotifier(defaultLibraryDirTemplate);
final libraryFileTemplateNotifier = ValueNotifier(defaultLibraryFileTemplate);
final libraryKeepFeatNotifier = ValueNotifier(true);

class LibraryNamingFormat {
  final String dirTemplate;
  final String fileTemplate;
  final bool keepFeat;

  const LibraryNamingFormat({
    this.dirTemplate = defaultLibraryDirTemplate,
    this.fileTemplate = defaultLibraryFileTemplate,
    this.keepFeat = true,
  });

  static LibraryNamingFormat get current => LibraryNamingFormat(
    dirTemplate: libraryDirTemplateNotifier.value,
    fileTemplate: libraryFileTemplateNotifier.value,
    keepFeat: libraryKeepFeatNotifier.value,
  );

  LibraryNamingFormat copyWith({
    String? dirTemplate,
    String? fileTemplate,
    bool? keepFeat,
  }) {
    return LibraryNamingFormat(
      dirTemplate: dirTemplate ?? this.dirTemplate,
      fileTemplate: fileTemplate ?? this.fileTemplate,
      keepFeat: keepFeat ?? this.keepFeat,
    );
  }

  Map<String, dynamic> toJson() => {
    'dirTemplate': dirTemplate,
    'fileTemplate': fileTemplate,
    'keepFeat': keepFeat,
  };

  factory LibraryNamingFormat.fromJson(Object? raw) {
    if (raw is! Map) {
      return const LibraryNamingFormat();
    }
    return LibraryNamingFormat(
      dirTemplate: raw['dirTemplate']?.toString() ?? defaultLibraryDirTemplate,
      fileTemplate:
          raw['fileTemplate']?.toString() ?? defaultLibraryFileTemplate,
      keepFeat: raw['keepFeat'] as bool? ?? true,
    );
  }
}

enum NamingTemplateError {
  empty,
  missingTitle,
  absolutePath,
  parentSegment,
  unknownPlaceholder,
}

final RegExp _placeholder = RegExp(r'\{([A-Za-z][A-Za-z0-9]*)(?::(\d+))?\}');

Set<String> namingPlaceholdersIn(String template) {
  return {
    for (final match in _placeholder.allMatches(template))
      match.group(1)!.toLowerCase(),
  };
}

/// Why [template] cannot be used, or null when it can.
NamingTemplateError? validateNamingTemplate(
  String template, {
  required bool directory,
}) {
  final trimmed = template.trim();
  if (trimmed.isEmpty) {
    return NamingTemplateError.empty;
  }
  if (trimmed.startsWith('/') ||
      trimmed.startsWith('\\') ||
      RegExp(r'^[A-Za-z]:').hasMatch(trimmed)) {
    return NamingTemplateError.absolutePath;
  }
  final segments = trimmed.split('/');
  if (segments.any((segment) => segment.trim() == '..')) {
    return NamingTemplateError.parentSegment;
  }
  final placeholders = namingPlaceholdersIn(trimmed);
  if (placeholders.any((name) => !libraryNamingPlaceholders.contains(name))) {
    return NamingTemplateError.unknownPlaceholder;
  }
  if (!directory && !placeholders.contains('title')) {
    return NamingTemplateError.missingTitle;
  }
  return null;
}

const Set<String> _windowsReservedNames = {
  'con',
  'prn',
  'aux',
  'nul',
  'com1',
  'com2',
  'com3',
  'com4',
  'com5',
  'com6',
  'com7',
  'com8',
  'com9',
  'lpt1',
  'lpt2',
  'lpt3',
  'lpt4',
  'lpt5',
  'lpt6',
  'lpt7',
  'lpt8',
  'lpt9',
};

/// Makes [input] safe as one path segment on every platform the app runs on.
///
/// Template literals decide the folder levels; a value a tag carries must never
/// be able to add one, so separators become `_`. Windows' own restrictions are
/// applied everywhere as well - a library synced between platforms must not
/// contain names that only one of them accepts.
String sanitizePathSegment(String input, {String fallback = 'Unknown'}) {
  var out = input.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  out = out.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  out = out.replaceAll(RegExp(r'\s+'), ' ');
  out = out.trim();
  if (out.isEmpty) {
    return fallback.isEmpty ? '_' : fallback;
  }
  if (out == '.' || out == '..') {
    return '_';
  }
  // A trailing dot or space is dropped (or rejected) by Windows itself.
  out = out.replaceAll(RegExp(r'[. ]+$'), '_');
  if (out.startsWith('-')) {
    out = '_$out';
  }
  final stem = out.split('.').first.toLowerCase();
  if (_windowsReservedNames.contains(stem)) {
    out = '${out}_';
  }
  if (out.length > 120) {
    out = out.substring(0, 120);
  }
  return out.isEmpty ? (fallback.isEmpty ? '_' : fallback) : out;
}

/// Everything the templates may read from one song. Kept separate from
/// [MyAudioMetadata] so the rendering is a pure function that can be tested.
class NamingInput {
  final String? title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final int? track;
  final int? disc;
  final int? year;

  /// The origin file's extension, including the dot; may be empty.
  final String ext;

  /// The origin file's name without its extension, used when the title is
  /// missing and for the example preview.
  final String fileName;

  const NamingInput({
    this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.track,
    this.disc,
    this.year,
    this.ext = '',
    this.fileName = '',
  });
}

class LibraryNamingPlan {
  /// Folder path relative to the library root, platform separated; empty when
  /// the folder template renders to nothing.
  final String relativeDir;

  /// File name including its extension.
  final String fileName;

  const LibraryNamingPlan({required this.relativeDir, required this.fileName});
}

final RegExp _featPattern = RegExp(
  r'[\(\（\[]\s*feat\.?\s*([^\)\）\]]+?)\s*[\)\）\]]',
  caseSensitive: false,
);

/// `Title (feat. X)` -> title `Title`, credit `X`.
({String title, String? feat}) splitFeat(String title) {
  final match = _featPattern.firstMatch(title);
  if (match == null) {
    return (title: title, feat: null);
  }
  final before = title.substring(0, match.start).trim();
  final feat = match.group(1)?.trim();
  if (before.isEmpty || feat == null || feat.isEmpty) {
    return (title: title, feat: null);
  }
  return (title: before, feat: feat);
}

String _render(String template, Map<String, String> values) {
  return template.replaceAllMapped(_placeholder, (match) {
    final name = match.group(1)!.toLowerCase();
    var value = values[name] ?? '';
    final width = int.tryParse(match.group(2) ?? '');
    if (width != null && width > 0 && value.isNotEmpty) {
      value = value.padLeft(width, '0');
    }
    return value;
  });
}

/// Renders [format] for [input]. Returns null when either template is invalid.
LibraryNamingPlan? buildLibraryNamingPlan(
  LibraryNamingFormat format,
  NamingInput input,
) {
  if (validateNamingTemplate(format.dirTemplate, directory: true) != null ||
      validateNamingTemplate(format.fileTemplate, directory: false) != null) {
    return null;
  }

  var title = (input.title == null || input.title!.trim().isEmpty)
      ? input.fileName
      : input.title!.trim();
  String? feat;
  if (format.keepFeat) {
    final split = splitFeat(title);
    title = split.title;
    feat = split.feat;
  }

  final artist = (input.artist == null || input.artist!.trim().isEmpty)
      ? 'Unknown Artist'
      : input.artist!.trim();
  final albumArtistRaw = input.albumArtist?.trim();
  final albumArtist = (albumArtistRaw == null || albumArtistRaw.isEmpty)
      ? artist
      : albumArtistRaw;
  final album = (input.album == null || input.album!.trim().isEmpty)
      ? 'Unknown Album'
      : input.album!.trim();

  final values = <String, String>{
    'artist': artist,
    'albumartist': albumArtist,
    'album': album,
    'title': feat == null ? title : '$title - feat. $feat',
    'track': input.track?.toString() ?? '00',
    'disc': input.disc?.toString() ?? '01',
    'year': input.year == null
        ? '0000'
        : input.year!.toString().padLeft(4, '0'),
    'ext': input.ext,
  };

  final dirSegments = <String>[];
  for (final raw in format.dirTemplate.trim().split('/')) {
    final rendered = _render(raw, values);
    final segment = sanitizePathSegment(rendered, fallback: 'Unknown');
    if (segment.isNotEmpty) {
      dirSegments.add(segment);
    }
  }

  final fileTemplateHasExt = namingPlaceholdersIn(format.fileTemplate).contains(
    'ext',
  );
  var renderedFile = _render(format.fileTemplate, values).trim();
  if (!fileTemplateHasExt) {
    renderedFile = '$renderedFile${input.ext}';
  }

  // The extension is the origin file's, and it is appended by the template or
  // by the line above; only the stem is sanitized, so `.mp3` stays `.mp3`.
  String nameOnly = renderedFile;
  if (input.ext.isNotEmpty && nameOnly.toLowerCase().endsWith(input.ext.toLowerCase())) {
    nameOnly = nameOnly.substring(0, nameOnly.length - input.ext.length);
  }
  final stem = sanitizePathSegment(nameOnly, fallback: 'Untitled');
  final fileName = '$stem${input.ext}';
  if (fileName == input.ext || stem == 'Untitled') {
    // A template that rendered to just its extension would produce a nameless
    // file; the fallback title keeps the preview honest.
    return LibraryNamingPlan(
      relativeDir: p.joinAll(dirSegments),
      fileName: 'Untitled${input.ext}',
    );
  }

  return LibraryNamingPlan(
    relativeDir: p.joinAll(dirSegments),
    fileName: fileName,
  );
}

/// The example shown on the naming page: one fixed set of tags, so a template
/// can be read before anything is touched.
NamingInput get namingExampleInput => const NamingInput(
  title: 'Song (feat. Guest)',
  artist: 'Artist',
  album: 'Album',
  albumArtist: 'Artist',
  track: 3,
  year: 2026,
  ext: '.mp3',
  fileName: 'song',
);
