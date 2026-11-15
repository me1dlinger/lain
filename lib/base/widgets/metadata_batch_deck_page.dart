import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:lain/base/app.dart';
import 'package:lain/base/data/loader.dart';
import 'package:lain/base/data/scrape_selection.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/services/metadata_scraper.dart';
import 'package:lain/base/services/metadata_write.dart';
import 'package:lain/base/widgets/apple_form.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/base/widgets/local_music_page.dart';
import 'package:lain/base/widgets/scrape_candidate_deck.dart';
import 'package:lain/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// Batch scraping straight into the rotating deck.
///
/// Every selected song is searched as soon as the page opens; the deck then
/// shows one song at a time, its candidates as turnable cards. A tap selects a
/// card, a long press applies it, the button below applies the visible one, and
/// the app bar applies the best candidate of every song. The arrows and the song
/// picker move between songs that have results; there is no intermediate list
/// to step through.
class MetadataBatchDeckPage extends StatefulWidget {
  final List<MyAudioMetadata> songs;

  const MetadataBatchDeckPage({super.key, required this.songs});

  @override
  State<MetadataBatchDeckPage> createState() => _MetadataBatchDeckPageState();
}

class _SongResults {
  final MyAudioMetadata song;
  List<ScrapedCandidate> candidates = const [];
  String? error;
  int selected = 0;

  _SongResults(this.song);

  bool get hasResults => candidates.isNotEmpty;

  ScrapedCandidate? get current {
    if (candidates.isEmpty) {
      return null;
    }
    return candidates[selected.clamp(0, candidates.length - 1)];
  }
}

class _MetadataBatchDeckPageState extends State<MetadataBatchDeckPage> {
  late final List<_SongResults> _items = [
    for (final song in widget.songs) _SongResults(song),
  ];

  ScrapeWriteMode _writeMode = ScrapeWriteMode.fillEmpty;
  final ValueNotifier<bool> _writeCover = ValueNotifier(true);
  final ValueNotifier<bool> _writeLyrics = ValueNotifier(false);

  bool _searching = true;
  bool _stopRequested = false;
  (int, int) _progress = (0, 0);
  int _current = 0;

  bool _applying = false;
  bool _applied = false;
  bool _undoing = false;
  int _appliedCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startSearch();
      }
    });
  }

  @override
  void dispose() {
    _writeCover.dispose();
    _writeLyrics.dispose();
    super.dispose();
  }

  Future<void> _startSearch() async {
    if (_items.isEmpty) {
      setState(() => _searching = false);
      return;
    }
    setState(() => _progress = (0, _items.length));
    for (var i = 0; i < _items.length; i++) {
      if (_stopRequested) {
        break;
      }
      final item = _items[i];
      try {
        final result = await MetadataScraper.instance.search(
          buildMetadataQuery(item.song),
        );
        final candidates = result.all.toList()
          ..sort((a, b) => b.score.compareTo(a.score));
        item.candidates = candidates;
        item.selected = bestCandidateIndex(
          candidates.map((candidate) => candidate.score),
        );
        if (item.selected < 0) {
          item.selected = 0;
        }
        if (candidates.isEmpty && result.errors.isNotEmpty) {
          item.error = result.errors.values.first;
        }
      } catch (e) {
        item.error = '$e';
      }
      if (mounted) {
        setState(() => _progress = (i + 1, _items.length));
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _searching = false;
      _current = _firstWithResults();
    });
  }

  int _firstWithResults() {
    final index = _items.indexWhere((item) => item.hasResults);
    return index < 0 ? 0 : index;
  }

  void _moveSong(int delta) {
    final hasResults = [for (final item in _items) item.hasResults];
    final next = nextIndexWithValue(hasResults, _current, delta);
    if (next < 0 || next == _current) {
      return;
    }
    setState(() => _current = next);
  }

  Future<void> _showSongPicker() async {
    if (_items.isEmpty) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final height = min(520.0, MediaQuery.sizeOf(context).height * 0.7);
    final picked = await showAnimationDialog<int>(
      context: context,
      child: SizedBox(
        width: max(300.0, min(520.0, MediaQuery.sizeOf(context).width - 24)),
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
          child: Column(
            children: [
              Text(
                l10n.jumpToSong,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorManager.getSpecificTextColor(),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return ListTile(
                      selected: index == _current,
                      leading: CoverArtWidget(
                        picture: item.song.picture,
                        size: 40,
                        borderRadius: 6,
                      ),
                      title: Text(
                        item.song.title ??
                            p.basenameWithoutExtension(item.song.path ?? ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        item.hasResults
                            ? l10n.resultsCount(item.candidates.length)
                            : l10n.noSearchResults,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onTap: () => Navigator.of(context).pop(index),
                    );
                  },
                ),
              ),
              appleTextButton(l10n.cancel, () => Navigator.of(context).pop()),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _current = picked);
    }
  }

  Future<void> _applyCurrent() async {
    final item = _items[_current];
    final candidate = item.current;
    if (candidate == null) {
      return;
    }
    await _applyPairs([(item.song, candidate)]);
  }

  Future<void> _applyCard(ScrapedCandidate candidate) async {
    final item = _items[_current];
    await _applyPairs([(item.song, candidate)]);
  }

  Future<void> _applyAllBest() async {
    final pairs = <(MyAudioMetadata, ScrapedCandidate)>[];
    for (final item in _items) {
      // The candidates are sorted by score, so the first one is the best even
      // when the user has turned the deck to another card.
      final candidate = item.candidates.isEmpty ? null : item.candidates.first;
      if (candidate != null) {
        pairs.add((item.song, candidate));
      }
    }
    await _applyPairs(pairs);
  }

  Future<void> _applyPairs(
    List<(MyAudioMetadata, ScrapedCandidate)> pairs,
  ) async {
    if (_applying || pairs.isEmpty) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    if (Loader.busy) {
      showCenterMessage(l10n.syncingWait);
      return;
    }
    setState(() => _applying = true);
    final snapshots = <(MyAudioMetadata, SongMetadataSnapshot)>[];
    for (final (song, candidate) in pairs) {
      final snapshot = await captureSongMetadata(song);
      final values = mergeScrapedTags(
        song: song,
        candidate: candidate,
        mode: _writeMode,
      );

      Uint8List? coverBytes;
      if (_writeCover.value && candidate.coverUrl != null) {
        final provider = MetadataScraper.instance.providerOf(candidate.source);
        final bytes = await provider?.fetchCoverBytes(candidate);
        if (bytes != null && isValidCoverBytes(bytes)) {
          coverBytes = bytes;
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
      if (ok) {
        snapshots.add((song, snapshot));
      }
    }
    if (!mounted) {
      return;
    }
    if (snapshots.isNotEmpty) {
      // Applying all best results is one step of undo.
      scrapeUndo.record(snapshots);
    }
    setState(() {
      _applying = false;
      _applied = snapshots.isNotEmpty;
      _appliedCount = snapshots.length;
    });
    showCenterMessage(
      snapshots.isEmpty
          ? l10n.updateFailed
          : l10n.batchApplied(snapshots.length),
    );
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
        _appliedCount = 0;
      }
    });
    showCenterMessage(ok ? l10n.undoSuccessfully : l10n.undoFailed);
  }

  @override
  Widget build(BuildContext context) {
    assert(isLocalLibrary);
    final l10n = AppLocalizations.of(context);
    final hasAnyResults = _items.any((item) => item.hasResults);

    return opaqueSettingsPage(
      context: context,
      title: l10n.batchSearchTags,
      actions: [
        if (_searching)
          TextButton(
            onPressed: () => setState(() => _stopRequested = true),
            child: Text(l10n.stop),
          )
        else if (hasAnyResults)
          TextButton(
            onPressed: _applying ? null : _applyAllBest,
            child: Text(l10n.applyAllBest),
          ),
      ],
      body: _searching
          ? _searchingBody(context, l10n)
          : _resultsBody(context, l10n),
    );
  }

  Widget _searchingBody(BuildContext context, AppLocalizations l10n) {
    final textColor = colorManager.getSpecificTextColor();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(
            l10n.batchSearching(_progress.$1, _progress.$2),
            style: TextStyle(fontSize: 13, color: textColor.withAlpha(170)),
          ),
        ],
      ),
    );
  }

  Widget _resultsBody(BuildContext context, AppLocalizations l10n) {
    if (_items.isEmpty) {
      return Center(
        child: Text(
          l10n.noData,
          style: TextStyle(
            fontSize: 14,
            color: colorManager.getSpecificTextColor().withAlpha(150),
          ),
        ),
      );
    }
    final item = _items[_current.clamp(0, _items.length - 1)];
    return Column(
      children: [
        _songHeader(context, l10n),
        AppleFormSection(
          divided: false,
          children: [
            appleSegmented<ScrapeWriteMode>(
              ScrapeWriteMode.values,
              (value) => value == ScrapeWriteMode.fillEmpty
                  ? l10n.scrapeFillEmpty
                  : l10n.overwriteTags,
              _writeMode,
              (value) => setState(() => _writeMode = value),
            ),
            appleSwitchRow(l10n.writeCoverToo, _writeCover),
            appleSwitchRow(l10n.writeLyricsToo, _writeLyrics),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(child: _currentSong(context, l10n, item)),
        if (_applied) _appliedRow(context, l10n),
      ],
    );
  }

  Widget _songHeader(BuildContext context, AppLocalizations l10n) {
    final textColor = colorManager.getSpecificTextColor();
    final index = _items.isEmpty ? 0 : _current + 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 20, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _moveSong(-1),
            icon: Icon(
              Icons.skip_previous_rounded,
              color: textColor.withAlpha(200),
            ),
            tooltip: l10n.previousSong,
          ),
          Expanded(
            child: GestureDetector(
              onTap: _showSongPicker,
              behavior: HitTestBehavior.opaque,
              child: Text(
                l10n.songPosition(index, _items.length),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: textColor.withAlpha(170)),
              ),
            ),
          ),
          IconButton(
            onPressed: () => _moveSong(1),
            icon: Icon(
              Icons.skip_next_rounded,
              color: textColor.withAlpha(200),
            ),
            tooltip: l10n.nextSong,
          ),
          IconButton(
            onPressed: _showSongPicker,
            icon: Icon(Icons.list_rounded, color: textColor.withAlpha(200)),
            tooltip: l10n.jumpToSong,
          ),
        ],
      ),
    );
  }

  Widget _currentSong(
    BuildContext context,
    AppLocalizations l10n,
    _SongResults item,
  ) {
    final textColor = colorManager.getSpecificTextColor();
    final title = item.song.title == null || item.song.title!.trim().isEmpty
        ? p.basenameWithoutExtension(item.song.path ?? '')
        : item.song.title!;

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
          child: Row(
            children: [
              CoverArtWidget(
                picture: item.song.picture,
                size: 56,
                borderRadius: 8,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, color: textColor),
                    ),
                    Text(
                      '${item.song.artist ?? ''} · ${item.song.album ?? ''}',
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
        ),
        if (!item.hasResults)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Text(
              item.error ?? l10n.noSearchResults,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: textColor.withAlpha(150)),
            ),
          )
        else ...[
          ScrapeCandidateDeck(
            deckKey: 'batch-${item.song.id}',
            cards: item.candidates,
            selectedIndex: item.selected,
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
            onSelected: (index) => setState(() => item.selected = index),
            onLongPress: (candidate) => _applyCard(candidate),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: appleFilledButton(
              l10n.applyCurrent,
              _applying || item.current == null ? null : _applyCurrent,
              busy: _applying,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              l10n.scrapeLongPressHint,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: textColor.withAlpha(120)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _appliedRow(BuildContext context, AppLocalizations l10n) {
    final textColor = colorManager.getSpecificTextColor();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 16, 10),
      child: Row(
        children: [
          Text(
            l10n.batchApplied(_appliedCount),
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
}
