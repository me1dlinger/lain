import 'package:material_ui/material_ui.dart';
import 'package:lain/base/data/comment_server.dart';
import 'package:lain/base/data/comment_setting.dart';
import 'package:lain/base/data/offline_setting.dart';
import 'package:lain/base/data/song_comment.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/comment_client.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/base/widgets/settings_page_route.dart';
import 'package:lain/l10n/generated/app_localizations.dart';
import 'package:lain/layer/layers_manager.dart';

/// How many comments one page holds. Paging is local: the whole answer is
/// fetched once and sliced, so turning a page is instant and costs nothing.
const _commentPageSize = 15;

/// A page size big enough to be "everything the server has": the server sends
/// the full list in one answer and never sees a page size, so this only
/// disables the client-side slicing for the single fetch.
const _fetchEverythingSize = 1 << 30;

/// The comments of one song, and the server that answers them.
///
/// The page opens on the current song for a pushed route, or on any song when
/// it is used as a widget. One page is [_commentPageSize] comments, sorted by
/// likes, because the reference server answers everything in one go and has no
/// paging of its own.
class CommentPageView extends StatefulWidget {
  /// The song whose comments are shown.
  final MyAudioMetadata currentSong;

  const CommentPageView({super.key, required this.currentSong});

  /// A route for the page: the settings drawer's slide-in, so it feels like the
  /// other pushed pages of the app.
  static Route<void> route(MyAudioMetadata song) {
    return settingsPageRoute<void>(() => CommentPageView(currentSong: song));
  }

  @override
  State<CommentPageView> createState() => _CommentPageViewState();
}

class _CommentPageViewState extends State<CommentPageView>
    with SingleTickerProviderStateMixin {
  /// The server this page asks, fixed when it opens: a long list is being read,
  /// so switching server underneath it would be a different song's answers.
  late final CommentServer? _server = activeCommentServer;

  late final AnimationController _fadeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  /// Every comment of the song, fetched once and sorted by likes; pages are
  /// slices of this list, so paging never touches the network.
  List<SongComment>? _all;

  int _page = 0;
  bool _loading = false;

  /// Why the page failed, for the error state; null when nothing failed.
  String? _errorReason;

  @override
  void initState() {
    super.initState();
    // The list only fades in once its first page is in, so the transition does
    // not show an empty page.
    Future.microtask(() => _load(0));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  CommentQuery get _query => CommentQuery(
    songName: getTitle(widget.currentSong),
    artistName: getArtist(widget.currentSong),
    songId: widget.currentSong.id.isEmpty ? null : widget.currentSong.id,
    pageSize: _fetchEverythingSize,
  );

  /// The comments of the current page: a local slice of the one full answer.
  List<SongComment> get _pageItems {
    final all = _all;
    if (all == null) {
      return const [];
    }
    final start = _page * _commentPageSize;
    if (start >= all.length) {
      return const [];
    }
    final end = start + _commentPageSize;
    return all.sublist(start, end > all.length ? all.length : end);
  }

  /// Whether a previous page exists. Every page is in memory, so this is
  /// simply "not the first page".
  bool get _hasPrevious => _page > 0;

  /// Whether a next page exists, counting the pages the one full answer can
  /// fill after the current one.
  bool get _hasNext => (_page + 1) * _commentPageSize < (_all?.length ?? 0);

  Future<void> _load(int page, {bool force = false}) async {
    final server = _server;
    if (server == null || page < 0) {
      return;
    }
    // The answer is already in memory; only a retry goes back to the server.
    if (!force && _all != null) {
      setState(() {
        _page = page;
        _errorReason = null;
      });
      _fadeController.forward(from: 0);
      return;
    }
    setState(() {
      _page = page;
      _loading = true;
      _errorReason = null;
    });

    try {
      final result = await CommentClient(server).fetch(_query);
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        // Sorted once over the whole answer, so the hottest comments are
        // always on the earliest pages no matter where the server put them.
        _all = _sorted(result.page.comments);
      });
      _fadeController.forward(from: 0);
    } on CommentFetchException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorReason = error.reason;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorReason = 'badResponse';
      });
    }
  }

  void _goTo(int page) {
    if (page < 0 || _loading) {
      return;
    }
    _load(page);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();

    return ListenableBuilder(
      listenable: Listenable.merge([
        layersManager.backgroundChangeNotifier,
        panelColor.valueNotifier,
        pageBackgroundColor.valueNotifier,
        offlineModeNotifier,
      ]),
      builder: (context, child) {
        return Scaffold(
          backgroundColor: colorManager.getSpecificOpaqueBgColor(),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: textColor,
                        ),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      Expanded(
                        child: Text(
                          l10n.comments,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                      // Keeps the title centred against the back arrow.
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _songHeader(l10n, textColor),
                      ),
                      const SizedBox(height: 12),
                      ..._body(l10n, textColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The song the comments belong to: its cover, title and artist.
  Widget _songHeader(AppLocalizations l10n, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: textColor.withAlpha(20),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CoverArtWidget(
            size: 64,
            borderRadius: 8,
            picture: widget.currentSong.picture,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  getTitle(widget.currentSong),
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
                  getArtist(widget.currentSong),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor.withAlpha(160),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _body(AppLocalizations l10n, Color textColor) {
    if (_server == null) {
      return [
        _message(
          l10n.commentNoServer,
          detail: l10n.commentNoServerHint,
          textColor: textColor,
        ),
      ];
    }
    if (offlineModeNotifier.value) {
      return [
        _message(
          l10n.offlineModeBlocked,
          textColor: textColor,
          actionLabel: l10n.commentRetry,
          onAction: () => _load(_page, force: true),
        ),
      ];
    }
    if (_errorReason != null) {
      return [
        _message(
          l10n.commentLoadFailed,
          detail: _errorDetail(l10n, _errorReason!),
          textColor: textColor,
          actionLabel: l10n.commentRetry,
          onAction: () => _load(_page, force: true),
        ),
      ];
    }
    // Nothing has loaded yet and nothing failed: this is the first request.
    if (_loading && _all == null) {
      return [_loadingState(textColor)];
    }

    final items = _pageItems;
    if (items.isEmpty) {
      return [_message(l10n.commentEmpty, textColor: textColor)];
    }

    return [
      // Already sorted over the whole answer when it arrived, so the comments
      // worth reading are always on the earliest pages.
      for (final comment in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _CommentTile(
            key: ValueKey('${_page}_${comment.commentId}'),
            comment: comment,
            fade: _fadeController,
            textColor: textColor,
          ),
        ),
      if (_hasPrevious || _hasNext) _pager(l10n, textColor),
      if (_loading) ...[
        const SizedBox(height: 8),
        LinearProgressIndicator(color: colorManager.getSpecificButtonColor()),
      ],
    ];
  }

  List<SongComment> _sorted(List<SongComment> comments) {
    final result = List<SongComment>.of(comments);
    result.sort((a, b) => b.praiseNum.compareTo(a.praiseNum));
    return result;
  }

  String _errorDetail(AppLocalizations l10n, String reason) {
    switch (reason) {
      case 'forbidden':
        return l10n.commentForbidden;
      case 'unreachable':
        return l10n.commentUnreachable;
      default:
        return l10n.commentServerError;
    }
  }

  Widget _message(
    String title, {
    String? detail,
    required Color textColor,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 8),
      child: Column(
        children: [
          Icon(
            Icons.forum_outlined,
            size: 40,
            color: textColor.withAlpha(90),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: textColor.withAlpha(200)),
          ),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: textColor.withAlpha(130),
              ),
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 14),
            _pagerButton(
              actionLabel,
              onAction,
      textColor: textColor,
              filled: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _loadingState(Color textColor) {
    // A skeleton of what the list will look like, so the page does not jump
    // when the comments arrive.
    return Column(
      children: [
        for (var i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: textColor.withAlpha(24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 10,
                        width: 90,
                        decoration: BoxDecoration(
                          color: textColor.withAlpha(24),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: textColor.withAlpha(18),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: textColor.withAlpha(120),
          ),
        ),
      ],
    );
  }

  /// Previous / page caption / next, as rounded pills in the app's button
  /// colour.
  Widget _pager(AppLocalizations l10n, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _pagerButton(l10n.commentPagePrevious, _hasPrevious ? () => _goTo(_page - 1) : null, textColor: textColor),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: textColor.withAlpha(22),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              l10n.commentPageIndicator(_page + 1),
              style: TextStyle(fontSize: 12, color: textColor.withAlpha(190)),
            ),
          ),
          _pagerButton(l10n.commentPageNext, _hasNext ? () => _goTo(_page + 1) : null, textColor: textColor),
        ],
      ),
    );
  }

  Widget _pagerButton(
    String label,
    VoidCallback? onPressed, {
    required Color textColor,
    bool filled = false,
  }) {
    final disabled = onPressed == null;
    final background = filled
        ? colorManager.getSpecificButtonColor().withAlpha(disabled ? 60 : 255)
        : textColor.withAlpha(disabled ? 14 : 22);
    final foreground = filled
        ? (disabled ? textColor.withAlpha(120) : textColor)
        : textColor.withAlpha(disabled ? 90 : 200);

    return Material(
      color: background,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: foreground),
          ),
        ),
      ),
    );
  }
}

/// One top-level comment, with its replies collapsed under it.
class _CommentTile extends StatefulWidget {
  final SongComment comment;
  final Animation<double> fade;
  final Color textColor;

  const _CommentTile({
    super.key,
    required this.comment,
    required this.fade,
    required this.textColor,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final comment = widget.comment;
    final textColor = widget.textColor;

    return FadeTransition(
      opacity: widget.fade,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: textColor.withAlpha(14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(
                  url: comment.avatarUrl,
                  size: 36,
                  textColor: textColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.nick.isEmpty
                            ? l10n.unknown
                            : comment.nick,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: textColor.withAlpha(220),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        comment.content,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: textColor.withAlpha(200),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const SizedBox(width: 46),
                if (comment.createTime > 0)
                  Text(
                    _formatDate(comment.createTime),
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withAlpha(120),
                    ),
                  ),
                if (comment.createTime > 0 && comment.praiseNum > 0)
                  const SizedBox(width: 12),
                if (comment.praiseNum > 0) ...[
                  Icon(
                    Icons.thumb_up_alt_outlined,
                    size: 12,
                    color: textColor.withAlpha(120),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${comment.praiseNum}',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withAlpha(120),
                    ),
                  ),
                ],
                const Spacer(),
                if (comment.replyCount > 0)
                  GestureDetector(
                    onTap: () => setState(() => expanded = !expanded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        expanded
                            ? l10n.commentHideReplies
                            : l10n.commentShowReplies(comment.replyCount),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorManager.getSpecificButtonColor(),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (expanded && comment.replyCount > 0) ...[
              const SizedBox(height: 6),
              for (final reply in comment.replies)
                Padding(
                  padding: const EdgeInsets.only(left: 46, top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Avatar(
                        url: reply.avatarUrl,
                        size: 28,
                        textColor: textColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reply.nick.isEmpty ? l10n.unknown : reply.nick,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: textColor.withAlpha(200),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              reply.content,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                color: textColor.withAlpha(170),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// `yyyy-MM-dd`, in local time: the server sends unix seconds.
  static String _formatDate(int seconds) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000,
    ).toLocal();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

/// A round avatar, falling back to a person icon when there is no image (or it
/// failed to load).
class _Avatar extends StatelessWidget {
  final String url;
  final double size;
  final Color textColor;

  const _Avatar({
    required this.url,
    required this.size,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url.trim().isEmpty
            ? _fallback()
            : Image.network(
                url.trim(),
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _fallback(),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) {
                    return child;
                  }
                  return _fallback();
                },
              ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: textColor.withAlpha(24),
      child: Icon(
        Icons.person_rounded,
        size: size * 0.6,
        color: textColor.withAlpha(140),
      ),
    );
  }
}
