import 'package:material_ui/material_ui.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/data/stats.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/picture_service.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

/// A story-like review of one year of listening: the totals, the top artist,
/// the top songs and albums, and the monthly rhythm. Data comes from the same
/// [ListeningStats] store as the report page.
class AnnualReportPage extends StatefulWidget {
  final String year;

  const AnnualReportPage({super.key, required this.year});

  @override
  State<AnnualReportPage> createState() => _AnnualReportPageState();
}

class _AnnualReportPageState extends State<AnnualReportPage> {
  final _pages = PageController();
  int _page = 0;
  final Map<String, MyPicture> _pictures = {};

  @override
  void initState() {
    super.initState();
    for (final song in library.songList) {
      final key = _songKey(song.title ?? '', song.artist ?? '');
      if (!_pictures.containsKey(key)) {
        _pictures[key] = song.picture;
      }
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  static String _songKey(String title, String artist) =>
      '${title.toLowerCase().trim()}|${artist.toLowerCase().trim()}';

  MyPicture? _songPicture(StatsSong? song) {
    if (song == null) {
      return null;
    }
    return _pictures[_songKey(song.title, song.artist)];
  }

  MyPicture? _albumPicture(String album) {
    final wanted = album.toLowerCase().trim();
    for (final song in library.songList) {
      if ((song.album ?? '').toLowerCase().trim() == wanted) {
        return song.picture;
      }
    }
    return null;
  }

  String _hours(int millis) {
    final hours = millis / 3600000;
    if (hours >= 10) {
      return hours.toStringAsFixed(0);
    }
    return hours.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final data = stats.year(widget.year);
    final accent = colorManager.getSpecificButtonColor();
    final topArtist = stats.topOf(data.artists, 1);
    final topSong = stats.topSongs(widget.year, 1).firstOrNull;
    final topAlbum = stats.topOf(data.albums, 1).firstOrNull;
    final days = data.days.values.where((day) => day.plays > 0).length;
    final months = _monthlyPlays(data);
    final bestMonth = months.indexOf(months.reduce((a, b) => a > b ? a : b)) + 1;
    final streak = _longestStreak(data);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView(
            controller: _pages,
            onPageChanged: (page) => setState(() => _page = page),
            children: [
              _pageOne(
                l10n,
                data,
                accent,
                days,
              ),
              _pageArtist(l10n, data, accent, topArtist),
              _pageSongs(l10n, data, accent, topSong, topAlbum),
              _pageMonths(l10n, accent, months, bestMonth, streak),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.year,
                    style: TextStyle(
                      color: Colors.white.withAlpha(190),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 4; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 18 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(i == _page ? 210 : 70),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shell({required Color accent, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(accent, Colors.black, 0.80)!,
            const Color(0xFF08080A),
            Color.lerp(accent, Colors.black, 0.55)!,
          ],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 64, 28, 48),
          child: child,
        ),
      ),
    );
  }

  Widget _pageOne(
    AppLocalizations l10n,
    StatsYear data,
    Color accent,
    int days,
  ) {
    return _shell(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.year,
            style: TextStyle(
              fontSize: 76,
              height: 0.95,
              fontWeight: FontWeight.w800,
              color: Colors.white.withAlpha(240),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.annualReport,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: Colors.white.withAlpha(190),
            ),
          ),
          const SizedBox(height: 44),
          if (data.plays == 0)
            Text(
              l10n.annualNoData,
              style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 15),
            )
          else ...[
            Text(
              l10n.listeningTime,
              style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 13),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _hours(data.millis),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 72,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 10),
                  child: Text(
                    l10n.hoursUnit,
                    style: TextStyle(
                      color: Colors.white.withAlpha(170),
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _stat(l10n.playTimes, '${data.plays}'),
                _stat(l10n.annualDaysMusic, '$days'),
                _stat(l10n.songsTotal, '${data.songs.length}'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _pageArtist(
    AppLocalizations l10n,
    StatsYear data,
    Color accent,
    List<MapEntry<String, int>> topArtist,
  ) {
    final ranks = stats.topOf(data.artists, 5);
    final max = ranks.isEmpty ? 1 : ranks.first.value;
    return _shell(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.annualTopArtist,
            style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            topArtist.isEmpty ? '—' : topArtist.first.key,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 46,
              height: 1.05,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (topArtist.isNotEmpty)
            Text(
              '${topArtist.first.value} ${l10n.timesUnit}',
              style: TextStyle(
                color: Colors.white.withAlpha(170),
                fontSize: 15,
              ),
            ),
          const SizedBox(height: 42),
          for (var i = 0; i < ranks.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 10,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: Colors.white.withAlpha(110),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          ranks[i].key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        '${ranks[i].value}',
                        style: TextStyle(
                          color: Colors.white.withAlpha(140),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: ranks[i].value / max,
                      minHeight: 3,
                      backgroundColor: Colors.white.withAlpha(18),
                      valueColor: AlwaysStoppedAnimation(
                        Color.lerp(accent, Colors.white, 0.25)!,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _pageSongs(
    AppLocalizations l10n,
    StatsYear data,
    Color accent,
    StatsSong? topSong,
    MapEntry<String, int>? topAlbum,
  ) {
    final songs = stats.topSongs(widget.year, 5);
    return _shell(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.annualTopSong,
            style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 13),
          ),
          const SizedBox(height: 10),
          if (topSong != null)
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CoverArtWidget(
                    size: 96,
                    picture: _songPicture(topSong),
                    useResize: false,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topSong.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${topSong.artist} · ${topSong.plays} ${l10n.timesUnit}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withAlpha(160),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 26),
          Text(
            l10n.annualTopAlbum,
            style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 13),
          ),
          const SizedBox(height: 10),
          if (topAlbum != null)
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CoverArtWidget(
                    size: 82,
                    picture: _albumPicture(topAlbum.key),
                    useResize: false,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topAlbum.key,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${topAlbum.value} ${l10n.timesUnit}',
                        style: TextStyle(
                          color: Colors.white.withAlpha(160),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 28),
          Text(
            l10n.popularSongs,
            style: TextStyle(color: Colors.white.withAlpha(85), fontSize: 13),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < songs.length; i++)
            _songRow(i + 1, songs[i], l10n),
        ],
      ),
    );
  }

  Widget _songRow(int rank, StatsSong song, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '$rank',
              style: TextStyle(color: Colors.white.withAlpha(110), fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          Text(
            '${song.plays} ${l10n.timesUnit}',
            style: TextStyle(color: Colors.white.withAlpha(140), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _pageMonths(
    AppLocalizations l10n,
    Color accent,
    List<int> months,
    int bestMonth,
    int streak,
  ) {
    final max = months.isEmpty ? 1 : months.reduce((a, b) => a > b ? a : b);
    return _shell(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.annualMonthly,
            style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.annualBestMonth,
            style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 12),
          ),
          Text(
            _monthName(l10n, bestMonth),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 26),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 12; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 500),
                                height: 120 * (months[i] / max) + 2,
                                decoration: BoxDecoration(
                                  color: i + 1 == bestMonth
                                      ? Color.lerp(accent, Colors.white, 0.18)
                                      : Colors.white.withAlpha(35),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: Colors.white.withAlpha(110),
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              l10n.annualStreak(streak),
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  List<int> _monthlyPlays(StatsYear data) {
    final months = List<int>.filled(12, 0);
    for (final entry in data.days.entries) {
      final date = DateTime.tryParse(entry.key);
      if (date == null || date.month < 1 || date.month > 12) {
        continue;
      }
      months[date.month - 1] += entry.value.plays;
    }
    return months;
  }

  int _longestStreak(StatsYear data) {
    final days = [
      for (final key in data.days.keys)
        if ((data.days[key]?.plays ?? 0) > 0) DateTime.tryParse(key),
    ].whereType<DateTime>().toList()..sort();
    var best = 0;
    var run = 0;
    DateTime? previous;
    for (final day in days) {
      if (previous != null &&
          day.difference(previous).inDays == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > best) {
        best = run;
      }
      previous = day;
    }
    return best;
  }

  String _monthName(AppLocalizations l10n, int month) {
    if (l10n.localeName.startsWith('zh')) {
      const months = [
        '一月',
        '二月',
        '三月',
        '四月',
        '五月',
        '六月',
        '七月',
        '八月',
        '九月',
        '十月',
        '十一月',
        '十二月',
      ];
      return months[(month - 1).clamp(0, 11)];
    }
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[(month - 1).clamp(0, 11)];
  }
}
