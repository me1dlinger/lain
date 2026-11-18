import 'package:material_ui/material_ui.dart';
import 'package:lain/base/audio_handler.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/data/playback_journal.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/utils/common_utils.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/base/widgets/local_music_page.dart';
import 'package:lain/base/widgets/my_sheet.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

/// A diary of listening runs: what was played, how much of it, and the queue
/// that was in use. It is deliberately separate from the aggregate statistics
/// page - this one can be reopened and replayed.
class SessionDiaryPage extends StatefulWidget {
  const SessionDiaryPage({super.key});

  @override
  State<SessionDiaryPage> createState() => _SessionDiaryPageState();
}

class _SessionDiaryPageState extends State<SessionDiaryPage> {
  List<JournalSession> _sessions = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await playbackJournal.ensureLoaded();
    if (!mounted) {
      return;
    }
    setState(() {
      _sessions = playbackJournal.history;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final memories = playbackJournal.onThisDay(DateTime.now());
    return opaqueSettingsPage(
      context: context,
      title: l10n.sessionDiary,
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 110),
              children: [
                if (memories.isNotEmpty) _memoryCard(context, l10n, memories),
                if (_sessions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 80),
                    child: Center(
                      child: Text(
                        l10n.sessionNoSessions,
                        style: TextStyle(
                          fontSize: 14,
                          color: colorManager
                              .getSpecificTextColor()
                              .withAlpha(140),
                        ),
                      ),
                    ),
                  )
                else
                  ..._groupedSessions(context, l10n),
              ],
            ),
    );
  }

  Widget _memoryCard(
    BuildContext context,
    AppLocalizations l10n,
    List<JournalSession> memories,
  ) {
    final textColor = colorManager.getSpecificTextColor();
    final accent = Theme.of(context).colorScheme.primary;
    final byYear = <int, List<JournalSession>>{};
    for (final session in memories) {
      byYear.putIfAbsent(session.startedAt.year, () => []).add(session);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent.withAlpha(34), textColor.withAlpha(8)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: textColor.withAlpha(18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 19, color: accent),
                const SizedBox(width: 8),
                Text(
                  l10n.sessionTodayMemories,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final entry in byYear.entries)
              GestureDetector(
                onTap: () => _showSessions(entry.value, l10n),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Text(
                        '${DateTime.now().year - entry.key} 年前的今天',
                        style: TextStyle(fontSize: 13, color: textColor),
                      ),
                      const Spacer(),
                      Text(
                        '${entry.value.length} 段 · '
                        '${formatDuration(Duration(milliseconds: entry.value.fold<int>(0, (sum, item) => sum + item.listenedMs)))}',
                        style: TextStyle(
                          fontSize: 11,
                          color: textColor.withAlpha(140),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 17,
                        color: textColor.withAlpha(120),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _groupedSessions(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final textColor = colorManager.getSpecificTextColor();
    final groups = <String, List<JournalSession>>{};
    for (final session in _sessions.take(120)) {
      final day = _dayKey(session.startedAt);
      groups.putIfAbsent(day, () => []).add(session);
    }
    final widgets = <Widget>[];
    for (final entry in groups.entries) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 16, 2, 7),
          child: Text(
            entry.key,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor.withAlpha(155),
            ),
          ),
        ),
      );
      for (final session in entry.value) {
        widgets.add(_sessionCard(context, l10n, session));
      }
    }
    return widgets;
  }

  Widget _sessionCard(
    BuildContext context,
    AppLocalizations l10n,
    JournalSession session,
  ) {
    final textColor = colorManager.getSpecificTextColor();
    final accent = Theme.of(context).colorScheme.primary;
    final firstSong = session.events.isEmpty
        ? null
        : library.id2Song[session.events.first.songId];
    final current = session == playbackJournal.current;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => _showDetail(session, l10n),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: textColor.withAlpha(12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              firstSong != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CoverArtWidget(
                        size: 46,
                        borderRadius: 8,
                        picture: firstSong.picture,
                      ),
                    )
                  : Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: textColor.withAlpha(18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.history_rounded,
                        size: 22,
                        color: textColor.withAlpha(130),
                      ),
                    ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_time(session.startedAt)} – '
                      '${session.endedAt == null ? '…' : _time(session.endedAt!)}'
                      '${current ? ' · 进行中' : ''}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${session.trackCount} 首 · '
                      '${formatDuration(Duration(milliseconds: session.listenedMs))}'
                      ' · ${session.completedCount} ${l10n.sessionCompleted}'
                      ' · ${session.skippedCount} ${l10n.sessionSkipped}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: textColor.withAlpha(135),
                      ),
                    ),
                  ],
                ),
              ),
              if (session.queue.isNotEmpty)
                IconButton(
                  tooltip: l10n.sessionResumeQueue,
                  icon: Icon(
                    Icons.playlist_play_rounded,
                    size: 21,
                    color: session.sourceKey == playbackJournal.sourceKey
                        ? accent
                        : textColor.withAlpha(80),
                  ),
                  onPressed: session.sourceKey == playbackJournal.sourceKey
                      ? () => _restore(session, l10n)
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(JournalSession session, AppLocalizations l10n) {
    final textColor = colorManager.getSpecificTextColor();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) {
        return MySheet(
          height: 620,
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_dayKey(session.startedAt)} · '
                        '${_time(session.startedAt)}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    if (session.queue.isNotEmpty)
                      IconButton(
                        tooltip: l10n.sessionResumeQueue,
                        icon: Icon(
                          Icons.playlist_play_rounded,
                          color: session.sourceKey ==
                                  playbackJournal.sourceKey
                              ? Theme.of(context).colorScheme.primary
                              : textColor.withAlpha(80),
                        ),
                        onPressed:
                            session.sourceKey == playbackJournal.sourceKey
                            ? () => _restore(session, l10n)
                            : null,
                      ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: textColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: session.events.length,
                  itemBuilder: (context, index) {
                    final event = session.events[index];
                    return _eventRow(event, textColor);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _eventRow(JournalEvent event, Color textColor) {
    final song = library.id2Song[event.songId];
    final ratio = event.completionRatio;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: song != null
                ? CoverArtWidget(size: 36, borderRadius: 6, picture: song.picture)
                : Container(
                    width: 36,
                    height: 36,
                    color: textColor.withAlpha(14),
                    child: Icon(
                      Icons.music_note_rounded,
                      size: 17,
                      color: textColor.withAlpha(110),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: textColor),
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 2,
                    backgroundColor: textColor.withAlpha(20),
                    valueColor: AlwaysStoppedAnimation(
                      ratio >= 0.9
                          ? Theme.of(context).colorScheme.primary
                          : textColor.withAlpha(100),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            ratio >= 0.9
                ? '✓'
                : '${formatDuration(Duration(milliseconds: event.playedMs))}',
            style: TextStyle(
              fontSize: 10,
              color: textColor.withAlpha(120),
            ),
          ),
        ],
      ),
    );
  }

  void _showSessions(List<JournalSession> sessions, AppLocalizations l10n) {
    final textColor = colorManager.getSpecificTextColor();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) {
        return MySheet(
          height: 480,
          ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${_dayKey(session.startedAt)} · ${_time(session.startedAt)}',
                  style: TextStyle(color: textColor, fontSize: 14),
                ),
                subtitle: Text(
                  '${session.trackCount} 首 · '
                  '${formatDuration(Duration(milliseconds: session.listenedMs))}',
                  style: TextStyle(fontSize: 11, color: textColor.withAlpha(135)),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(context);
                  _showDetail(session, l10n);
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _restore(JournalSession session, AppLocalizations l10n) async {
    final songs = <MyAudioMetadata>[];
    for (final track in session.queue) {
      final song = library.id2Song[track.id];
      if (song != null) {
        songs.add(song);
      }
    }
    if (songs.isEmpty) {
      showCenterMessage(l10n.sessionNoSessions);
      return;
    }
    final index = session.queueIndex.clamp(0, songs.length - 1);
    await audioHandler.setPlayQueue(songs, session.playMode, targetIndex: index);
  }

  static String _dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String _time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}
