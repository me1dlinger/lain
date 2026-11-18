import 'package:material_ui/material_ui.dart';
import 'package:lain/base/audio_handler.dart';
import 'package:lain/base/data/daily_recommendation.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/utils/common_utils.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/base/widgets/local_music_page.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

/// The day's twenty songs, with a date strip back to every earlier day. The
/// list is computed once per day per source and stored; refresh replaces only
/// today's snapshot.
class DailyRecommendationPage extends StatefulWidget {
  const DailyRecommendationPage({super.key});

  @override
  State<DailyRecommendationPage> createState() =>
      _DailyRecommendationPageState();
}

class _DailyRecommendationPageState extends State<DailyRecommendationPage> {
  bool _loading = true;
  DailyMixDay? _day;
  List<DailyMixDay> _history = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh && mounted) {
      setState(() => _loading = true);
    }
    final day = await dailyRecommendations.ensureToday(refresh: refresh);
    if (!mounted) {
      return;
    }
    setState(() {
      _day = day;
      _history = dailyRecommendations.days();
      _loading = false;
    });
  }

  void _select(DailyMixDay day) {
    setState(() => _day = day);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final today = dailyRecommendations.today()?.date;
    final selected = _day;
    return opaqueSettingsPage(
      context: context,
      title: l10n.dailyMix,
      actions: [
        IconButton(
          tooltip: l10n.refresh,
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loading
              ? null
              : () async {
                  final day = await dailyRecommendations.ensureToday(
                    refresh: true,
                  );
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    _day = day;
                    _history = dailyRecommendations.days();
                  });
                },
        ),
      ],
      body: _loading || selected == null
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListenableBuilder(
              listenable: library.changeNotifier,
              builder: (context, child) {
                final resolved = dailyRecommendations.resolve(selected);
                final playable = [
                  for (final item in resolved)
                    if (item.song != null) item.song!,
                ];
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 110),
                  children: [
                    _dayCard(
                      context,
                      l10n,
                      selected,
                      playable,
                      isToday: selected.date == today,
                    ),
                    if (_history.length > 1) ...[
                      const SizedBox(height: 20),
                      _historyStrip(context, l10n, today),
                    ],
                    const SizedBox(height: 14),
                    if (resolved.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            l10n.dailyMixEmpty,
                            style: TextStyle(
                              fontSize: 13,
                              color: colorManager
                                  .getSpecificTextColor()
                                  .withAlpha(145),
                            ),
                          ),
                        ),
                      )
                    else
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        child: Column(
                          key: ValueKey(selected.date),
                          children: [
                            for (var i = 0; i < resolved.length; i++)
                              _row(context, l10n, resolved, i),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }

  Widget _dayCard(
    BuildContext context,
    AppLocalizations l10n,
    DailyMixDay day,
    List<MyAudioMetadata> playable, {
    required bool isToday,
  }) {
    final textColor = colorManager.getSpecificTextColor();
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withAlpha(36), textColor.withAlpha(8)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: textColor.withAlpha(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withAlpha(32),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 22,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isToday ? l10n.dailyMixToday : day.date,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isToday
                          ? '${l10n.songCount(day.songs.length)} · ${day.date}'
                          : l10n.songCount(day.songs.length),
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: playable.isEmpty
                  ? null
                  : () {
                      tryVibrate();
                      audioHandler.setPlayQueue(playable, 0);
                    },
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: Text(l10n.playAll),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyStrip(
    BuildContext context,
    AppLocalizations l10n,
    String? today,
  ) {
    final textColor = colorManager.getSpecificTextColor();
    final selected = _day?.date;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.dailyMixHistory,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor.withAlpha(180),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _history.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final day = _history[index];
              final active = day.date == selected;
              final isToday = day.date == today;
              final label = isToday
                  ? l10n.dailyMixToday
                  : day.date.substring(5).replaceAll('-', '/');
              return GestureDetector(
                onTap: () => _select(day),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: textColor.withAlpha(active ? 48 : 12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: active
                          ? Colors.transparent
                          : textColor.withAlpha(28),
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      color: active
                          ? textColor
                          : textColor.withAlpha(180),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    AppLocalizations l10n,
    List<DailyMixResolved> resolved,
    int index,
  ) {
    final item = resolved[index];
    final song = item.song;
    final textColor = colorManager.getSpecificTextColor();
    final playableIndex = [
      for (var i = 0; i < index; i++)
        if (resolved[i].song != null) i,
    ].length;
    final playable = [
      for (final entry in resolved)
        if (entry.song != null) entry.song!,
    ];
    return Opacity(
      opacity: song == null ? .42 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: song == null
            ? null
            : () {
                audioHandler.setPlayQueue(
                  playable,
                  0,
                  targetIndex: playableIndex,
                );
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '${index + 1}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withAlpha(105),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              song != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CoverArtWidget(
                        size: 46,
                        borderRadius: 8,
                        picture: song.picture,
                      ),
                    )
                  : Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: textColor.withAlpha(12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.link_off_rounded,
                        size: 20,
                        color: textColor.withAlpha(110),
                      ),
                    ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song == null ? item.entry.title : getTitle(song),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song == null
                          ? l10n.dailyMixMissing
                          : '${getArtist(song)} · ${getAlbum(song)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor.withAlpha(140),
                      ),
                    ),
                  ],
                ),
              ),
              if (song != null && getDuration(song) > Duration.zero)
                Text(
                  formatDuration(getDuration(song)),
                  style: TextStyle(
                    fontSize: 11,
                    color: textColor.withAlpha(105),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
