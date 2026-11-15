/// An LRC document in the shape the timeline editor needs: header lines kept
/// verbatim, then the timed line groups, where two lines sharing one timestamp
/// are one group's primary and secondary text.
///
/// The editor is line-level only. Per-word timestamps are detected so the page
/// can offer to strip them instead of silently dropping them on save.
library;

class LrcLineGroup {
  /// Stable identity for the list, so editing a line does not rebuild the
  /// widget with another row's state.
  final String localId;

  /// Null for a line of a document that has no timestamps at all.
  Duration? start;

  String primary;
  String? secondary;

  LrcLineGroup(this.localId, this.start, this.primary, [this.secondary]);

  LrcLineGroup copy() =>
      LrcLineGroup(localId, start, primary, secondary);
}

class LrcDocument {
  /// `[ti:]`, `[ar:]` and untimed text kept as written.
  final List<String> headerLines;
  final List<LrcLineGroup> groups;
  final bool hasWordTimestamps;

  LrcDocument({
    required this.headerLines,
    required this.groups,
    this.hasWordTimestamps = false,
  });

  bool get isEmpty => groups.isEmpty;

  static final RegExp _timeLine = RegExp(
    r'^\s*[\[<](\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?[\]>](.*)$',
  );
  static final RegExp _tagLine = RegExp(r'^\s*\[([A-Za-z]+):(.*)\]\s*$');
  static final RegExp _wordTimestamp = RegExp(
    r'[\[<]\d{1,3}:\d{1,2}(?:[.:]\d{1,3})?[\]>]',
  );

  static Duration _duration(String minutes, String seconds, String? fraction) {
    final millis = fraction == null
        ? 0
        : int.parse(fraction.padRight(3, '0'));
    return Duration(
      minutes: int.parse(minutes),
      seconds: int.parse(seconds),
      milliseconds: millis,
    );
  }

  factory LrcDocument.parse(String text) {
    final header = <String>[];
    final groups = <LrcLineGroup>[];
    var hasWordTimestamps = false;
    var index = 0;

    final rawLines = text.split(RegExp(r'\r?\n'));
    final parsed = <({Duration? start, String text})>[];

    for (final raw in rawLines) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        continue;
      }
      final time = _timeLine.firstMatch(line);
      if (time != null) {
        final body = time.group(4) ?? '';
        if (_wordTimestamp.hasMatch(body)) {
          hasWordTimestamps = true;
        }
        parsed.add((
          start: _duration(time.group(1)!, time.group(2)!, time.group(3)),
          text: body,
        ));
        continue;
      }
      final tag = _tagLine.firstMatch(line);
      if (tag != null) {
        header.add(line);
        continue;
      }
      // Untimed text: a document without any timestamp keeps it as an editable
      // line; otherwise it is part of the preamble and kept verbatim.
      parsed.add((start: null, text: line));
    }

    final anyTimed = parsed.any((line) => line.start != null);
    for (final line in parsed) {
      if (line.start == null && anyTimed) {
        header.add(line.text);
        continue;
      }
      final last = groups.isEmpty ? null : groups.last;
      if (last != null &&
          last.start != null &&
          line.start != null &&
          last.start == line.start &&
          last.secondary == null) {
        last.secondary = line.text;
        continue;
      }
      groups.add(
        LrcLineGroup('lrc-${index++}', line.start, line.text),
      );
    }

    return LrcDocument(
      headerLines: header,
      groups: groups,
      hasWordTimestamps: hasWordTimestamps,
    );
  }

  String serialize() {
    final buffer = StringBuffer();
    for (final line in headerLines) {
      buffer.writeln(line);
    }
    for (final group in groups) {
      final start = group.start;
      if (start == null) {
        buffer.writeln(group.primary);
        continue;
      }
      final stamp = '[${formatLrcTimestamp(start)}]';
      buffer.writeln('$stamp${group.primary}');
      final secondary = group.secondary;
      if (secondary != null && secondary.isNotEmpty) {
        buffer.writeln('$stamp$secondary');
      }
    }
    return buffer.toString().trimRight();
  }

  /// Removes every `<mm:ss.xx>` from a line, leaving its line timestamp.
  void stripWordTimestamps() {
    for (final group in groups) {
      group.primary = group.primary
          .replaceAll(_wordTimestamp, '')
          .trim();
      if (group.secondary != null) {
        group.secondary = group.secondary!
            .replaceAll(_wordTimestamp, '')
            .trim();
      }
    }
  }

  /// Shifts every timed line by `-offset` milliseconds, which is what writing
  /// the player's offset into the text means: playback compares
  /// `position + offset` with each line, so the stored line times must move the
  /// other way to keep the same listening result.
  void bakeOffset(int offsetMillis) {
    for (final group in groups) {
      final start = group.start;
      if (start == null) {
        continue;
      }
      final shifted = start.inMilliseconds - offsetMillis;
      group.start = Duration(milliseconds: shifted < 0 ? 0 : shifted);
    }
  }
}

String formatLrcTimestamp(Duration duration) {
  final totalMillis = duration.inMilliseconds;
  final minutes = totalMillis ~/ 60000;
  final seconds = (totalMillis % 60000) ~/ 1000;
  final centis = (totalMillis % 1000) ~/ 10;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}.'
      '${centis.toString().padLeft(2, '0')}';
}

/// Parses what the user typed into a timestamp field: `mm:ss`, `mm:ss.x`,
/// `mm:ss.xx` or `mm:ss.xxx`. Anything else (including `1:2.3`) is rejected so
/// the saved file stays readable by the app's own parser.
Duration? parseLrcTimestampInput(String input) {
  final match = RegExp(
    r'^\s*(\d{2,3}):([0-5]\d)(?:\.(\d{1,3}))?\s*$',
  ).firstMatch(input);
  if (match == null) {
    return null;
  }
  final seconds = int.parse(match.group(2)!);
  if (seconds > 59) {
    return null;
  }
  final fraction = match.group(3);
  return Duration(
    minutes: int.parse(match.group(1)!),
    seconds: seconds,
    milliseconds: fraction == null ? 0 : int.parse(fraction.padRight(3, '0')),
  );
}
