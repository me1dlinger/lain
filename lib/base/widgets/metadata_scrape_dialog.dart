import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:lain/base/data/loader.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/services/metadata_scraper.dart';
import 'package:lain/base/services/metadata_write.dart';
import 'package:lain/base/services/picture_service.dart';
import 'package:lain/base/widgets/apple_form.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/base/widgets/scrape_candidate_deck.dart';
import 'package:lain/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// Searches NetEase and QQ for one local song's tags and writes the chosen
/// result back into the file.
///
/// The song's own artwork heads the dialog. Candidates are shown as a deck of
/// cards that can be turned one by one: the centred card is the selection, a tap
/// selects it, and a long press applies it immediately. The mode switch decides
/// whether empty fields are filled or existing values are replaced, and it is
/// always visible - the user chooses, this dialog does not pick for them.
class MetadataScrapeDialog extends StatefulWidget {
  final MyAudioMetadata song;

  /// Kept for callers that used to close on apply; the dialog now stays open so
  /// the single-step undo is reachable, and closes when the user asks.
  final bool returnAfterApply;

  const MetadataScrapeDialog({
    super.key,
    required this.song,
    this.returnAfterApply = true,
  });

  @override
  State<MetadataScrapeDialog> createState() => _MetadataScrapeDialogState();
}

class _MetadataScrapeDialogState extends State<MetadataScrapeDialog> {
  late final MyAudioMetadata song = widget.song;

  late final TextEditingController _titleController;
  late final TextEditingController _artistController;
  late final TextEditingController _albumController;
  late final TextEditingController _trackController;
  late final TextEditingController _yearController;

  final ValueNotifier<bool> _writeCover = ValueNotifier(true);
  final ValueNotifier<bool> _writeLyrics = ValueNotifier(false);

  ScrapeWriteMode _mode = ScrapeWriteMode.fillEmpty;
  MetadataScrapeResult? _result;
  bool _searching = false;
  bool _applying = false;
  bool _applied = false;
  bool _undoing = false;
  ScrapedCandidate? _selected;
  int _deckRevision = 0;
  final Set<String> _excluded = {};

  @override
  void initState() {
    super.initState();
    final query = buildMetadataQuery(song);
    _titleController = TextEditingController(text: query.title ?? '');
    _artistController = TextEditingController(text: query.artist ?? '');
    _albumController = TextEditingController(text: query.album ?? '');
    _trackController = TextEditingController(
      text: query.track?.toString() ?? '',
    );
    _yearController = TextEditingController(text: query.year?.toString() ?? '');
    // The dialog shows the song's own cover; load it through the app's picture
    // pipeline so it is on disk (and in the shared cache) before it is drawn.
    unawaited(_loadOwnCover());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _search();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    _trackController.dispose();
    _yearController.dispose();
    _writeCover.dispose();
    _writeLyrics.dispose();
    super.dispose();
  }

  Future<void> _loadOwnCover() async {
    if (song.picture.isExist) {
      return;
    }
    try {
      await loadPictureSafe(song.picture);
    } catch (_) {}
    if (mounted) {
      setState(() {});
    }
  }

  MetadataQuery get _query => buildMetadataQuery(
    song,
    title: _titleController.text,
    artist: _artistController.text,
    album: _albumController.text,
    track: int.tryParse(_trackController.text),
    year: int.tryParse(_yearController.text),
    excludeIds: _excluded,
  );

  List<ScrapedCandidate> get _cards {
    final result = _result;
    if (result == null) {
      return const [];
    }
    return [
      for (final group in result.groups.values) ...group,
    ];
  }

  int get _selectedIndex {
    final key = _selected?.key;
    if (key == null) {
      return 0;
    }
    final index = _cards.indexWhere((candidate) => candidate.key == key);
    return index < 0 ? 0 : index;
  }

  Future<void> _search() async {
    if (_searching) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    if (Loader.busy) {
      showCenterMessage(l10n.syncingWait);
      return;
    }
    setState(() {
      _searching = true;
      _applied = false;
    });
    try {
      final result = await MetadataScraper.instance.search(_query);
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
        _searching = false;
        _deckRevision++;
        _applyFirstCard();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _searching = false);
      showCenterMessage('$e');
    }
  }

  void _applyFirstCard() {
    final cards = _cards;
    _selected = cards.isEmpty ? null : cards.first;
  }

  Future<void> _nextBatch(String sourceId) async {
    if (_searching) {
      return;
    }
    final provider = MetadataScraper.instance.providerOf(sourceId);
    if (provider == null) {
      return;
    }
    for (final candidate in _result?.groups[sourceId] ?? <ScrapedCandidate>[]) {
      _excluded.add(candidate.sourceId);
    }
    setState(() {
      _searching = true;
      _selected = null;
    });
    try {
      final found = await provider.search(_query);
      if (!mounted) {
        return;
      }
      final scored = <ScrapedCandidate>[
        for (final candidate in found)
          candidate.copyWith(score: scoreCandidate(_query, candidate)),
      ];
      scored.sort((a, b) => b.score.compareTo(a.score));
      final visible = [
        for (final candidate in scored)
          if (!_excluded.contains(candidate.sourceId)) candidate,
      ].take(5).toList();
      setState(() {
        final groups = Map<String, List<ScrapedCandidate>>.from(
          _result?.groups ?? const {},
        );
        if (visible.isEmpty) {
          groups.remove(sourceId);
          showCenterMessage(AppLocalizations.of(context).noMoreResults);
        } else {
          groups[sourceId] = visible;
        }
        _result = MetadataScrapeResult(
          groups: groups,
          errors: _result?.errors ?? const {},
        );
        _searching = false;
        _deckRevision++;
        _applyFirstCard();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _searching = false);
      showCenterMessage('$e');
    }
  }

  Future<void> _apply([ScrapedCandidate? target]) async {
    final candidate = target ?? _selected;
    if (candidate == null || _applying) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    if (Loader.busy) {
      showCenterMessage(l10n.syncingWait);
      return;
    }
    setState(() {
      _selected = candidate;
      _applying = true;
    });

    final snapshot = await captureSongMetadata(song);
    final values = mergeScrapedTags(
      song: song,
      candidate: candidate,
      mode: _mode,
    );

    Uint8List? coverBytes;
    if (_writeCover.value && candidate.coverUrl != null) {
      final provider = MetadataScraper.instance.providerOf(candidate.source);
      final bytes = await provider?.fetchCoverBytes(candidate);
      if (bytes != null && isValidCoverBytes(bytes)) {
        coverBytes = bytes;
      } else if (bytes != null) {
        showCenterMessage(l10n.coverSkipped);
      }
    }

    String lyrics = values.lyrics;
    var lyricsChanged = false;
    if (_writeLyrics.value) {
      final provider = MetadataScraper.instance.providerOf(candidate.source);
      final fetched = await provider?.fetchLyrics(candidate);
      if (fetched != null && fetched.trim().isNotEmpty) {
        lyrics = fetched;
        lyricsChanged = true;
      }
    }

    final ok = await writeSongTags(
      song: song,
      title: values.title,
      artist: values.artist,
      album: values.album,
      albumArtist: values.albumArtist,
      genre: values.genre,
      lyrics: lyrics,
      year: values.year,
      track: values.track,
      disc: values.disc,
      pictureBytes: coverBytes,
      lyricsChanged: lyricsChanged,
    );
    if (!mounted) {
      return;
    }
    if (ok) {
      // One step of history for this application, replacing any earlier one.
      scrapeUndo.record([(song, snapshot)]);
    }
    setState(() {
      _applying = false;
      _applied = ok;
    });
    showCenterMessage(ok ? l10n.updateSuccessfully : l10n.updateFailed);
  }

  Future<void> _undo() async {
    final l10n = AppLocalizations.of(context);
    if (_undoing || !scrapeUndo.canUndo) {
      return;
    }
    setState(() => _undoing = true);
    final ok = await scrapeUndo.undo();
    if (!mounted) {
      return;
    }
    setState(() {
      _undoing = false;
      if (ok) {
        _applied = false;
      }
    });
    showCenterMessage(ok ? l10n.undoSuccessfully : l10n.undoFailed);
  }

  void _close() {
    Navigator.of(context).pop(_applied);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = max(280.0, min(620.0, size.width - 24));
    final height = size.height - 60 < 420
        ? size.height - 60
        : size.height * 0.85;
    return SizedBox(
      width: width,
      height: max(320, height),
      child: _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();
    final cards = _cards;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
      child: Column(
        children: [
          Text(
            l10n.searchTags,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 10),
              children: [
                _songHeader(context),
                const SizedBox(height: 6),
                AppleFormSection(
                  children: [
                    appleTextFieldRow(
                      l10n.title,
                      _titleController,
                      onSubmitted: (_) => _search(),
                    ),
                    appleTextFieldRow(
                      l10n.artist,
                      _artistController,
                      onSubmitted: (_) => _search(),
                    ),
                    appleTextFieldRow(
                      l10n.album,
                      _albumController,
                      onSubmitted: (_) => _search(),
                    ),
                    appleTextFieldRow(
                      l10n.track,
                      _trackController,
                      number: true,
                      onSubmitted: (_) => _search(),
                    ),
                    appleTextFieldRow(
                      l10n.year,
                      _yearController,
                      number: true,
                      onSubmitted: (_) => _search(),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: _searching ? null : _search,
                            icon: const Icon(Icons.search_rounded, size: 18),
                            label: Text(l10n.search),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AppleFormSection(
                  divided: false,
                  children: [
                    appleSegmented<ScrapeWriteMode>(
                      ScrapeWriteMode.values,
                      (value) => value == ScrapeWriteMode.fillEmpty
                          ? l10n.scrapeFillEmpty
                          : l10n.overwriteTags,
                      _mode,
                      (value) => setState(() => _mode = value),
                    ),
                    appleSwitchRow(l10n.writeCoverToo, _writeCover),
                    appleSwitchRow(l10n.writeLyricsToo, _writeLyrics),
                  ],
                ),
                const SizedBox(height: 12),
                if (_searching)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 26),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (cards.isEmpty)
                  _empty(context)
                else ...[
                  ScrapeCandidateDeck(
                    deckKey: '${song.id}:$_deckRevision',
                    cards: cards,
                    selectedIndex: _selectedIndex,
                    sourceName: (candidate) =>
                        MetadataScraper.instance
                            .providerOf(candidate.source)
                            ?.displayName ??
                        candidate.source,
                    coverLoader: (candidate) {
                      final provider = MetadataScraper.instance.providerOf(
                        candidate.source,
                      );
                      return provider?.fetchCoverBytes(candidate) ??
                          Future<Uint8List?>.value();
                    },
                    onSelected: (index) =>
                        setState(() => _selected = cards[index]),
                    onLongPress: (candidate) => _apply(candidate),
                  ),
                  _sourceActions(context, l10n),
                  const SizedBox(height: 2),
                  Text(
                    l10n.scrapeLongPressHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: textColor.withAlpha(120),
                    ),
                  ),
                ],
                if (_selected != null) _diffSection(context),
                if (_applied) _appliedRow(context, l10n),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _applied
                      ? appleFilledButton(l10n.close, _close)
                      : appleFilledButton(
                          l10n.apply,
                          _applying || _selected == null
                              ? null
                              : () => _apply(),
                          busy: _applying,
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: appleTextButton(l10n.cancel, _close),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _songHeader(BuildContext context) {
    final textColor = colorManager.getSpecificTextColor();
    final title = (song.title == null || song.title!.trim().isEmpty)
        ? p.basenameWithoutExtension(song.path ?? '')
        : song.title!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Row(
        children: [
          CoverArtWidget(
            picture: song.picture,
            size: 96,
            borderRadius: 10,
            priorityLoad: true,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${song.artist ?? ''} · ${song.album ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withAlpha(150),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _appliedRow(BuildContext context, AppLocalizations l10n) {
    final textColor = colorManager.getSpecificTextColor();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Text(
            l10n.batchApplied(scrapeUndo.count),
            style: TextStyle(fontSize: 12, color: textColor.withAlpha(150)),
          ),
          const Spacer(),
          if (scrapeUndo.canUndo)
            TextButton(
              onPressed: _undoing ? null : _undo,
              child: Text(l10n.undoApply),
            ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();
    final errors = _result?.errors ?? const {};
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(
            l10n.noSearchResults,
            style: TextStyle(fontSize: 14, color: textColor.withAlpha(150)),
          ),
          for (final entry in errors.entries)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${entry.key}: ${entry.value}',
                style: TextStyle(fontSize: 12, color: textColor.withAlpha(120)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sourceActions(BuildContext context, AppLocalizations l10n) {
    final textColor = colorManager.getSpecificTextColor();
    final sources = _result?.groups.keys.toList() ?? const <String>[];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      children: [
        for (final sourceId in sources)
          TextButton(
            onPressed: _searching ? null : () => _nextBatch(sourceId),
            child: Text(
              '${MetadataScraper.instance.providerOf(sourceId)?.displayName ?? sourceId}'
              ' · ${l10n.nextBatch}',
              style: TextStyle(fontSize: 12, color: textColor),
            ),
          ),
      ],
    );
  }

  Widget _diffSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final candidate = _selected!;
    final values = mergeScrapedTags(
      song: song,
      candidate: candidate,
      mode: _mode,
    );

    String? diff(String current, String next) {
      if (next.trim().isEmpty || next == current) {
        return null;
      }
      return '$current -> $next';
    }

    final rows = <Widget>[];
    void add(String label, String? text) {
      if (text != null) {
        rows.add(
          appleFormRow(
            label,
            Text(
              text,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: colorManager.getSpecificTextColor(),
              ),
            ),
          ),
        );
      }
    }

    add(l10n.title, diff(song.title ?? '', values.title));
    add(l10n.artist, diff(song.artist ?? '', values.artist));
    add(l10n.album, diff(song.album ?? '', values.album));
    add(l10n.albumArtist, diff(song.albumArtist ?? '', values.albumArtist));
    if (values.year != song.year) {
      add(l10n.year, '${song.year ?? ''} -> ${values.year ?? ''}');
    }
    if (values.track != song.track) {
      add(l10n.track, '${song.track ?? ''} -> ${values.track ?? ''}');
    }

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }
    return AppleFormSection(title: l10n.changes, children: rows);
  }
}
