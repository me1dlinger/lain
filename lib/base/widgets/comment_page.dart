import 'dart:async';

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

/// How many comments one page holds. The server pages on its side, so this is
/// one request's worth, not a slice of one big answer.
const _commentPageSize = 20;

/// How many floor replies come attached to each comment of a page; the rest
/// are fetched on demand through the replies endpoint.
const _replyLimit = 3;

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

  /// Pages already fetched for the current sort and song, by their 1-based
  /// index, so going back and forth never asks twice.
  final Map<int, CommentPageResult> _pages = {};

  /// How the list is ordered.
  CommentSort _sort = CommentSort.recommended;

  /// The current page, 1 based, as the server numbers them.
  int _page = 1;
  bool _loading = false;

  /// Why the page failed, for the error state; null when nothing failed.
  String? _errorReason;

  /// The song the comments are about: what the server matched the query to,
  /// or what the user picked by hand.
  CommentSong? _song;

  /// Whether the user chose [_song] themselves, in which case it is trusted
  /// even when its name differs from the local track.
  bool _pickedManually = false;

  @override
  void initState() {
    super.initState();
    // The list only fades in once its first page is in, so the transition does
    // not show an empty page.
    Future.microtask(() => _load(1));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  CommentQuery _queryFor(int page) => CommentQuery(
    songId: _song?.id,
    songName: getTitle(widget.currentSong),
    artistName: getArtist(widget.currentSong),
    albumName: getAlbum(widget.currentSong),
    sort: _sort,
    page: page,
    pageSize: _commentPageSize,
    replyLimit: _replyLimit,
  );

  /// The page the user is looking at.
  CommentPageResult? get _current => _pages[_page];

  bool get _hasPrevious => _page > 1;

  /// Whether a next page exists: the server says so, or it is already loaded.
  bool get _hasNext => _current?.page.hasMore == true || _pages.containsKey(_page + 1);

  /// Whether the song the server matched is clearly not this track. Comments
  /// of another song are worse than none, so they are held back and the user
  /// is asked to pick the right one instead.
  bool get _songMismatch {
    if (_pickedManually || _song == null) {
      return false;
    }
    return !_titlesMatch(getTitle(widget.currentSong), _song!.name);
  }

  /// Loose on purpose: punctuation, spacing and case differences between the
  /// local tags and the server's names must not count as a mismatch.
  static bool _titlesMatch(String a, String b) {
    String norm(String value) => value
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\p{P}\p{S}]+', unicode: true), '');
    final x = norm(a);
    final y = norm(b);
    if (x.isEmpty || y.isEmpty) {
      return true;
    }
    return x.contains(y) || y.contains(x);
  }

  Future<void> _load(int page, {bool force = false}) async {
    final server = _server;
    if (server == null || page < 1) {
      return;
    }
    // A page already fetched is shown from memory; only a retry or a page that
    // is not here yet reaches the network.
    if (!force && _pages.containsKey(page)) {
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
      final result = await CommentClient(server).fetch(_queryFor(page));
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _pages[page] = result;
        // A name query says which song it matched; an id query leaves the
        // song as picked. The first answer decides, so a stale match from an
        // earlier page never lingers.
        if (result.song != null) {
          _song = result.song;
          _pickedManually = false;
        }
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

  /// Orders the list differently: the pages of the previous order do not apply.
  void _changeSort(CommentSort sort) {
    if (sort == _sort) {
      return;
    }
    setState(() {
      _sort = sort;
      _pages.clear();
      _page = 1;
    });
    _load(1);
  }

  /// Reads the comments of a song picked by hand, which is trusted as-is.
  void _pickSong(CommentSong song) {
    setState(() {
      _song = song;
      _pickedManually = true;
      _pages.clear();
      _page = 1;
      _errorReason = null;
    });
    _load(1);
  }

  /// The replies of one comment, fetched a floor page at a time. A null return
  /// means the floor could not be read; the tile then keeps what it has.
  Future<CommentReplyResult?> _loadReplies(String songId, String commentId, String? time) async {
    final server = _server;
    if (server == null) {
      return null;
    }
    try {
      return await CommentClient(server).fetchReplies(songId, commentId, time: time);
    } on CommentFetchException {
      return null;
    }
  }

  Future<void> _openSongPicker() async {
    final picked = await showModalBottomSheet<CommentSong>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SongPickerSheet(
        server: _server!,
        initialKeywords: '${getTitle(widget.currentSong)} ${getArtist(widget.currentSong)}',
      ),
    );
    if (picked != null) {
      _pickSong(picked);
    }
  }

  void _goTo(int page) {
    if (page < 1 || _loading) {
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
                      if (_server != null) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: _matchedRow(l10n, textColor),
                        ),
                        const SizedBox(height: 8),
                        _sortChips(l10n, textColor),
                      ],
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

  /// Which song the comments are really about, with a way to change it.
  Widget _matchedRow(AppLocalizations l10n, Color textColor) {
    final song = _song;
    if (song == null) {
      return const SizedBox.shrink();
    }
    final mismatch = _songMismatch;
    final label = mismatch
        ? l10n.commentMismatchTitle
        : l10n.commentMatchedSong(song.name);
    return Row(
      children: [
        Icon(
          mismatch ? Icons.link_off_rounded : Icons.link_rounded,
          size: 14,
          color: textColor.withAlpha(mismatch ? 200 : 140),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: textColor.withAlpha(mismatch ? 200 : 150),
            ),
          ),
        ),
        GestureDetector(
          onTap: _openSongPicker,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Text(
              l10n.commentChangeSong,
              style: TextStyle(
                fontSize: 12,
                color: colorManager.getSpecificButtonColor(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The three orders the server offers, as pills with the selected one
  /// filled.
  Widget _sortChips(AppLocalizations l10n, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final (sort, label) in [
          (CommentSort.recommended, l10n.commentSortRecommended),
          (CommentSort.hot, l10n.commentSortHot),
          (CommentSort.time, l10n.commentSortTime),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _pagerButton(
              label,
              sort == _sort ? () {} : () => _changeSort(sort),
              textColor: textColor,
              filled: sort == _sort,
            ),
          ),
      ],
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
    // The server matched a song that is clearly not this one: its comments
    // stay hidden until the user confirms which song they want.
    if (_songMismatch) {
      return [
        _message(
          l10n.commentMismatchTitle,
          detail: l10n.commentMismatchDetail(_song!.name),
          textColor: textColor,
          actionLabel: l10n.commentPickSong,
          onAction: _openSongPicker,
        ),
      ];
    }
    // Nothing has loaded yet and nothing failed: this is the first request.
    if (_loading && !_pages.containsKey(_page)) {
      return [_loadingState(textColor)];
    }

    final result = _current;
    final comments = result?.page.comments ?? const <SongComment>[];
    if (comments.isEmpty) {
      return [
        _message(
          l10n.commentEmpty,
          textColor: textColor,
          detail: (result?.total ?? 0) > 0
              ? l10n.commentTotalCount(result!.total)
              : null,
        ),
      ];
    }

    return [
      // The server already ordered the page (recommended, hot or by time), so
      // the order it sent is kept.
      for (final comment in comments)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _CommentTile(
            key: ValueKey('${_sort.index}_${_song?.id}_${_page}_${comment.commentId}'),
            comment: comment,
            fade: _fadeController,
            textColor: textColor,
            onLoadReplies: (commentId, time) =>
                _loadReplies(_song?.id ?? comment.songId, commentId, time),
          ),
        ),
      if ((result?.total ?? 0) > 0)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            l10n.commentTotalCount(result!.total),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: textColor.withAlpha(130)),
          ),
        ),
      if (_hasPrevious || _hasNext) _pager(l10n, textColor),
      if (_loading) ...[
        const SizedBox(height: 8),
        LinearProgressIndicator(color: colorManager.getSpecificButtonColor()),
      ],
    ];
  }

  String _errorDetail(AppLocalizations l10n, String reason) {
    switch (reason) {
      case 'forbidden':
        return l10n.commentForbidden;
      case 'unreachable':
        return l10n.commentUnreachable;
      case 'notFound':
        return l10n.commentSongNotFound;
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
              (_current?.pageCount ?? 0) > 0
                  ? l10n.commentPageOf(_page, _current!.pageCount)
                  : l10n.commentPageIndicator(_page),
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

  /// Reads one more page of the floor's replies, passed the comment id and the
  /// last page's `time` cursor. A null return means the floor could not be
  /// read, so the tile keeps what it has.
  final Future<CommentReplyResult?> Function(String commentId, String? time)
  onLoadReplies;

  const _CommentTile({
    super.key,
    required this.comment,
    required this.fade,
    required this.textColor,
    required this.onLoadReplies,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool expanded = false;

  /// The floor's replies, starting from what the page brought along; more are
  /// appended by [loadMoreReplies].
  late final List<SongComment> replies = List.of(widget.comment.replies);

  /// The floor cursor of the next request, when a page before it set one.
  String? _nextTime;

  /// Whether the floor still has replies the tile has not shown.
  bool get _floorHasMore =>
      widget.comment.repliesHasMore ||
      widget.comment.replyCount > replies.length;

  bool _loadingReplies = false;

  /// Appends one more page of the floor, keeping what is already there.
  Future<void> loadMoreReplies() async {
    if (_loadingReplies) {
      return;
    }
    setState(() => _loadingReplies = true);
    final result = await widget.onLoadReplies(
      widget.comment.commentId,
      _nextTime,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _loadingReplies = false;
      if (result != null) {
        // The floor pages are already newest first, so they join in order.
        replies.addAll(result.replies);
        _nextTime = result.nextTime;
      }
    });
  }

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
                if (comment.ipLocation.trim().isNotEmpty) ...[
                  if (comment.createTime > 0) const SizedBox(width: 12),
                  Text(
                    comment.ipLocation.trim(),
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withAlpha(120),
                    ),
                  ),
                ],
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
              for (final reply in replies)
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
              if (_floorHasMore)
                Padding(
                  padding: const EdgeInsets.only(left: 46, top: 8),
                  child: _loadingReplies
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: textColor.withAlpha(140),
                          ),
                        )
                      : GestureDetector(
                          onTap: loadMoreReplies,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              l10n.commentShowMoreReplies,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorManager.getSpecificButtonColor(),
                              ),
                            ),
                          ),
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

/// A bottom sheet that searches the server's song list, so the user can pick
/// the song whose comments should really be shown.
///
/// The search runs debounced while typing; picking a song pops the sheet with
/// it. It is shown by the comments page when the server matched the wrong song
/// or the user asked for another one.
class _SongPickerSheet extends StatefulWidget {
  final CommentServer server;

  /// What the search field starts with: the local track's title and artist.
  final String initialKeywords;

  const _SongPickerSheet({
    required this.server,
    required this.initialKeywords,
  });

  @override
  State<_SongPickerSheet> createState() => _SongPickerSheetState();
}

class _SongPickerSheetState extends State<_SongPickerSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialKeywords,
  );
  Timer? _debounce;
  bool _loading = false;
  List<CommentSong> _songs = const [];
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    // The sheet opens with the local track as keywords, so the first answer is
    // already a match instead of an empty list.
    Future.microtask(_search);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _search);
  }

  Future<void> _search() async {
    final keywords = _controller.text.trim();
    if (keywords.isEmpty) {
      setState(() {
        _songs = const [];
        _searched = false;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    List<CommentSong> songs;
    try {
      songs = await CommentClient(widget.server).searchSongs(keywords);
    } catch (_) {
      songs = const [];
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      _songs = songs;
      _searched = true;
    });
  }

  String _formatDuration(int milliseconds) {
    if (milliseconds <= 0) {
      return '';
    }
    final total = milliseconds ~/ 1000;
    final minutes = (total ~/ 60).toString().padLeft(2, '0');
    final seconds = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                l10n.commentSearchTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onChanged,
                onSubmitted: (_) => _search(),
                style: TextStyle(color: textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: l10n.commentSearchHint,
                  hintStyle: TextStyle(color: textColor.withAlpha(110)),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: textColor.withAlpha(140),
                  ),
                  filled: true,
                  fillColor: textColor.withAlpha(16),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_songs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    _searched ? l10n.commentSearchEmpty : '',
                    style: TextStyle(
                      fontSize: 13,
                      color: textColor.withAlpha(130),
                    ),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _songs.length,
                  itemBuilder: (context, index) {
                    final song = _songs[index];
                    final duration = _formatDuration(song.duration);
                    return ListTile(
                      dense: true,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: song.coverUrl.trim().isEmpty
                              ? Container(
                                  color: textColor.withAlpha(24),
                                  child: Icon(
                                    Icons.music_note_rounded,
                                    size: 20,
                                    color: textColor.withAlpha(140),
                                  ),
                                )
                              : Image.network(
                                  song.coverUrl.trim(),
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        color: textColor.withAlpha(24),
                                        child: Icon(
                                          Icons.music_note_rounded,
                                          size: 20,
                                          color: textColor.withAlpha(140),
                                        ),
                                      ),
                                ),
                        ),
                      ),
                      title: Text(
                        song.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor.withAlpha(220),
                        ),
                      ),
                      subtitle: Text(
                        duration.isEmpty
                            ? '${song.artist}${song.album.isEmpty ? '' : ' · ${song.album}'}'
                            : '${song.artist}${song.album.isEmpty ? '' : ' · ${song.album}'} · $duration',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor.withAlpha(130),
                        ),
                      ),
                      onTap: () => Navigator.of(context).pop(song),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
