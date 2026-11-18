import 'dart:math';

import 'package:lain/base/app.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/services/metadata_scraper.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:lain/base/services/metadata_write.dart';
import 'package:lain/base/widgets/apple_form.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/base/widgets/local_music_page.dart';
import 'package:lain/base/widgets/metadata_scrape_dialog.dart';
import 'package:lain/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

bool songHasMissingTags(MyAudioMetadata song) {
  bool empty(String? value) => value == null || value.trim().isEmpty;
  return empty(song.title) || empty(song.artist) || empty(song.album);
}

bool songHasMissingCover(MyAudioMetadata song) => !song.picture.isExist;

bool songHasMissingLyrics(MyAudioMetadata song) =>
    song.lyrics == null || song.lyrics!.trim().isEmpty;

int countSongsMissingTags(Iterable<MyAudioMetadata> songs) {
  var count = 0;
  for (final song in songs) {
    if (song.path != null && songHasMissingTags(song)) {
      count++;
    }
  }
  return count;
}

/// The local songs whose tags are incomplete, with a per-song search and a
/// batch path that reviews every best match before writing anything.
class MetadataCompletionPage extends StatefulWidget {
  /// Restricts the page to these songs (the selection page's "batch search");
  /// null means the whole local library.
  final List<MyAudioMetadata>? songs;

  const MetadataCompletionPage({super.key, this.songs});

  @override
  State<MetadataCompletionPage> createState() => _MetadataCompletionPageState();
}

class _MetadataCompletionPageState extends State<MetadataCompletionPage> {
  final Set<String> _selected = {};
  final _searchController = TextEditingController();
  bool _showAll = false;
  bool _batchRunning = false;
  bool _batchStop = false;
  (int, int) _batchProgress = (0, 0);

  /// Every local song that has a file to write to. Songs that already carry
  /// tags are listed as well: the fill-empty / overwrite choice on the page is
  /// what decides whether they are updated, not a filter here.
  List<MyAudioMetadata> get _allSongs {
    final source = widget.songs ?? library.songList;
    return [
      for (final song in source)
        if (song.path != null) song,
    ];
  }

  List<MyAudioMetadata> get _missingSongs {
    return [
      for (final song in _allSongs)
        if (songHasMissingTags(song)) song,
    ];
  }

  List<MyAudioMetadata> get _visibleSongs {
    final base = _showAll ? _allSongs : _missingSongs;
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return base;
    }
    return [
      for (final song in base)
        if (getTitle(song).toLowerCase().contains(query) ||
            getArtist(song).toLowerCase().contains(query) ||
            getAlbum(song).toLowerCase().contains(query))
          song,
    ];
  }

  List<MyAudioMetadata> get _selectedSongs {
    final songs = <MyAudioMetadata>[];
    for (final song in _allSongs) {
      if (_selected.contains(song.id)) {
        songs.add(song);
      }
    }
    return songs;
  }

  Future<void> _searchOne(MyAudioMetadata song) async {
    final applied = await showAnimationDialog<bool>(
      context: context,
      child: MetadataScrapeDialog(song: song),
    );
    if (applied == true && mounted) {
      setState(() => _selected.remove(song.id));
    }
  }

  Future<void> _batchSearch() async {
    final songs = _selectedSongs;
    if (songs.isEmpty || _batchRunning) {
      return;
    }
    setState(() {
      _batchRunning = true;
      _batchStop = false;
      _batchProgress = (0, songs.length);
    });
    final items = <_BatchItem>[];
    for (var i = 0; i < songs.length; i++) {
      if (_batchStop) {
        break;
      }
      final song = songs[i];
      try {
        final result = await MetadataScraper.instance.search(
          buildMetadataQuery(song),
        );
        final candidates = result.all.toList()
          ..sort((a, b) => b.score.compareTo(a.score));
        items.add(_BatchItem(song: song, candidates: candidates));
      } catch (e) {
        items.add(_BatchItem(song: song, candidates: const [], error: '$e'));
      }
      if (mounted) {
        setState(() => _batchProgress = (i + 1, songs.length));
      }
    }
    if (!mounted) {
      return;
    }
    setState(() => _batchRunning = false);
    if (items.isEmpty) {
      return;
    }
    final applied = await showAnimationDialog<int>(
      context: context,
      child: _BatchReviewDialog(items: items),
    );
    if (applied != null && applied > 0 && mounted) {
      showCenterMessage(
        AppLocalizations.of(context).batchApplied(applied),
      );
      setState(() {
        for (final item in items) {
          if (item.applied) {
            _selected.remove(item.song.id);
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(isLocalLibrary);
    final l10n = AppLocalizations.of(context);
    final candidates = _visibleSongs;

    return opaqueSettingsPage(
      context: context,
      title: l10n.metadataCompletion,
      actions: [
        if (_batchRunning)
          TextButton(
            onPressed: () => setState(() => _batchStop = true),
            child: Text(l10n.stop),
          )
        else if (_selectedSongs.isNotEmpty)
          TextButton(
            onPressed: _batchSearch,
            child: Text(l10n.batchSearchSelected),
          ),
      ],
      body: Padding(
        padding: const EdgeInsets.only(bottom: 106),
        child: Column(
        children: [
          _searchField(context, l10n),
          if (_batchRunning)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.batchSearching(
                        _batchProgress.$1,
                        _batchProgress.$2,
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: colorManager
                            .getSpecificTextColor()
                            .withAlpha(150),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ),
            ),
          if (candidates.isNotEmpty) _selectAllBar(context, l10n, candidates),
          Expanded(
            child: candidates.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _searchController.text.trim().isNotEmpty
                            ? l10n.noSearchResults
                            : _missingSongs.isEmpty && !_showAll
                            ? l10n.allMetadataComplete
                            : l10n.noResults,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: colorManager
                              .getSpecificTextColor()
                              .withAlpha(150),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: candidates.length,
                    itemBuilder: (context, index) =>
                        _row(context, candidates[index]),
                  ),
          ),
          _allSongsButton(context, l10n),
        ],
        ),
      ),
    );
  }

  Widget _searchField(BuildContext context, AppLocalizations l10n) {
    final textColor = colorManager.getSpecificTextColor();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: textColor.withAlpha(14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(Icons.search_rounded, size: 18, color: textColor.withAlpha(150)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: TextStyle(fontSize: 14, color: textColor),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: l10n.searchSongs,
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: textColor.withAlpha(120),
                  ),
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: textColor.withAlpha(150),
                ),
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _allSongsButton(BuildContext context, AppLocalizations l10n) {
    final textColor = colorManager.getSpecificTextColor();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: TextButton(
        onPressed: () => setState(() => _showAll = !_showAll),
        child: Text(
          _showAll ? l10n.showMissingOnly : l10n.showAllSongs,
          style: TextStyle(fontSize: 13, color: textColor.withAlpha(170)),
        ),
      ),
    );
  }

  Widget _selectAllBar(
    BuildContext context,
    AppLocalizations l10n,
    List<MyAudioMetadata> candidates,
  ) {
    final allSelected =
        candidates.isNotEmpty &&
        candidates.every((song) => _selected.contains(song.id));
    final textColor = colorManager.getSpecificTextColor();
    return Row(
      children: [
        Checkbox(
          value: allSelected,
          activeColor: iconColor.value,
          shape: const CircleBorder(),
          side: BorderSide(color: iconColor.value.withAlpha(128)),
          onChanged: (value) {
            setState(() {
              if (value == true) {
                _selected.addAll(candidates.map((song) => song.id));
              } else {
                _selected.clear();
              }
            });
          },
        ),
        Text(l10n.selectAll, style: const TextStyle(fontSize: 15)),
        const Spacer(),
        Text(
          l10n.selectedCount(_selected.length),
          style: TextStyle(fontSize: 12, color: textColor.withAlpha(150)),
        ),
        const SizedBox(width: 20),
      ],
    );
  }

  Widget _row(BuildContext context, MyAudioMetadata song) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();
    final missing = <String>[
      if (song.title == null || song.title!.trim().isEmpty) l10n.missingTitle,
      if (song.artist == null || song.artist!.trim().isEmpty) l10n.missingArtist,
      if (song.album == null || song.album!.trim().isEmpty) l10n.missingAlbum,
      if (songHasMissingCover(song)) l10n.missingCover,
      if (songHasMissingLyrics(song)) l10n.missingLyrics,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          Checkbox(
            value: _selected.contains(song.id),
            activeColor: iconColor.value,
            shape: const CircleBorder(),
            side: BorderSide(color: iconColor.value.withAlpha(128)),
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selected.add(song.id);
                } else {
                  _selected.remove(song.id);
                }
              });
            },
          ),
          CoverArtWidget(size: 44, borderRadius: 6, picture: song.picture),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title == null || song.title!.isEmpty
                      ? p.basenameWithoutExtension(song.path ?? '')
                      : song.title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, color: textColor),
                ),
                Text(
                  '${song.artist ?? ''} - ${song.album ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withAlpha(150),
                  ),
                ),
                if (missing.isNotEmpty)
                  Text(
                    missing.take(3).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: textColor.withAlpha(120),
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _searchOne(song),
            child: Text(l10n.search),
          ),
        ],
      ),
    );
  }
}

class _BatchItem {
  final MyAudioMetadata song;
  final List<ScrapedCandidate> candidates;
  final String? error;
  int index = 0;
  bool selected;
  bool applied = false;

  _BatchItem({required this.song, required this.candidates, this.error})
    : selected =
          candidates.isNotEmpty && candidates.first.score >= 18;

  ScrapedCandidate? get candidate =>
      candidates.isEmpty ? null : candidates[index % candidates.length];
}

class _BatchReviewDialog extends StatefulWidget {
  final List<_BatchItem> items;

  const _BatchReviewDialog({required this.items});

  @override
  State<_BatchReviewDialog> createState() => _BatchReviewDialogState();
}

class _BatchReviewDialogState extends State<_BatchReviewDialog> {
  ScrapeWriteMode _mode = ScrapeWriteMode.fillEmpty;
  bool _applying = false;
  bool _applied = false;
  bool _undoing = false;
  int _appliedCount = 0;
  (int, int) _progress = (0, 0);

  Future<void> _apply() async {
    if (_applying) {
      return;
    }
    setState(() => _applying = true);
    final selected = [
      for (final item in widget.items)
        if (item.selected && item.candidate != null) item,
    ];
    var applied = 0;
    final snapshots = <(MyAudioMetadata, SongMetadataSnapshot)>[];
    for (var i = 0; i < selected.length; i++) {
      final item = selected[i];
      final values = mergeScrapedTags(
        song: item.song,
        candidate: item.candidate!,
        mode: _mode,
      );
      final snapshot = await captureSongMetadata(item.song);
      final ok = await writeSongTags(
        song: item.song,
        title: values.title,
        artist: values.artist,
        album: values.album,
        albumArtist: values.albumArtist,
        genre: values.genre,
        year: values.year,
        track: values.track,
        disc: values.disc,
      );
      item.applied = ok;
      if (ok) {
        applied++;
        snapshots.add((item.song, snapshot));
      }
      if (mounted) {
        setState(() => _progress = (i + 1, selected.length));
      }
    }
    if (!mounted) {
      return;
    }
    if (snapshots.isNotEmpty) {
      // The whole batch is one step of undo.
      scrapeUndo.record(snapshots);
    }
    setState(() {
      _applying = false;
      _applied = applied > 0;
      _appliedCount = applied;
    });
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
        for (final item in widget.items) {
          item.applied = false;
        }
        _applied = false;
        _appliedCount = 0;
      }
    });
    showCenterMessage(ok ? l10n.undoSuccessfully : l10n.undoFailed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();
    final reviewed = widget.items;
    return SizedBox(
      width: max(
        320,
        min(560, MediaQuery.sizeOf(context).width - 24),
      ),
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
        child: Column(
          children: [
            Text(
              l10n.batchReview,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
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
              ],
            ),
            if (_applying)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  '${_progress.$1} / ${_progress.$2}',
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withAlpha(150),
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: reviewed.length,
                itemBuilder: (context, index) =>
                    _row(context, l10n, reviewed[index]),
              ),
            ),
            if (_applied)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Row(
                  children: [
                    Text(
                      l10n.batchApplied(_appliedCount),
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor.withAlpha(150),
                      ),
                    ),
                    const Spacer(),
                    if (scrapeUndo.canUndo)
                      TextButton(
                        onPressed: _undoing ? null : _undo,
                        child: Text(l10n.undoApply),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _applied
                  ? appleFilledButton(
                      l10n.close,
                      () => Navigator.of(context).pop(_appliedCount),
                    )
                  : appleFilledButton(
                      l10n.applySelected,
                      _applying ? null : _apply,
                      busy: _applying,
                    ),
            ),
            appleTextButton(
              l10n.cancel,
              _applying
                  ? null
                  : () => Navigator.of(context).pop(_applied ? _appliedCount : 0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, AppLocalizations l10n, _BatchItem item) {
    final textColor = colorManager.getSpecificTextColor();
    final candidate = item.candidate;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: item.selected,
            activeColor: iconColor.value,
            shape: const CircleBorder(),
            side: BorderSide(color: iconColor.value.withAlpha(128)),
            onChanged: candidate == null
                ? null
                : (value) => setState(() => item.selected = value == true),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.song.title ??
                      p.basenameWithoutExtension(item.song.path ?? ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, color: textColor),
                ),
                if (candidate == null)
                  Text(
                    item.error ?? l10n.noSearchResults,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.withAlpha(200),
                    ),
                  )
                else ...[
                  Text(
                    '${candidate.title ?? ''} - ${candidate.artist ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withAlpha(180),
                    ),
                  ),
                  Text(
                    '${candidate.album ?? ''} · '
                    '${l10n.matchScore} ${candidate.score.toStringAsFixed(0)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: textColor.withAlpha(130),
                    ),
                  ),
                  if (item.candidates.length > 1)
                    TextButton(
                      onPressed: () => setState(() {
                        item.index = (item.index + 1) % item.candidates.length;
                      }),
                      child: Text(
                        l10n.nextCandidate,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
