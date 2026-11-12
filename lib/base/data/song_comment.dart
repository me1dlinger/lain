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

  /// Second level replies, empty when there are none.
  final List<SongComment> replies;

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
    this.isHot = false,
  });

  int get replyCount => replies.length;

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
    isHot: hot,
  );
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
