import 'dart:async';
import 'dart:math';

import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/metadata_scraper.dart';
import 'package:lain/base/widgets/apple_form.dart';
import 'package:lain/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Lyrics lookup for the lyric editor: NetEase and QQ by title/artist/album,
/// a candidate list, and a preview of the selected candidate's lyrics.
///
/// The dialog only returns text. The editor keeps the original snapshot, and
/// saving still writes the embedded tag (an existing `.lrc` sidecar is updated,
/// a new one is never created).
class LyricSearchDialog extends StatefulWidget {
  final MyAudioMetadata song;

  const LyricSearchDialog({super.key, required this.song});

  @override
  State<LyricSearchDialog> createState() => _LyricSearchDialogState();
}

class _LyricSearchDialogState extends State<LyricSearchDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _artistController;
  late final TextEditingController _albumController;

  MetadataScrapeResult? _result;
  bool _searching = false;
  bool _loadingLyrics = false;
  ScrapedCandidate? _selected;
  String? _lyrics;
  String? _error;

  @override
  void initState() {
    super.initState();
    final query = buildMetadataQuery(widget.song);
    _titleController = TextEditingController(text: query.title ?? '');
    _artistController = TextEditingController(text: query.artist ?? '');
    _albumController = TextEditingController(text: query.album ?? '');
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
    super.dispose();
  }

  MetadataQuery get _query => buildMetadataQuery(
    widget.song,
    title: _titleController.text,
    artist: _artistController.text,
    album: _albumController.text,
  );

  Future<void> _search() async {
    if (_searching) {
      return;
    }
    setState(() {
      _searching = true;
      _selected = null;
      _lyrics = null;
      _error = null;
    });
    try {
      final result = await MetadataScraper.instance.search(
        _query,
        allSources: true,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _searching = false;
        _error = '$e';
      });
    }
  }

  List<ScrapedCandidate> get _candidates {
    final result = _result;
    if (result == null) {
      return const [];
    }
    return [
      for (final group in result.groups.values) ...group,
    ];
  }

  Future<void> _select(ScrapedCandidate candidate) async {
    setState(() {
      _selected = candidate;
      _lyrics = null;
      _loadingLyrics = true;
      _error = null;
    });
    final provider = MetadataScraper.instance.providerOf(candidate.source);
    String? text;
    try {
      text = await provider?.fetchLyrics(candidate);
    } catch (e) {
      text = null;
    }
    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loadingLyrics = false;
      if (text == null || text.trim().isEmpty) {
        _lyrics = null;
        _error = l10n.noLyrics;
      } else {
        _lyrics = text;
      }
    });
  }

  void _apply() {
    final lyrics = _lyrics;
    if (lyrics == null || lyrics.trim().isEmpty) {
      return;
    }
    Navigator.of(context).pop(lyrics);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = max(320.0, min(560.0, size.width - 24));
    final height = size.height < 520 ? size.height - 40 : size.height * 0.8;
    return SizedBox(
      width: width,
      height: max(360, height),
      child: _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();
    final candidates = _candidates;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
      child: Column(
        children: [
          Text(
            l10n.searchLyrics,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
          Expanded(
            flex: _selected == null ? 1 : 3,
            child: _searching
                ? const Center(child: CircularProgressIndicator())
                : candidates.isEmpty
                ? _empty(context)
                : ListView.builder(
                    itemCount: candidates.length,
                    itemBuilder: (context, index) =>
                        _candidateRow(context, candidates[index]),
                  ),
          ),
          if (_selected != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  Text(
                    l10n.lyricsPreview,
                    style: TextStyle(
                      fontSize: 13,
                      color: textColor.withAlpha(170),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: textColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _loadingLyrics
                    ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _lyrics == null
                    ? Center(
                        child: Text(
                          _error ?? l10n.noLyrics,
                          style: TextStyle(
                            fontSize: 13,
                            color: textColor.withAlpha(150),
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        child: SelectableText(
                          _lyrics!,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: textColor.withAlpha(200),
                          ),
                        ),
                      ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: appleFilledButton(
              l10n.apply,
              _lyrics == null || _loadingLyrics ? null : _apply,
            ),
          ),
          appleTextButton(l10n.cancel, () => Navigator.of(context).pop()),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();
    final errors = _result?.errors ?? const {};
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
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

  Widget _candidateRow(BuildContext context, ScrapedCandidate candidate) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();
    final selected = _selected?.key == candidate.key;
    final source =
        MetadataScraper.instance.providerOf(candidate.source)?.displayName ??
        candidate.source;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _select(candidate),
      child: Container(
        color: selected ? textColor.withAlpha(38) : Colors.transparent,
        padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidate.title ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, color: textColor),
                  ),
                  Text(
                    '${candidate.artist ?? ''} - ${candidate.album ?? ''}',
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
            const SizedBox(width: 8),
            Text(
              source,
              style: TextStyle(fontSize: 11, color: textColor.withAlpha(130)),
            ),
            const SizedBox(width: 10),
            Text(
              '${l10n.matchScore} ${candidate.score.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 11, color: textColor.withAlpha(130)),
            ),
          ],
        ),
      ),
    );
  }
}
