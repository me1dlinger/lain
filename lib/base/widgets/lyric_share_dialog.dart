import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/data/share_card_settings.dart';
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
  String? translation,
}) {
  return showAnimationDialog<void>(
    context: context,
    child: LyricShareDialog(song: song, lyric: lyric, translation: translation),
  );
}

class LyricShareDialog extends StatefulWidget {
  final MyAudioMetadata song;
  final String? lyric;
  final String? translation;

  const LyricShareDialog({
    super.key,
    required this.song,
    this.lyric,
    this.translation,
  });

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
    return text.isEmpty ? getTitle(widget.song) : text;
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
                child: LyricShareCard(
                  title: getTitle(widget.song),
                  artist: getArtist(widget.song),
                  album: getAlbum(widget.song),
                  lyric: _lyric,
                  translation: widget.translation ?? '',
                  picture: widget.song.picture,
                ),
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

/// The card itself. The share-card settings decide the background,
/// text size, cover size and whether the translation is shown.
class LyricShareCard extends StatelessWidget {
  final String title;
  final String artist;
  final String album;
  final String lyric;
  final String translation;
  final MyPicture? picture;

  const LyricShareCard({
    super.key,
    required this.title,
    required this.artist,
    required this.album,
    required this.lyric,
    required this.picture,
    this.translation = '',
  });

  @override
  Widget build(BuildContext context) {
    final background = shareCardBackgroundNotifier.value;
    final textSize = shareCardTextSizeNotifier.value;
    final coverSize = shareCardCoverSizeNotifier.value;
    final showTranslation = shareCardShowTranslationNotifier.value;
    final topText = shareCardTopTextNotifier.value.trim().isEmpty
        ? 'LAIN · 临音'
        : shareCardTopTextNotifier.value.trim();
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
          _background(background, accent),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CoverArtWidget(
                      size: coverSize,
                      picture: picture,
                      useResize: false,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    title,
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
                    artist,
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
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: textSize,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (showTranslation && translation.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      translation,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _background(ShareCardBackground mode, Color accent) {
    final file = File(picture?.path ?? '');
    final hasImage = picture != null && file.existsSync();
    final cover = hasImage
        ? Image.file(
            file,
            fit: BoxFit.cover,
            width: 280,
            height: 498,
            gaplessPlayback: true,
          )
        : const SizedBox.shrink();

    Widget content;
    switch (mode) {
      case ShareCardBackground.crop:
        content = Stack(
          fit: StackFit.expand,
          children: [
            cover,
            Container(color: Colors.black.withValues(alpha: 0.52)),
          ],
        );
      case ShareCardBackground.blur:
        content = Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Opacity(opacity: 0.55, child: cover),
            ),
            Container(color: Colors.black.withValues(alpha: 0.38)),
          ],
        );
      case ShareCardBackground.aurora:
        content = Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Opacity(opacity: 0.45, child: cover),
            ),
            Container(color: Colors.black.withValues(alpha: 0.30)),
            Positioned.fill(
              child: CustomPaint(painter: _AuroraPainter(accent: accent)),
            ),
          ],
        );
      case ShareCardBackground.pixelate:
        content = Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Opacity(opacity: 0.35, child: cover),
            ),
            Positioned.fill(
              child: CustomPaint(painter: _MosaicPainter(accent: accent)),
            ),
          ],
        );
      case ShareCardBackground.halftone:
        content = Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Opacity(opacity: 0.40, child: cover),
            ),
            Positioned.fill(
              child: CustomPaint(painter: _HalftonePainter(accent: accent)),
            ),
          ],
        );
    }
    return Positioned.fill(child: content);
  }
}

class _AuroraPainter extends CustomPainter {
  final Color accent;

  const _AuroraPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.12),
          Color.lerp(accent, Colors.white, 0.25)!.withValues(alpha: 0.20),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.30, 0.55, 1.0],
      ).createShader(Offset.zero & size);
    canvas.save();
    canvas.rotate(-0.38);
    canvas.drawOval(
      Rect.fromLTWH(
        -size.width * 0.25,
        size.height * 0.16,
        size.width * 1.5,
        size.height * 0.22,
      ),
      paint,
    );
    canvas.restore();
    canvas.save();
    canvas.rotate(0.28);
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * 0.10,
        size.height * 0.054,
        size.width * 1.2,
        size.height * 0.12,
      ),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

class _MosaicPainter extends CustomPainter {
  final Color accent;

  const _MosaicPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    const columns = 18;
    const rows = 32;
    final cellW = size.width / columns;
    final cellH = size.height / rows;
    for (var x = 0; x < columns; x++) {
      for (var y = 0; y < rows; y++) {
        final alpha = 10 + ((x * 7 + y * 5) % 26);
        final color = (x + y) % 3 == 0 ? accent : Colors.black;
        canvas.drawRect(
          Rect.fromLTWH(x * cellW, y * cellH, cellW + 0.6, cellH + 0.6),
          Paint()..color = color.withValues(alpha: alpha / 255),
        );
      }
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );
  }

  @override
  bool shouldRepaint(covariant _MosaicPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

class _HalftonePainter extends CustomPainter {
  final Color accent;

  const _HalftonePainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 9.0;
    final paint = Paint();
    for (var y = gap / 2; y < size.height; y += gap) {
      for (var x = gap / 2; x < size.width; x += gap) {
        final distance = (x / size.width + y / size.height) / 2;
        paint.color = Color.lerp(accent, Colors.white, 0.35)!.withValues(
          alpha: 0.10 + distance * 0.20,
        );
        canvas.drawCircle(Offset(x, y), 1.5 + distance * 1.8, paint);
      }
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
  }

  @override
  bool shouldRepaint(covariant _HalftonePainter oldDelegate) =>
      oldDelegate.accent != accent;
}
