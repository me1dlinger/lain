import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/data/stats.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/layer/layers_manager.dart';

/// Local listening report: a yearly heatmap, the day's ranking, the year's
/// totals and the top songs / artists / albums. Everything comes from
/// [ListeningStats], so all music sources contribute to the same figures; every
/// section is drawn even when it has no data yet.
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  String? selectedYear;

  /// Drives the heatmap's horizontal position: the page opens on the month in
  /// progress rather than on January.
  final _heatController = ScrollController();

  /// Year the grid was last lined up for, so that a rebuild (a theme change,
  /// say) does not drag the view back to it.
  int? _heatAnchoredFor;

  @override
  void dispose() {
    _heatController.dispose();
    super.dispose();
  }

  static const _cell = 13.0;
  static const _cellGap = 3.0;
  static const _monthsZh = [
    '一月', '二月', '三月', '四月', '五月', '六月',
    '七月', '八月', '九月', '十月', '十一月', '十二月',
  ];
  static const _monthsEn = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // The panel colour is translucent by design (it sits over the app's
    // cover-art background); on a pushed page that would show the dark
    // navigator underneath, so composite it into an opaque colour instead.
    return ListenableBuilder(
      listenable: Listenable.merge([
        layersManager.backgroundChangeNotifier,
        panelColor.valueNotifier,
        pageBackgroundColor.valueNotifier,
      ]),
      builder: (context, child) {
        return Scaffold(
          backgroundColor: colorManager.getSpecificOpaqueBgColor(),
          body: SafeArea(
            child: FutureBuilder(
              // The store loads lazily on first use.
              future: stats.ensureLoaded(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Column(
                  children: [
                    _header(l10n),
                    Expanded(child: _content(l10n)),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Color get _textColor => colorManager.getSpecificTextColor();

  // ---- chrome --------------------------------------------------------------

  Widget _header(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: _textColor),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              l10n.listeningReport,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.clear,
            icon: Icon(Icons.delete_sweep_outlined, color: _textColor),
            onPressed: () async {
              if (!await showConfirmDialog(context, l10n.clear)) {
                return;
              }
              await stats.clear();
              if (mounted) {
                setState(() {});
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _content(AppLocalizations l10n) {
    final years = stats.availableYears;
    final currentYear = DateTime.now().year.toString();
    final year = selectedYear ?? (years.isEmpty ? currentYear : years.first);
    final data = stats.year(year);
    final todayKey = _dayKey(DateTime.now());

    return ListView(
      padding: const EdgeInsets.only(bottom: 30),
      children: [
        if (years.length > 1) _yearPicker(years, year),
        _sectionTitle(l10n.yearlyActivity),
        _card(_heatmap(l10n, int.tryParse(year) ?? DateTime.now().year, data)),
        _sectionTitle('${l10n.playRanking}  ($todayKey)'),
        _card(
          _rankList(l10n, [
            for (final song in stats.topSongsOfDay(year, data.days[todayKey], 10))
              _Rank(song.title, song.artist, song.plays),
          ]),
        ),
        _sectionTitle(l10n.yearlyStats),
        _card(_statTiles(l10n, data)),
        _sectionTitle(l10n.popularSongs),
        _card(
          _rankList(l10n, [
            for (final song in stats.topSongs(year, 20))
              _Rank(song.title, song.artist, song.plays),
          ]),
        ),
        _sectionTitle(l10n.topArtists),
        _card(
          _rankList(l10n, [
            for (final artist in stats.topOf(data.artists, 20))
              _Rank(artist.key, '', artist.value),
          ]),
        ),
        _sectionTitle(l10n.popularAlbums),
        _card(
          _rankList(l10n, [
            for (final album in stats.topOf(data.albums, 20))
              _Rank(album.key, '', album.value),
          ]),
        ),
      ],
    );
  }

  Widget _yearPicker(List<String> years, String current) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Wrap(
        spacing: 8,
        children: [
          for (final year in years)
            ChoiceChip(
              label: Text(year),
              selected: year == current,
              onSelected: (_) => setState(() => selectedYear = year),
              labelStyle: TextStyle(fontSize: 13, color: _textColor),
              backgroundColor: _textColor.withAlpha(16),
              selectedColor: _textColor.withAlpha(48),
              side: BorderSide(color: _textColor.withAlpha(60)),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title,
        style: TextStyle(fontSize: 15, color: _textColor.withAlpha(160)),
      ),
    );
  }

  Widget _card(Widget child) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _textColor.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _empty(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Center(
        child: Text(
          l10n.noData,
          style: TextStyle(fontSize: 14, color: _textColor.withAlpha(150)),
        ),
      ),
    );
  }

  // ---- heatmap -------------------------------------------------------------

  String _dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  String _monthLabel(AppLocalizations l10n, int month) {
    final months = l10n.localeName.startsWith('zh') ? _monthsZh : _monthsEn;
    return months[month.clamp(1, 12) - 1];
  }

  Color _cellColor(int plays) {
    if (plays <= 0) {
      return _textColor.withAlpha(20);
    }
    if (plays <= 1) {
      return _textColor.withAlpha(70);
    }
    if (plays <= 4) {
      return _textColor.withAlpha(120);
    }
    if (plays <= 9) {
      return _textColor.withAlpha(175);
    }
    return _textColor.withAlpha(230);
  }

  Widget _heatmap(AppLocalizations l10n, int year, StatsYear data) {
    final first = DateTime(year);
    final last = DateTime(year + 1, 1, 0);
    final start = first.subtract(Duration(days: first.weekday % 7));
    final cells = <DateTime?>[];
    for (
      var day = start;
      !day.isAfter(last);
      day = day.add(const Duration(days: 1))
    ) {
      cells.add(day);
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final weeks = cells.length ~/ 7;
    final pitch = _cell + _cellGap;

    // Which month each week column belongs to, so the labels above the grid span
    // exactly the columns of their month.
    final columnMonth = <int>[];
    var previousMonth = first.month;
    for (var week = 0; week < weeks; week++) {
      var month = previousMonth;
      for (var weekday = 0; weekday < 7; weekday++) {
        final day = cells[week * 7 + weekday];
        if (day != null && day.year == year) {
          month = day.month;
          break;
        }
      }
      columnMonth.add(month);
      previousMonth = month;
    }

    final labels = <Widget>[];
    var index = 0;
    while (index < weeks) {
      final month = columnMonth[index];
      var span = 1;
      while (index + span < weeks && columnMonth[index + span] == month) {
        span++;
      }
      labels.add(
        SizedBox(
          width: pitch * span,
          child: Text(
            _monthLabel(l10n, month),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _textColor.withAlpha(170)),
          ),
        ),
      );
      index += span;
    }

    // Opening the report in November used to show January, leaving the recent
    // weeks a swipe away. Line the grid up on the month in progress: its first
    // column ends up leftmost, and the days around today stay in view.
    if (year != _heatAnchoredFor) {
      _heatAnchoredFor = year;
      final now = DateTime.now();
      final anchor = year == now.year ? columnMonth.indexOf(now.month) : -1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_heatController.hasClients) return;
        final target = anchor <= 0 ? 0.0 : anchor * pitch;
        _heatController.jumpTo(
          target
              .clamp(0.0, _heatController.position.maxScrollExtent)
              .toDouble(),
        );
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          controller: _heatController,
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: labels),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var week = 0; week < weeks; week++)
                    Column(
                      children: [
                        for (var weekday = 0; weekday < 7; weekday++)
                          _heatCell(cells[week * 7 + weekday], data),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              l10n.heatLess,
              style: TextStyle(fontSize: 12, color: _textColor.withAlpha(150)),
            ),
            const SizedBox(width: 6),
            for (final plays in [0, 1, 4, 9, 20])
              Container(
                width: _cell,
                height: _cell,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: _cellColor(plays),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            const SizedBox(width: 6),
            Text(
              l10n.heatMore,
              style: TextStyle(fontSize: 12, color: _textColor.withAlpha(150)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _heatCell(DateTime? day, StatsYear data) {
    var plays = 0;
    if (day != null) {
      plays = data.days[_dayKey(day)]?.plays ?? 0;
    }
    return Container(
      width: _cell,
      height: _cell,
      margin: const EdgeInsets.all(_cellGap / 2),
      decoration: BoxDecoration(
        color: day == null ? Colors.transparent : _cellColor(plays),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  // ---- tiles and lists ------------------------------------------------------

  String _duration(int millis) {
    final hours = millis / 3600000;
    if (hours >= 1) {
      return '${hours.toStringAsFixed(1)}h';
    }
    return '${(millis / 60000).round()}m';
  }

  Widget _statTiles(AppLocalizations l10n, StatsYear data) {
    final days = data.days.values.where((day) => day.plays > 0).length;
    final tiles = <List<String>>[
      [l10n.listeningTime, _duration(data.millis)],
      [l10n.playTimes, '${data.plays}'],
      [l10n.listeningDays, '$days'],
      [l10n.songsTotal, '${data.songs.length}'],
      [l10n.albumsTotal, '${data.albums.length}'],
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final tile in tiles)
          Container(
            width: 100,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _textColor.withAlpha(38),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  tile[1],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tile[0],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: _textColor.withAlpha(160),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _rankList(AppLocalizations l10n, List<_Rank> ranks) {
    if (ranks.isEmpty) {
      return _empty(l10n);
    }
    return Column(
      children: [
        for (var i = 0; i < ranks.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      color: _textColor.withAlpha(140),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ranks[i].title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, color: _textColor),
                      ),
                      if (ranks[i].subtitle.isNotEmpty)
                        Text(
                          ranks[i].subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: _textColor.withAlpha(150),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${ranks[i].count} ${l10n.timesUnit}',
                  style: TextStyle(
                    fontSize: 13,
                    color: _textColor.withAlpha(180),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Rank {
  final String title;
  final String subtitle;
  final int count;

  const _Rank(this.title, this.subtitle, this.count);
}