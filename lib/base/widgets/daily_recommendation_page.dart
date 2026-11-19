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
import 'package:lain/base/widgets/my_sheet.dart';
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
          tooltip: l10n.dailyMixCalendar,
          icon: const Icon(Icons.calendar_month_rounded),
          onPressed: _loading ? null : _openCalendar,
        ),
        IconButton(
          tooltip: l10n.refresh,
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loading ? null : _refreshToday,
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

  Future<void> _refreshToday() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context,
      l10n.dailyMixRefreshConfirm,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _loading = true);
    final day = await dailyRecommendations.ensureToday(refresh: true);
    if (!mounted) {
      return;
    }
    setState(() {
      _day = day;
      _history = dailyRecommendations.days();
      _loading = false;
    });
  }

  Future<void> _openCalendar() async {
    final today = dailyRecommendations.today()?.date ?? '';
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DailyMixCalendar(
        days: _history,
        selected: _day?.date ?? '',
        today: today,
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    final day = dailyRecommendations.day(result);
    if (day != null && day.date != _day?.date) {
      tryVibrate();
      setState(() => _day = day);
    }
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

String _calendarDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// A month calendar that only lights up days with a saved recommendation.
/// Picking one returns its date; the page owns the selection and the list
/// animation, so the sheet can close immediately.
class _DailyMixCalendar extends StatefulWidget {
  final List<DailyMixDay> days;
  final String selected;
  final String today;

  const _DailyMixCalendar({
    required this.days,
    required this.selected,
    required this.today,
  });

  @override
  State<_DailyMixCalendar> createState() => _DailyMixCalendarState();
}

class _DailyMixCalendarState extends State<_DailyMixCalendar> {
  late DateTime _month;
  bool _forward = true;

  static DateTime _parse(String value) =>
      DateTime.tryParse(value) ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    final anchor = widget.selected.isNotEmpty
        ? widget.selected
        : widget.today.isNotEmpty
        ? widget.today
        : _calendarDateKey(DateTime.now());
    final date = _parse(anchor);
    _month = DateTime(date.year, date.month);
  }

  void _moveMonth(int delta) {
    if (!_canMove(delta)) {
      return;
    }
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _forward = delta > 0;
    });
  }

  DateTime? get _oldestDay {
    if (widget.days.isEmpty) {
      return null;
    }
    var date = _parse(widget.days.first.date);
    for (final day in widget.days.skip(1)) {
      final other = _parse(day.date);
      if (other.isBefore(date)) {
        date = other;
      }
    }
    return DateTime(date.year, date.month);
  }

  DateTime get _newestDay {
    var date = widget.today.isNotEmpty
        ? _parse(widget.today)
        : _parse(widget.days.first.date);
    for (final day in widget.days) {
      final other = _parse(day.date);
      if (other.isAfter(date)) {
        date = other;
      }
    }
    return DateTime(date.year, date.month);
  }

  bool _canMove(int delta) {
    if (delta < 0) {
      final oldest = _oldestDay;
      return oldest != null && _month.isAfter(oldest);
    }
    return _month.isBefore(_newestDay);
  }

  void _pick(String date) {
    if (date.isEmpty) {
      return;
    }
    tryVibrate();
    Navigator.pop(context, date);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loc = MaterialLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();
    final accent = Theme.of(context).colorScheme.primary;
    final byDate = {for (final day in widget.days) day.date: day};
    final selectedDay = byDate[widget.selected];
    final selectedLabel = widget.selected == widget.today
        ? l10n.dailyMixToday
        : widget.selected;
    final firstWeekday = loc.firstDayOfWeekIndex;
    final weekdays = [
      for (var i = 0; i < 7; i++) loc.narrowWeekdays[(firstWeekday + i) % 7],
    ];
    final first = DateTime(_month.year, _month.month, 1);
    final leading = (first.weekday - (firstWeekday + 1) + 7) % 7;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final rows = ((leading + daysInMonth) / 7).ceil();
    final cellCount = rows * 7;

    return MySheet(
      Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 10, 2),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.dailyMixCalendar,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '$selectedLabel · '
                        '${l10n.songCount(selectedDay?.songs.length ?? 0)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor.withAlpha(145),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: loc.previousMonthTooltip,
                  onPressed: _canMove(-1) ? () => _moveMonth(-1) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                SizedBox(
                  width: 116,
                  child: Text(
                    loc.formatMonthYear(_month),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: loc.nextMonthTooltip,
                  onPressed: _canMove(1) ? () => _moveMonth(1) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
            child: Row(
              children: [
                for (final label in weekdays)
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textColor.withAlpha(115),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 230),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final offset = Tween<Offset>(
                  begin: Offset(_forward ? 0.10 : -0.10, 0),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: offset, child: child),
                );
              },
              child: GridView.builder(
                key: ValueKey('${_month.year}-${_month.month}'),
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1,
                ),
                itemCount: cellCount,
                itemBuilder: (context, index) {
                  final dayNumber = index - leading + 1;
                  if (dayNumber < 1 || dayNumber > daysInMonth) {
                    return const SizedBox.shrink();
                  }
                  final date = DateTime(_month.year, _month.month, dayNumber);
                  final key = _calendarDateKey(date);
                  final mix = byDate[key];
                  final selected = key == widget.selected;
                  final today = key == widget.today;
                  return Padding(
                    padding: const EdgeInsets.all(3),
                    child: Semantics(
                      button: mix != null,
                      label: key,
                      child: GestureDetector(
                        onTap: mix == null ? null : () => _pick(key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected
                                ? accent.withAlpha(42)
                                : today
                                ? textColor.withAlpha(12)
                                : Colors.transparent,
                            border: Border.all(
                              color: selected
                                  ? accent.withAlpha(175)
                                  : today
                                  ? textColor.withAlpha(55)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                '$dayNumber',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: mix == null
                                      ? textColor.withAlpha(45)
                                      : selected
                                      ? accent
                                      : textColor,
                                ),
                              ),
                              if (mix != null && !selected)
                                Positioned(
                                  bottom: 5,
                                  child: Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: accent.withAlpha(190),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedDay == null
                        ? l10n.dailyMixEmpty
                        : l10n.songCount(selectedDay.songs.length),
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withAlpha(135),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.selected == widget.today
                      ? null
                      : () => _pick(widget.today),
                  style: TextButton.styleFrom(foregroundColor: accent),
                  icon: const Icon(Icons.today_rounded, size: 17),
                  label: Text(l10n.dailyMixBackToday),
                ),
              ],
            ),
          ),
        ],
      ),
      height: 552,
      maxHeightFactor: 0.82,
    );
  }
}
