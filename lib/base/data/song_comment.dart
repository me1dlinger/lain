/// A comment authored by a listener, on a song the user is playing.
///
/// Level comes from [type]: a floor-level reply carries a list of second level
/// replies, which are shown collapsed under it.
class SongComment {
  /// The song the comment belongs to, as the source identifies it.
  final String songId;

  final String commentId;
  final String nick;
  final String avatarUrl;
  final String content;

  /// Likes / likes count, what the list is sorted by.
  int praiseNum;

  /// Unix seconds.
  int createTime;

  /// Second level replies, empty when there are none. Only the first few come
  /// with the comment; the rest are fetched on demand ([repliesHasMore]).
  final List<SongComment> replies;

  /// How many replies the whole floor has, as the server counts it; may be
  /// more than [replies].length.
  final int replyCount;

  /// Whether [replies] is only the start of the floor, so more can be fetched.
  final bool repliesHasMore;

  /// The server's IP-location label for the author, when it has one.
  final String ipLocation;

  /// Whether this comment came from the source's featured ("hot") section.
  final bool isHot;

  SongComment({
    required this.songId,
    required this.commentId,
    required this.nick,
    required this.avatarUrl,
    required this.content,
    required this.praiseNum,
    required this.createTime,
    this.replies = const [],
    this.replyCount = 0,
    this.repliesHasMore = false,
    this.ipLocation = '',
    this.isHot = false,
  });

  /// A copy with the fields the featured section may improve on.
  SongComment withHot(bool hot) => SongComment(
    songId: songId,
    commentId: commentId,
    nick: nick,
    avatarUrl: avatarUrl,
    content: content,
    praiseNum: praiseNum,
    createTime: createTime,
    replies: replies,
    replyCount: replyCount,
    repliesHasMore: repliesHasMore,
    ipLocation: ipLocation,
    isHot: hot,
  );
}

/// The song the comment server matched a query to, so the page can tell the
/// user which song the comments really belong to.
class CommentSong {
  final String id;
  final String name;

  /// Artists joined with `/`, as the server sends them.
  final String artist;

  final String album;
  final String coverUrl;

  /// Milliseconds; 0 when the server did not say.
  final int duration;

  const CommentSong({
    required this.id,
    required this.name,
    required this.artist,
    this.album = '',
    this.coverUrl = '',
    this.duration = 0,
  });
}

/// One page of comments for a song, as a source returned them.
class CommentPage {
  final List<SongComment> comments;

  /// Whether the source has more pages after this one.
  final bool hasMore;

  const CommentPage({required this.comments, required this.hasMore});

  static const empty = CommentPage(comments: [], hasMore: false);

  bool get isEmpty => comments.isEmpty;
}
