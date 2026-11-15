import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/audio_handler.dart';
import 'package:lain/base/data/lrc_document.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/services/logger.dart';
import 'package:lain/base/services/lyric.dart';
import 'package:lain/base/services/metadata_write.dart';
import 'package:lain/base/widgets/apple_form.dart';
import 'package:lain/base/widgets/local_music_page.dart';
import 'package:lain/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// Edits the line-level timestamps of one song's lyrics against its own audio.
///
/// Opened from the metadata editor it only returns the text; opened from a song
/// menu it writes the tag itself. Either way the value is written into the
/// embedded lyric tag - an existing `.lrc` sidecar is updated so other players
/// see it too, but a new sidecar is never created.
class LyricTimelinePage extends StatefulWidget {
  final MyAudioMetadata song;

  /// When true the page is a text picker for the metadata editor: it decodes no
  /// audio and pops the serialized lyrics instead of writing them.
  final bool returnOnly;

  const LyricTimelinePage({
    super.key,
    required this.song,
    required this.returnOnly,
  });

  @override
  State<LyricTimelinePage> createState() => _LyricTimelinePageState();
}

class _LyricTimelinePageState extends State<LyricTimelinePage> {
  late final MyAudioMetadata song = widget.song;

  final _scrollController = ScrollController();

  /// The player state to put back when this page closes.
  LyricPreviewBookmark? _bookmark;

  LrcDocument? _document;
  String _originalText = '';
  bool _ttml = false;
  bool _dirty = false;
  bool _saving = false;
  bool _playing = false;

  int? _activeIndex;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  final Map<String, TextEditingController> _stampControllers = {};
  final Map<String, TextEditingController> _primaryControllers = {};
  final Map<String, TextEditingController> _secondaryControllers = {};
  final Map<String, GlobalKey> _rowKeys = {};

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final text = await _initialLyrics(song);
    if (!mounted) {
      return;
    }
    _originalText = text;
    _ttml = looksLikeTtml(text);
    // The main player is borrowed for the preview, so the editor has exactly
    // the controls and the sound the rest of the app has; entering the page
    // pauses the current track first, and leaving it puts that back.
    await _startPreview();
    if (_ttml) {
      // The page still needs a document object to build against; it is empty
      // on purpose, and the body shows the "not editable" note instead of rows.
      _document = LrcDocument.parse('');
      setState(() {});
      return;
    }
    _document = LrcDocument.parse(text);
    _buildControllers();
    _activeIndex = _document!.groups.isEmpty ? null : 0;
    setState(() {});
  }

  Future<void> _startPreview() async {
    final path = song.path;
    if (path == null || !File(path).existsSync()) {
      return;
    }
    try {
      _bookmark = await audioHandler.startLyricPreview(song);
    } catch (e) {
      logger.output('[lyric timeline] preview start failed: $e');
      return;
    }
    _playing = isPlayingNotifier.value;
    isPlayingNotifier.addListener(_onPlayingChanged);
    _positionSub = audioHandler.getPositionStream().listen((position) {
      if (mounted) {
        setState(() => _position = position);
      }
    });
    _durationSub = audioHandler.getDurationStream().listen((duration) {
      if (mounted) {
        setState(() => _duration = duration);
      }
    });
    final knownDuration = audioHandler.getCurrentDuration();
    if (knownDuration > Duration.zero) {
      _duration = knownDuration;
    }
  }

  void _onPlayingChanged() {
    if (mounted) {
      setState(() => _playing = isPlayingNotifier.value);
    }
  }

  /// Hands the player back to what it was playing before this page opened.
  Future<void> _restorePlayback() async {
    final bookmark = _bookmark;
    if (bookmark == null) {
      return;
    }
    _bookmark = null;
    try {
      await audioHandler.stopLyricPreview(bookmark);
    } catch (e) {
      logger.output('[lyric timeline] preview restore failed: $e');
    }
  }

  Future<String> _initialLyrics(MyAudioMetadata song) async {
    final embedded = song.lyrics;
    if (embedded != null && embedded.trim().isNotEmpty) {
      return embedded;
    }
    final path = song.path;
    if (path == null) {
      return '';
    }
    final stem = path.substring(0, path.lastIndexOf('.'));
    for (final ext in const ['.lrc', '.ttml', '.xml']) {
      final file = File('$stem$ext');
      if (file.existsSync()) {
        try {
          final text = await file.readAsString();
          if (text.trim().isNotEmpty) {
            return text;
          }
        } catch (e) {
          logger.output('[lyric timeline] sidecar read failed: $e');
        }
      }
    }
    return '';
  }

  void _buildControllers() {
    for (final group in _document?.groups ?? const <LrcLineGroup>[]) {
      _stampControllers[group.localId] = TextEditingController(
        text: group.start == null ? '' : formatLrcTimestamp(group.start!),
      );
      _primaryControllers[group.localId] = TextEditingController(
        text: group.primary,
      );
      _secondaryControllers[group.localId] = TextEditingController(
        text: group.secondary ?? '',
      );
      _rowKeys[group.localId] = GlobalKey();
    }
  }

  void _disposeControllers() {
    for (final controller in [
      ..._stampControllers.values,
      ..._primaryControllers.values,
      ..._secondaryControllers.values,
    ]) {
      controller.dispose();
    }
    _stampControllers.clear();
    _primaryControllers.clear();
    _secondaryControllers.clear();
    _rowKeys.clear();
  }

  @override
  void dispose() {
    isPlayingNotifier.removeListener(_onPlayingChanged);
    _positionSub?.cancel();
    _durationSub?.cancel();
    unawaited(_restorePlayback());
    _scrollController.dispose();
    _disposeControllers();
    super.dispose();
  }

  bool get _hasUnsavedChanges => _dirty;

  void _markDirty() {
    if (!_dirty) {
      _dirty = true;
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) {
      return true;
    }
    final l10n = AppLocalizations.of(context);
    return showConfirmDialog(context, l10n.discardChanges);
  }

  // ---- actions -------------------------------------------------------------

  void _select(int index) {
    if (_activeIndex == index) {
      return;
    }
    setState(() => _activeIndex = index);
    _reveal(index);
  }

  void _moveSelection(int delta) {
    final groups = _document?.groups;
    if (groups == null || groups.isEmpty) {
      return;
    }
    final next = ((_activeIndex ?? 0) + delta).clamp(0, groups.length - 1);
    _select(next);
  }

  void _reveal(int index) {
    final groups = _document?.groups;
    if (groups == null || index < 0 || index >= groups.length) {
      return;
    }
    final key = _rowKeys[groups[index].localId];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = key?.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 200),
          alignment: 0.3,
        );
      }
    });
  }

  Future<void> _stamp() async {
    final groups = _document?.groups;
    if (groups == null || groups.isEmpty) {
      return;
    }
    final index = _activeIndex ?? 0;
    final group = groups[index];
    group.start = _position;
    _stampControllers[group.localId]?.text = formatLrcTimestamp(_position);
    _markDirty();
    final next = index < groups.length - 1 ? index + 1 : index;
    setState(() => _activeIndex = next);
    _reveal(next);
  }

  void _commitTimestamp(LrcLineGroup group) {
    final controller = _stampControllers[group.localId];
    if (controller == null) {
      return;
    }
    if (controller.text.trim().isEmpty) {
      group.start = null;
      _markDirty();
      return;
    }
    final parsed = parseLrcTimestampInput(controller.text);
    if (parsed == null) {
      controller.text = group.start == null
          ? ''
          : formatLrcTimestamp(group.start!);
      showCenterMessage(AppLocalizations.of(context).invalidTimeFormat);
      return;
    }
    group.start = parsed;
    controller.text = formatLrcTimestamp(parsed);
    _markDirty();
  }

  void _addSecondary() {
    final groups = _document?.groups;
    if (groups == null || groups.isEmpty) {
      return;
    }
    final index = _activeIndex ?? 0;
    final group = groups[index];
    if (group.secondary != null) {
      return;
    }
    group.secondary = '';
    _secondaryControllers[group.localId] = TextEditingController();
    _markDirty();
    setState(() {});
  }

  void _addBelow() {
    final document = _document;
    if (document == null) {
      return;
    }
    final index = _activeIndex ?? document.groups.length - 1;
    final above = document.groups.isEmpty
        ? null
        : document.groups[index.clamp(0, document.groups.length - 1)];
    final start = above?.start == null
        ? null
        : above!.start! + const Duration(milliseconds: 100);
    final group = LrcLineGroup(
      'lrc-${DateTime.now().microsecondsSinceEpoch}',
      start,
      '',
    );
    document.groups.insert(above == null ? 0 : index + 1, group);
    _stampControllers[group.localId] = TextEditingController(
      text: start == null ? '' : formatLrcTimestamp(start),
    );
    _primaryControllers[group.localId] = TextEditingController();
    _secondaryControllers[group.localId] = TextEditingController();
    _rowKeys[group.localId] = GlobalKey();
    _markDirty();
    final newIndex = above == null ? 0 : index + 1;
    setState(() => _activeIndex = newIndex);
    _reveal(newIndex);
  }

  void _deleteGroup() {
    final document = _document;
    if (document == null || document.groups.isEmpty) {
      return;
    }
    final index = (_activeIndex ?? 0).clamp(0, document.groups.length - 1);
    final group = document.groups[index];
    final secondary = group.secondary;
    if (secondary == null) {
      document.groups.removeAt(index);
      _removeControllers(group.localId);
      if (document.groups.isEmpty) {
        _activeIndex = null;
      } else {
        _activeIndex = index >= document.groups.length
            ? document.groups.length - 1
            : index;
      }
    } else {
      // Deleting the primary line promotes its secondary to primary, which is
      // what the reference editor does; the words are not thrown away.
      group.primary = secondary;
      group.secondary = null;
      _primaryControllers[group.localId]?.text = secondary;
      _secondaryControllers.remove(group.localId)?.dispose();
    }
    _markDirty();
    setState(() {});
  }

  void _removeControllers(String localId) {
    _stampControllers.remove(localId)?.dispose();
    _primaryControllers.remove(localId)?.dispose();
    _secondaryControllers.remove(localId)?.dispose();
    _rowKeys.remove(localId);
  }

  void _stripWordTimestamps() {
    final document = _document;
    if (document == null || !document.hasWordTimestamps) {
      return;
    }
    document.stripWordTimestamps();
    for (final group in document.groups) {
      _primaryControllers[group.localId]?.text = group.primary;
      _secondaryControllers[group.localId]?.text = group.secondary ?? '';
    }
    _markDirty();
    setState(() {});
  }

  Future<void> _bakeOffset() async {
    final document = _document;
    if (document == null || song.lyricsTimeOffset == 0) {
      return;
    }
    final offset = song.lyricsTimeOffset;
    document.bakeOffset(offset);
    song.lyricsTimeOffset = 0;
    await library.updateLyricsTimeOffset(song);
    for (final group in document.groups) {
      _stampControllers[group.localId]?.text = group.start == null
          ? ''
          : formatLrcTimestamp(group.start!);
    }
    _markDirty();
    setState(() {});
  }

  Future<void> _reset() async {
    if (_dirty && !await _confirmDiscard()) {
      return;
    }
    _disposeControllers();
    setState(() {
      _document = LrcDocument.parse(_originalText);
      _ttml = looksLikeTtml(_originalText);
      _dirty = false;
      _activeIndex = _document!.groups.isEmpty ? null : 0;
    });
    _buildControllers();
    setState(() {});
  }

  Future<void> _save() async {
    final document = _document;
    if (document == null || _saving) {
      return;
    }
    final text = document.serialize();
    if (widget.returnOnly) {
      Navigator.of(context).pop(text);
      return;
    }
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context);
    final ok = await writeSongTags(
      song: song,
      lyrics: text,
      lyricsChanged: true,
    );
    if (!mounted) {
      return;
    }
    if (ok) {
      await _updateExistingSidecar(text);
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      showCenterMessage(l10n.saveSuccessfully);
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _saving = false);
    showCenterMessage(l10n.saveFailed);
  }

  /// Writes the same text to a sidecar that already exists, so other players
  /// see it; a song without one is left without one.
  Future<void> _updateExistingSidecar(String text) async {
    final path = song.path;
    if (path == null) {
      return;
    }
    final stem = path.substring(0, path.lastIndexOf('.'));
    final sidecar = File('$stem.lrc');
    try {
      if (sidecar.existsSync()) {
        await sidecar.writeAsString(text);
      }
    } catch (e) {
      logger.output('[lyric timeline] sidecar update failed: $e');
      if (mounted) {
        showCenterMessage(AppLocalizations.of(context).sidecarUpdateFailed);
      }
    }
  }

  void _seek(int seconds) {
    final target = _position + Duration(seconds: seconds);
    final clamped = Duration(
      milliseconds: target.inMilliseconds.clamp(0, _duration.inMilliseconds),
    );
    unawaited(audioHandler.seek(clamped));
    _selectNearest(clamped);
  }

  void _selectNearest(Duration position) {
    final groups = _document?.groups;
    if (groups == null || groups.isEmpty) {
      return;
    }
    var best = 0;
    Duration? bestDiff;
    for (var i = 0; i < groups.length; i++) {
      final start = groups[i].start;
      if (start == null) {
        continue;
      }
      final diff = (start - position).abs();
      if (bestDiff == null || diff < bestDiff) {
        bestDiff = diff;
        best = i;
      }
    }
    _select(best);
  }

  // ---- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    assert(isLocalLibrary);
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();

    if (_document == null) {
      return opaqueSettingsPage(
        context: context,
        title: l10n.lyricTimeline,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        if (await _confirmDiscard() && context.mounted) {
          setState(() => _dirty = false);
          Navigator.of(context).pop();
        }
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter, shift: true):
              _stamp,
          const SingleActivator(LogicalKeyboardKey.space, shift: true):
              () => _togglePlay(),
          const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true):
              () => _seek(-5),
          const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true):
              () => _seek(5),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
              _moveSelection(-1),
          const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
              _moveSelection(1),
        },
        child: opaqueSettingsPage(
          context: context,
          title: l10n.lyricTimeline,
          actions: [
            TextButton(
              onPressed: _reset,
              child: Text(
                l10n.reset,
                style: TextStyle(fontSize: 15, color: textColor),
              ),
            ),
            if (!_ttml)
              TextButton(
                onPressed: _saving ? null : _save,
                child: Text(
                  l10n.save,
                  style: TextStyle(fontSize: 15, color: textColor),
                ),
              ),
          ],
          body: Column(
            children: [
              _songHeader(context),
              _playerSection(context),
              if (song.lyricsTimeOffset != 0) _offsetSection(context),
              if (_document!.hasWordTimestamps) _wordTimestampSection(context),
              Expanded(child: _list(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _songHeader(BuildContext context) {
    final textColor = colorManager.getSpecificTextColor();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            song.title ?? p.basenameWithoutExtension(song.path ?? ''),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, color: textColor),
          ),
          Text(
            '${song.artist ?? ''} - ${song.album ?? ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: textColor.withAlpha(150)),
          ),
        ],
      ),
    );
  }

  void _togglePlay() {
    if (isPlayingNotifier.value) {
      unawaited(audioHandler.pause());
    } else {
      unawaited(audioHandler.play());
    }
  }

  Widget _playerSection(BuildContext context) {
    final textColor = colorManager.getSpecificTextColor();
    return AppleFormSection(
      divided: false,
      children: [
        appleFormRow(
          AppLocalizations.of(context).progress,
          Text(
            '${formatLrcTimestamp(_position)} / '
            '${formatLrcTimestamp(_duration)}',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 14, color: textColor),
          ),
        ),
        Slider(
          value: _duration.inMilliseconds == 0
              ? 0
              : _position.inMilliseconds
                    .clamp(0, _duration.inMilliseconds)
                    .toDouble(),
          max: _duration.inMilliseconds == 0
              ? 1
              : _duration.inMilliseconds.toDouble(),
          onChanged: (value) {
            final target = Duration(milliseconds: value.round());
            setState(() => _position = target);
          },
          onChangeEnd: (value) {
            final target = Duration(milliseconds: value.round());
            unawaited(audioHandler.seek(target));
            _selectNearest(target);
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.replay_5_rounded),
              color: textColor,
              onPressed: () => _seek(-5),
            ),
            IconButton(
              icon: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
              color: textColor,
              iconSize: 32,
              onPressed: _togglePlay,
            ),
            IconButton(
              icon: const Icon(Icons.forward_5_rounded),
              color: textColor,
              onPressed: () => _seek(5),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: _stamp,
              icon: Icon(Icons.schedule_rounded, color: textColor),
              label: Text(
                AppLocalizations.of(context).stamp,
                style: TextStyle(color: textColor),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _offsetSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppleFormSection(
      divided: false,
      children: [
        appleFormRow(
          l10n.playbackOffset,
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${song.lyricsTimeOffset > 0 ? '+' : ''}'
                '${(song.lyricsTimeOffset / 1000).toStringAsFixed(2)}s',
                style: TextStyle(
                  fontSize: 14,
                  color: colorManager.getSpecificTextColor(),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _bakeOffset,
                child: Text(
                  l10n.bakeOffset,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _wordTimestampSection(BuildContext context) {
    return AppleFormSection(
      divided: false,
      children: [
        appleFormRow(
          AppLocalizations.of(context).wordTimestamps,
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _stripWordTimestamps,
              child: Text(
                AppLocalizations.of(context).stripWordTimestamps,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _list(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();
    if (_ttml) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Text(
            l10n.ttmlNotEditable,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: textColor.withAlpha(150)),
          ),
        ),
      );
    }
    final groups = _document!.groups;
    if (groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.noLyricLines,
              style: TextStyle(fontSize: 14, color: textColor.withAlpha(150)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 180,
              child: appleFilledButton(l10n.addLine, _addBelow),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 100, top: 6),
      itemCount: groups.length,
      itemBuilder: (context, index) => _row(context, groups[index], index),
    );
  }

  Widget _row(BuildContext context, LrcLineGroup group, int index) {
    final textColor = colorManager.getSpecificTextColor();
    final selected = _activeIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _select(index),
      child: Container(
        key: _rowKeys[group.localId],
        color: selected ? textColor.withAlpha(38) : Colors.transparent,
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 86,
              child: TextField(
                controller: _stampControllers[group.localId],
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  color: textColor,
                  fontFeatures: [ui.FontFeature.tabularFigures()],
                ),
                cursorColor: textColor,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: '00:00.00',
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                onSubmitted: (_) => _commitTimestamp(group),
                onEditingComplete: () => _commitTimestamp(group),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _primaryControllers[group.localId],
                    style: TextStyle(fontSize: 15, color: textColor),
                    cursorColor: textColor,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 6),
                    ),
                    onChanged: (value) {
                      group.primary = value;
                      _markDirty();
                    },
                  ),
                  if (group.secondary != null)
                    TextField(
                      controller: _secondaryControllers[group.localId],
                      style: TextStyle(
                        fontSize: 13,
                        color: textColor.withAlpha(170),
                      ),
                      cursorColor: textColor,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: '翻译',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: textColor.withAlpha(90),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 2,
                        ),
                      ),
                      onChanged: (value) {
                        group.secondary = value;
                        _markDirty();
                      },
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.schedule_rounded),
              color: textColor,
              onPressed: () {
                _select(index);
                _stamp();
              },
            ),
            PopupMenuButton<String>(
              color: colorManager.getSpecificOpaqueBgColor(),
              icon: Icon(Icons.more_vert_rounded, color: textColor),
              onSelected: (value) {
                _select(index);
                switch (value) {
                  case 'secondary':
                    _addSecondary();
                  case 'below':
                    _addBelow();
                  case 'delete':
                    _deleteGroup();
                }
              },
              itemBuilder: (context) {
                final l10n = AppLocalizations.of(context);
                return [
                  PopupMenuItem(
                    value: 'secondary',
                    enabled: group.secondary == null,
                    child: Text(l10n.addSecondaryLine),
                  ),
                  PopupMenuItem(
                    value: 'below',
                    child: Text(l10n.addLineBelow),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      l10n.delete,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}
