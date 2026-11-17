import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:lain/base/audio_handler.dart';
import 'package:lain/base/services/audio_output.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:lain/base/widgets/apple_form.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/base/widgets/local_music_page.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

/// Where the sound is going, and at what rate Android is running the output.
/// The buffer and rate are read from the platform; the Bluetooth codec is
/// deliberately not guessed - Android does not expose the negotiated codec to
/// ordinary apps.
class AudioOutputPage extends StatefulWidget {
  const AudioOutputPage({super.key});

  @override
  State<AudioOutputPage> createState() => _AudioOutputPageState();
}

class _AudioOutputPageState extends State<AudioOutputPage> {
  AudioOutputInfo? _info;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final info = await audioOutputService.query();
    if (mounted) {
      setState(() => _info = info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return opaqueSettingsPage(
      context: context,
      title: l10n.audioOutput,
      body: ListenableBuilder(
        listenable: currentSongNotifier,
        builder: (context, child) {
          final info = _info;
          return ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            children: [
              _routeCard(context, l10n, info),
              appleSectionTitle(l10n.audioSourceFormat),
              _sourceCard(context, l10n),
              if (info != null) ...[
                appleSectionTitle(l10n.audioOutput),
                _detailTile(
                  Icons.speed_rounded,
                  l10n.audioOutputSampleRate,
                  _rateText(info.sampleRate),
                ),
                _detailTile(
                  Icons.blur_circular_rounded,
                  l10n.audioOutputBuffer,
                  info.framesPerBuffer == null
                      ? '—'
                      : '${info.framesPerBuffer}  '
                            '${_latencyText(info.framesPerBuffer, info.sampleRate)}',
                ),
                if (info.devices.isNotEmpty) ...[
                  appleSectionTitle(l10n.audioOutputDevices),
                  for (final device in info.devices)
                    _deviceTile(context, l10n, device),
                ],
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Text(
                  info == null ? l10n.audioOutputUnavailable : l10n.audioOutputNote,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: colorManager.getSpecificTextColor().withAlpha(125),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _routeCard(
    BuildContext context,
    AppLocalizations l10n,
    AudioOutputInfo? info,
  ) {
    final textColor = colorManager.getSpecificTextColor();
    final accent = Theme.of(context).colorScheme.primary;
    final route = info?.route;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent.withAlpha(32), textColor.withAlpha(10)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: textColor.withAlpha(20)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withAlpha(34),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _routeIcon(route?.type),
                color: accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.audioRoute,
                    style: TextStyle(fontSize: 11, color: textColor.withAlpha(135)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    route == null ? l10n.audioRouteOther : _routeLabel(l10n, route.type),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  if (route != null && route.name.trim().isNotEmpty)
                    Text(
                      route.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: textColor.withAlpha(140)),
                    ),
                ],
              ),
            ),
            Text(
              _rateText(info?.sampleRate),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceCard(BuildContext context, AppLocalizations l10n) {
    final textColor = colorManager.getSpecificTextColor();
    final song = currentSongNotifier.value;
    if (song == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Text(
          l10n.audioNoSongPlaying,
          style: TextStyle(fontSize: 13, color: textColor.withAlpha(140)),
        ),
      );
    }
    final format = (song.format ?? '').trim().toUpperCase();
    final sampleRate = song.samplerate;
    final bitrate = song.bitrate;
    final detail = [
      if (format.isNotEmpty) format,
      if (sampleRate != null) _rateText(sampleRate),
      if (bitrate != null && bitrate > 0) '$bitrate kbps',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: CoverArtWidget(size: 54, borderRadius: 9, picture: song.picture),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  getTitle(song),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail.isEmpty ? l10n.audioOutputUnavailable : detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: textColor.withAlpha(145)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailTile(IconData icon, String label, String value) {
    final textColor = colorManager.getSpecificTextColor();
    return ListTile(
      leading: Icon(icon, size: 23, color: colorManager.getSpecificIconColor()),
      title: Text(label),
      trailing: Text(
        '$value  ',
        style: TextStyle(fontSize: 13, color: textColor.withAlpha(180)),
      ),
    );
  }

  Widget _deviceTile(
    BuildContext context,
    AppLocalizations l10n,
    AudioOutputDevice device,
  ) {
    final textColor = colorManager.getSpecificTextColor();
    return ListTile(
      leading: Icon(
        _routeIcon(device.type),
        size: 23,
        color: colorManager.getSpecificIconColor(),
      ),
      title: Text(
        _routeLabel(l10n, device.type),
        style: TextStyle(fontSize: 14, color: textColor),
      ),
      subtitle: device.name.trim().isEmpty
          ? null
          : Text(
              device.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: textColor.withAlpha(130)),
            ),
    );
  }

  static IconData _routeIcon(int? type) {
    switch (type) {
      case 26:
      case 27:
      case 30:
      case 7:
      case 8:
        return Icons.bluetooth_audio_rounded;
      case 11:
      case 12:
      case 22:
        return Icons.usb_rounded;
      case 3:
      case 4:
        return Icons.headphones_rounded;
      case 9:
      case 10:
      case 29:
        return Icons.tv_rounded;
      case 2:
        return Icons.speaker_rounded;
      case 1:
        return Icons.phone_in_talk_rounded;
      case 13:
        return Icons.dock_rounded;
      case 23:
        return Icons.hearing_rounded;
      default:
        return Icons.volume_up_rounded;
    }
  }

  static String _routeLabel(AppLocalizations l10n, int type) {
    switch (type) {
      case 7:
      case 8:
      case 26:
      case 27:
      case 30:
        return l10n.audioRouteBluetooth;
      case 11:
      case 12:
      case 22:
        return l10n.audioRouteUsb;
      case 3:
      case 4:
        return l10n.audioRouteWired;
      case 2:
        return l10n.audioRouteSpeaker;
      case 1:
        return l10n.audioRouteEarpiece;
      case 9:
      case 10:
      case 29:
        return l10n.audioRouteHdmi;
      case 13:
        return l10n.audioRouteDock;
      case 23:
        return l10n.audioRouteHearingAid;
      case 5:
      case 6:
      case 19:
        return l10n.audioRouteLine;
      default:
        return l10n.audioRouteOther;
    }
  }

  static String _rateText(int? rate) {
    if (rate == null || rate <= 0) {
      return '—';
    }
    if (rate % 1000 == 0) {
      return '${rate ~/ 1000} kHz';
    }
    return '${(rate / 1000).toStringAsFixed(1)} kHz';
  }

  static String _latencyText(int? frames, int? rate) {
    if (frames == null || frames <= 0 || rate == null || rate <= 0) {
      return '';
    }
    final ms = frames * 1000 / rate;
    return '· ${ms.toStringAsFixed(1)} ms';
  }
}
