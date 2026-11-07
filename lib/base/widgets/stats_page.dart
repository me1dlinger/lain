import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/data/stats.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';

/// Local listening report: a GitHub-style yearly heatmap, the year's totals,
/// the most played songs and the top artists. Everything comes from
/// [ListeningStats], so all music sources contribute to the same figures.
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  String? selectedYear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();

    return ValueListenableBuilder(
      valueListenable: panelColor.valueNotifier,
      builder: (context, background, child) {
        return Scaffold(
          backgroundColor: background,
          body: SafeArea(
            child: Column(
              children: [
                _header(l10n, textColor),
                Expanded(
                  child: FutureBuilder(
                    // The store loads lazily on the first read.
                    future: stats.ensureLoaded(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final years = stats.availableYears;
                      final year = selectedYear ?? (years.isEmpty ? '' : years.first);
                      if (year.isEmpty) {
                        return Center(
                          child: Text(l10n.cacheEmpty, style: TextStyle(color: textColor)),
                        );
                      }
                      final data = stats.year(year);
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        children: [
                          _yearPicker(l10n, years, year, textColor),
                          const SizedBox(height: 12),
                          _sectionTitle(l10n.yearlyActivity, textColor),
                          const SizedBox(height: 8),
                          _heatmap(data, textColor),
                          const SizedBox(height: 20),
                          _sectionTitle(l10n.yearlyStats, textColor),
                          const SizedBox(height: 8),
                          _statCards(l10n, data, textColor),
                          const SizedBox(height: 20),
                          _sectionTitle(l10n.playRanking, textColor),
                          const SizedBox(height: 4),
                          ..._songRows(data, textColor),
                          const SizedBox(height: 20),
                          _sectionTitle(l10n.topArtists, textColor),
                          const SizedBox(height: 4),
                          ..._artistRows(data, textColor),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(AppLocalizations l10n, Color textColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              l10n.listeningReport,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _yearPicker(
    AppLocalizations l10n,
    List<String> years,
    String current,
    Color textColor,
  ) {
    return Wrap(
      spacing: 8,
      children: [
        for (final year in years)
          ChoiceChip(
            label: Text(year),
            selected: year == current,
            onSelected: (_) => setState(() => selectedYear = year),
            labelStyle: TextStyle(color: textColor),
            backgroundColor: textColor.withAlpha(20),
            selectedColor: textColor.withAlpha(60),
            side: BorderSide(color: textColor.withAlpha(80)),
          ),
      ],
    );
  }

  Widget _sectionTitle(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
  }

  // ---- heatmap -------------------------------------------------------------

  List<DateTime?> _cells(int year) {
    final first = DateTime(year);
    final last = DateTime(year + 1, 1, 0);
    // Start on the Sunday of the week that contains January 1st, like GitHub.
    final start = first.subtract(Duration(days: first.weekday % 7));
    final cells = <DateTime?>[];
    for (var day = start; !day.isAfter(last); day = day.add(const Duration(days: 1))) {
      cells.add(day);
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  Color _cellColor(int plays, Color textColor) {
    if (plays <= 0) {
      return textColor.withAlpha(18);
    }
    if (plays <= 1) {
      return textColor.withAlpha(60);
    }
    if (plays <= 4) {
      return textColor.withAlpha(110);
    }
    if (plays <= 9) {
      return textColor.withAlpha(165);
    }
    return textColor.withAlpha(225);
  }

  Widget _heatmap(StatsYear data, Color textColor) {
    final l10n = AppLocalizations.of(context);
    final year = int.tryParse(selectedYear ?? '') ?? DateTime.now().year;
    final cells = _cells(year);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // GitHub scrolls the year horizontally on narrow screens; 53 columns do
        // not fit a phone.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var week = 0; week < cells.length; week += 7)
                Column(
                  children: [
                    for (var weekday = 0; weekday < 7; weekday++)
                      _cell(cells[week + weekday], data, textColor),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(l10n.heatLess, style: TextStyle(fontSize: 11, color: textColor)),
            const SizedBox(width: 4),
            for (final plays in [0, 1, 4, 9, 20])
              Container(
                width: 11,
                height: 11,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: _cellColor(plays, textColor),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            const SizedBox(width: 4),
            Text(l10n.heatMore, style: TextStyle(fontSize: 11, color: textColor)),
          ],
        ),
      ],
    );
  }

  Widget _cell(DateTime? day, StatsYear data, Color textColor) {
    var plays = 0;
    if (day != null) {
      final key =
          '${day.year.toString().padLeft(4, '0')}-'
          '${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}';
      plays = data.days[key]?.plays ?? 0;
    }
    return Container(
      width: 11,
      height: 11,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: day == null ? Colors.transparent : _cellColor(plays, textColor),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // ---- cards and lists -----------------------------------------------------

  String _duration(int millis) {
    final hours = millis / 3600000;
    if (hours >= 1) {
      return '${hours.toStringAsFixed(1)}h';
    }
    return '${(millis / 60000).round()}min';
  }

  Widget _statCards(AppLocalizations l10n, StatsYear data, Color textColor) {
    final days = data.days.values.where((day) => day.plays > 0).length;
    final cards = <List<String>>[
      [l10n.listeningTime, _duration(data.millis)],
      [l10n.playTimes, '${data.plays}'],
      [l10n.listeningDays, '$days'],
      [l10n.songCount, '${data.songs.length}'],
      [l10n.albumCount, '${data.albums.length}'],
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final card in cards)
          Container(
            width: 104,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: textColor.withAlpha(16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card[1],
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  card[0],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: textColor.withAlpha(160)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _rankRow(
    int index,
    String title,
    String subtitle,
    int plays,
    Color textColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: textColor.withAlpha(140),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textColor),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: textColor.withAlpha(150)),
                  ),
              ],
            ),
          ),
          Text(
            '$plays',
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
        ],
      ),
    );
  }

  List<Widget> _songRows(StatsYear data, Color textColor) {
    final songs = data.songs.values.toList()
      ..sort((a, b) => b.plays.compareTo(a.plays));
    return [
      for (var i = 0; i < songs.length && i < 20; i++)
        _rankRow(i, songs[i].title, songs[i].artist, songs[i].plays, textColor),
    ];
  }

  List<Widget> _artistRows(StatsYear data, Color textColor) {
    final artists = data.artists.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (var i = 0; i < artists.length && i < 20; i++)
        _rankRow(i, artists[i].key, '', artists[i].value, textColor),
    ];
  }
}