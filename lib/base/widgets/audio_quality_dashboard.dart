import 'package:material_ui/material_ui.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:lain/base/widgets/apple_form.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/base/widgets/dashboard_widgets.dart';
import 'package:lain/base/widgets/local_music_page.dart';
import 'package:lain/base/widgets/quality_badge.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

/// The local library's audio quality at a glance: tier mix, formats, average
/// bitrate and the files with the highest quality.
class AudioQualityDashboardPage extends StatelessWidget {
  const AudioQualityDashboardPage({super.key});

  static const _hrColor = Color(0xFFD9AE3C);
  static const _sqColor = Color(0xFF6FA8C6);
  static const _hqColor = Color(0xFF8E6745);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return opaqueSettingsPage(
      context: context,
      title: l10n.audioQualityStats,
      body: ListenableBuilder(
        listenable: library.changeNotifier,
        builder: (context, child) {
          final songs = [
            for (final song in library.songList)
              if (song.path != null) song,
          ];
          final tiers = _tiers(songs);
          final total = songs.length;
          final size = songs.fold<int>(0, (sum, song) => sum + (song.size ?? 0));
          final duration = songs.fold<Duration>(
            Duration.zero,
            (sum, song) => sum + (song.duration ?? Duration.zero),
          );
          final bitrates = [
            for (final song in songs)
              if (_kbps(song) != null) _kbps(song)!,
          ];
          final average = bitrates.isEmpty
              ? 0
              : (bitrates.reduce((a, b) => a + b) / bitrates.length).round();
          final lossless = tiers['HR']! + tiers['SQ']!;
          final ratio = total == 0 ? 0.0 : lossless / total;
          final formats = _formats(songs);
          final textColor = colorManager.getSpecificTextColor();

          return ListView(
            padding: const EdgeInsets.only(top: 6, bottom: 130),
            children: [
              DashboardCard(
                child: Row(
                  children: [
                    AnimatedRing(
                      size: 132,
                      strokeWidth: 14,
                      segments: [
                        RingSegment(
                          label: 'HR',
                          value: tiers['HR']!.toDouble(),
                          color: _hrColor,
                        ),
                        RingSegment(
                          label: 'SQ',
                          value: tiers['SQ']!.toDouble(),
                          color: _sqColor,
                        ),
                        RingSegment(
                          label: 'HQ',
                          value: tiers['HQ']!.toDouble(),
                          color: _hqColor,
                        ),
                        RingSegment(
                          label: '?',
                          value: tiers['?']!.toDouble(),
                          color: textColor.withAlpha(55),
                        ),
                      ],
                      center: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$total',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          Text(
                            l10n.songsTotal,
                            style: TextStyle(
                              fontSize: 10,
                              color: textColor.withAlpha(150),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          _heroStat(
                            l10n.totalSize,
                            dashboardSize(size),
                            textColor,
                          ),
                          _heroStat(
                            l10n.totalDuration,
                            dashboardDuration(duration),
                            textColor,
                          ),
                          _heroStat(
                            l10n.averageBitrate,
                            average == 0 ? '—' : '$average kbps',
                            textColor,
                          ),
                          _heroStat(
                            l10n.losslessRatio,
                            '${(ratio * 100).round()}%',
                            textColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              appleSectionTitle(l10n.qualityDistribution),
              DashboardCard(
                child: Column(
                  children: [
                    for (final entry in [
                      ('HR', l10n.hires, _hrColor),
                      ('SQ', l10n.lossless, _sqColor),
                      ('HQ', l10n.lossy, _hqColor),
                      ('?', l10n.unknownQuality, textColor.withAlpha(70)),
                    ])
                      AnimatedMetricBar(
                        label: entry.$2,
                        value: '${tiers[entry.$1] ?? 0}',
                        fraction: total == 0
                            ? 0
                            : (tiers[entry.$1] ?? 0) / total,
                        color: entry.$3,
                      ),
                  ],
                ),
              ),
              appleSectionTitle(l10n.formatDistribution),
              DashboardCard(
                child: Column(
                  children: [
                    for (final entry in formats)
                      AnimatedMetricBar(
                        label: entry.$1,
                        value: '${entry.$2}',
                        fraction: total == 0 ? 0 : entry.$2 / total,
                        color: _formatColor(entry.$1, textColor),
                      ),
                  ],
                ),
              ),
              appleSectionTitle(l10n.highestQualitySongs),
              DashboardCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    for (final song in _topQuality(songs).take(6))
                      ListTile(
                        leading: CoverArtWidget(
                          size: 42,
                          borderRadius: 6,
                          picture: song.picture,
                        ),
                        title: Text(
                          getTitle(song),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, color: textColor),
                        ),
                        subtitle: Text(
                          '${(song.format ?? '').toUpperCase()} · '
                          '${_kbps(song) ?? '—'} kbps',
                          style: TextStyle(
                            fontSize: 11,
                          
                            color: textColor.withAlpha(150),
                          ),
                        ),
                        trailing: _tierPill(song, textColor),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static int? _kbps(MyAudioMetadata song) {
    final raw = song.bitrate;
    if (raw == null) {
      return null;
    }
    return raw > 10000 ? raw ~/ 1000 : raw;
  }

  Map<String, int> _tiers(List<MyAudioMetadata> songs) {
    final result = {'HR': 0, 'SQ': 0, 'HQ': 0, '?': 0};
    for (final song in songs) {
      final label = QualityBadge.classify(song)?.$1 ?? '?';
      result[label] = (result[label] ?? 0) + 1;
    }
    return result;
  }

  List<(String, int)> _formats(List<MyAudioMetadata> songs) {
    final counts = <String, int>{};
    for (final song in songs) {
      final format = (song.format ?? '').trim().toUpperCase();
      final key = format.isEmpty ? '?' : format;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [for (final entry in entries.take(6)) (entry.key, entry.value)];
  }

  Color _formatColor(String format, Color textColor) {
    return switch (format) {
      'FLAC' || 'ALAC' => _sqColor,
      'WAV' || 'AIFF' || 'APE' || 'DSF' || 'DFF' => _hrColor,
      'MP3' || 'AAC' || 'M4A' => _hqColor,
      _ => textColor.withAlpha(70),
    };
  }

  List<MyAudioMetadata> _topQuality(List<MyAudioMetadata> songs) {
    int score(MyAudioMetadata song) {
      final tier = QualityBadge.classify(song)?.$1;
      final base = switch (tier) {
        'HR' => 3,
        'SQ' => 2,
        'HQ' => 1,
        _ => 0,
      };
      return base * 1000000 + (_kbps(song) ?? 0);
    }

    return List.of(songs)..sort((a, b) => score(b).compareTo(score(a)));
  }

  Widget _tierPill(MyAudioMetadata song, Color textColor) {
    final info = QualityBadge.classify(song);
    if (info == null) {
      return Text(
        '—',
        style: TextStyle(color: textColor.withAlpha(120), fontSize: 12),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: info.$3.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: info.$3.withValues(alpha: 0.35)),
      ),
      child: Text(
        info.$1,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: info.$3,
        ),
      ),
    );
  }

  Widget _heroStat(String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: textColor.withAlpha(150)),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
