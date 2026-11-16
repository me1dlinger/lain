import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/services/picture_service.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:lain/base/widgets/apple_form.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

/// A shareable 9:16 card with the current lyric line, the song and its cover.
Future<void> showLyricShareDialog(
  BuildContext context,
  MyAudioMetadata song, {
  String? lyric,
}) {
  return showAnimationDialog<void>(
    context: context,
    child: LyricShareDialog(song: song, lyric: lyric),
  );
}

class LyricShareDialog extends StatefulWidget {
  final MyAudioMetadata song;
  final String? lyric;

  const LyricShareDialog({super.key, required this.song, this.lyric});

  @override
  State<LyricShareDialog> createState() => _LyricShareDialogState();
}

class _LyricShareDialogState extends State<LyricShareDialog> {
  final _cardKey = GlobalKey();
  bool _ready = false;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _prepareCover();
  }

  Future<void> _prepareCover() async {
    try {
      await loadPictureSafe(widget.song.picture, priority: true);
    } catch (_) {}
    if (mounted) {
      setState(() => _ready = true);
    }
  }

  String get _lyric {
    final text = widget.lyric?.trim() ?? '';
    if (text.isNotEmpty) {
      return text;
    }
    return getTitle(widget.song);
  }

  Future<void> _share() async {
    if (_sharing || !_ready) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() => _sharing = true);
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        return;
      }
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        return;
      }
      final file = File(
        '${appSupportDir.path}/share/lyric_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);

      if (Platform.isAndroid) {
        final shared = await const MethodChannel(
          'com.meidlinger.lain.media',
        ).invokeMethod<bool>('shareFile', {'path': file.path});
        if (shared != true && mounted) {
          showCenterMessage(l10n.savedTo(file.path));
        }
      } else if (mounted) {
        showCenterMessage(l10n.savedTo(file.path));
      }
    } catch (e) {
      if (mounted) {
        showCenterMessage('$e');
      }
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();
    return SizedBox(
      width: 300,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_ready)
              const SizedBox(
                height: 498,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              RepaintBoundary(
                key: _cardKey,
                child: _ShareCard(song: widget.song, lyric: _lyric),
              ),
            const SizedBox(height: 12),
            appleFilledButton(
              l10n.share,
              _ready && !_sharing ? _share : null,
              busy: _sharing,
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                l10n.cancel,
                style: TextStyle(color: textColor.withAlpha(170)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  final MyAudioMetadata song;
  final String lyric;

  const _ShareCard({required this.song, required this.lyric});

  @override
  Widget build(BuildContext context) {
    final accent = currentCoverArtColor == Colors.grey
        ? const Color(0xFF7C5CFF)
        : currentCoverArtColor;
    return Container(
      width: 280,
      height: 498,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(accent, Colors.black, 0.72)!,
            const Color(0xFF101014),
            Color.lerp(accent, Colors.black, 0.55)!,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -40,
            top: 60,
            right: -40,
            child: Opacity(
              opacity: 0.18,
              child: CoverArtWidget(
                size: 360,
                picture: song.picture,
                useResize: false,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'L A I N',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    letterSpacing: 5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CoverArtWidget(
                      size: 164,
                      picture: song.picture,
                      useResize: false,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    getTitle(song),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    getArtist(song),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Center(
                  child: Text(
                    '“$lyric”',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Center(
                  child: Text(
                    'Lain · 临音',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                      letterSpacing: 1.2,
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
}
