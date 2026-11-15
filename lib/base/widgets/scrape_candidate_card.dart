import 'dart:async';
import 'dart:typed_data';

import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/metadata_scraper.dart';
import 'package:lain/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// One scrape result, drawn the same way in the single-song deck and in the
/// swipe stack.
///
/// The cover is fetched from the candidate and a spinner is shown until it
/// arrives; only a source without artwork (or a failed fetch) falls back to the
/// album placeholder. The whole card uses the app's theme colours.
class ScrapeCandidateCard extends StatefulWidget {
  final ScrapedCandidate candidate;
  final String sourceName;

  /// Shown before the source name, so a card in a mixed deck still says which
  /// song it belongs to.
  final String? songLabel;

  final Future<Uint8List?> Function(ScrapedCandidate candidate) coverLoader;
  final bool selected;

  const ScrapeCandidateCard({
    super.key,
    required this.candidate,
    required this.sourceName,
    required this.coverLoader,
    this.songLabel,
    this.selected = false,
  });

  @override
  State<ScrapeCandidateCard> createState() => _ScrapeCandidateCardState();
}

class _ScrapeCandidateCardState extends State<ScrapeCandidateCard> {
  Uint8List? _cover;
  bool _loading = false;
  String? _loadedFor;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCover());
  }

  @override
  void didUpdateWidget(covariant ScrapeCandidateCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candidate.key != widget.candidate.key) {
      setState(() {
        _cover = null;
        _loading = false;
        _loadedFor = null;
      });
      unawaited(_loadCover());
    }
  }

  Future<void> _loadCover() async {
    if (_loading || _loadedFor == widget.candidate.key) {
      return;
    }
    _loading = true;
    Uint8List? bytes;
    try {
      bytes = await widget.coverLoader(widget.candidate);
    } catch (_) {
      bytes = null;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _cover = bytes;
      _loading = false;
      _loadedFor = widget.candidate.key;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();
    final candidate = widget.candidate;
    final source = widget.songLabel == null
        ? widget.sourceName
        : '${widget.songLabel} · ${widget.sourceName}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: textColor.withAlpha(widget.selected ? 38 : 20),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  source,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withAlpha(170),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${l10n.matchScore} ${candidate.score.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  color: textColor.withAlpha(150),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: _coverWidget(textColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidate.title ?? '',
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
                        candidate.artist ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor.withAlpha(180),
                        ),
                      ),
                      Text(
                        candidate.album ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: textColor.withAlpha(150),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        [
                          if (candidate.track != null)
                            '${l10n.track} ${candidate.track}',
                          if (candidate.year != null) '${candidate.year}',
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor.withAlpha(130),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverWidget(Color textColor) {
    Widget placeholder() => Icon(
      Icons.album_rounded,
      size: 48,
      color: textColor.withAlpha(120),
    );
    Widget loading() => const Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );

    if (_loading) {
      return loading();
    }
    final cover = _cover;
    if (cover != null && cover.isNotEmpty) {
      return Image.memory(
        cover,
        fit: BoxFit.cover,
        cacheWidth: 192,
        gaplessPlayback: true,
        errorBuilder: (context, error, stack) => placeholder(),
      );
    }
    final url = widget.candidate.coverUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Referer': widget.candidate.source == 'netease'
              ? 'https://music.163.com/'
              : 'https://y.qq.com/',
        },
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : loading(),
        errorBuilder: (context, error, stack) => placeholder(),
      );
    }
    return placeholder();
  }
}
