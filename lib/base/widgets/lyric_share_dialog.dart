import 'dart:io';
import 'dart:math' as math;
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
class LyricShareCard extends StatefulWidget {
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
  State<LyricShareCard> createState() => _LyricShareCardState();
}

class _LyricShareCardState extends State<LyricShareCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flow;
  List<Color> _palette = const [];
  String _palettePath = '';

  @override
  void initState() {
    super.initState();
    _flow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
    _loadPalette();
  }

  @override
  void didUpdateWidget(covariant LyricShareCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.picture?.path != widget.picture?.path) {
      _loadPalette();
    }
  }

  Future<void> _loadPalette() async {
    final path = widget.picture?.path ?? '';
    _palettePath = path;
    if (path.isEmpty) {
      if (mounted) {
        setState(() => _palette = const []);
      }
      return;
    }
    final colors = await _CoverPalette.fromPath(path);
    if (!mounted || _palettePath != path) {
      return;
    }
    setState(() => _palette = colors);
  }

  List<Color> _colorsFor(Color accent) {
    final colors = [..._palette];
    // A cover that is almost entirely paper/black has no useful palette; a
    // generated complementary set is livelier than five shades of grey.
    final vivid = colors.any((color) {
      final hsv = HSVColor.fromColor(color);
      return hsv.saturation >= 0.22 && hsv.value >= 0.18;
    });
    if (!vivid) {
      colors.clear();
    }
    if (colors.isEmpty) {
      colors.add(accent);
    }
    for (final fallback in _fallbackPalette(accent)) {
      if (colors.length >= 5) {
        break;
      }
      final distinct = colors.every((color) {
        final a = HSVColor.fromColor(color);
        final b = HSVColor.fromColor(fallback);
        return (a.hue - b.hue).abs() > 24;
      });
      if (distinct) {
        colors.add(fallback);
      }
    }
    return colors;
  }

  List<Color> _fallbackPalette(Color accent) {
    final hsv = HSVColor.fromColor(accent);
    final saturation = hsv.saturation.clamp(0.42, 0.84).toDouble();
    final value = hsv.value.clamp(0.52, 0.92).toDouble();
    Color at(double hue, double sat, double val) {
      return HSVColor.fromAHSV(1, hue % 360, sat, val).toColor();
    }

    return [
      at(hsv.hue + 42, saturation, value),
      at(hsv.hue + 186, saturation * 0.82, value * 0.88),
      at(hsv.hue + 308, saturation * 0.68, value),
    ];
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final artist = widget.artist;
    final lyric = widget.lyric;
    final translation = widget.translation;
    final picture = widget.picture;
    final background = shareCardBackgroundNotifier.value;
    final textSize = shareCardTextSizeNotifier.value;
    final coverSize = shareCardCoverSizeNotifier.value;
    final showTranslation = shareCardShowTranslationNotifier.value;
    final topText = shareCardTopTextNotifier.value.trim().isEmpty
        ? 'LAIN · 临音'
        : shareCardTopTextNotifier.value.trim();
    final coverColor = picture?.color;
    final accent = (coverColor != null && coverColor != Colors.grey)
        ? coverColor
        : (currentCoverArtColor == Colors.grey
              ? const Color(0xFF7C5CFF)
              : currentCoverArtColor);
    final palette = _colorsFor(accent);

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
            Color.lerp(palette.first, Colors.black, 0.72)!,
            const Color(0xFF0B0B10),
            Color.lerp(palette.last, Colors.black, 0.58)!,
          ],
        ),
      ),
      child: Stack(
        children: [
          _background(background, accent),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _flow,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _FlowPainter(
                      phase: _flow.value,
                      colors: palette,
                      strength: switch (background) {
                        ShareCardBackground.aurora => 1.0,
                        ShareCardBackground.blur => 0.82,
                        ShareCardBackground.crop => 0.50,
                        ShareCardBackground.pixelate => 0.58,
                        ShareCardBackground.halftone => 0.52,
                      },
                    ),
                  );
                },
              ),
            ),
          ),
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
    final file = File(widget.picture?.path ?? '');
    final hasImage = widget.picture != null && file.existsSync();
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

/// A moving light band over the card. A static gradient reads as a dull
/// vignette; an actual flow needs a narrow, blurred specular streak whose
/// position changes every frame, plus a weaker coloured echo behind it. The
/// overlay is deliberately subtle so the lyric stays readable at thumbnail
/// size.
/// A slow liquid mesh built from the cover's own dominant colours. Each blob
/// is a huge, blurred radial gradient; because they overlap and move on
/// different orbits, adjacent colours blend into new ones the way a stirred
/// gradient does. A broad diagonal sheen crosses the card without producing a
/// hard oval or band.
class _FlowPainter extends CustomPainter {
  final double phase;
  final List<Color> colors;
  final double strength;

  const _FlowPainter({
    required this.phase,
    required this.colors,
    required this.strength,
  });

  void _blob(
    Canvas canvas,
    Size size,
    Offset center,
    double radius,
    Color color,
    double alpha,
  ) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..blendMode = BlendMode.screen
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 14)
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: alpha * 0.42),
          color.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.42, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = phase * math.pi * 2;
    final palette = colors.isEmpty ? const [Colors.white] : colors;

    for (var i = 0; i < palette.length; i++) {
      final color = Color.lerp(palette[i], Colors.white, 0.16)!;
      final drift = t * 0.72 + i * 2.399;
      final center = Offset(
        size.width * (0.50 + 0.34 * math.sin(drift * 0.93 + i * 1.063)),
        size.height * (0.48 + 0.28 * math.cos(drift * 0.71 + i * 1.051)),
      );
      final radius =
          size.width * (0.38 + 0.09 * math.sin(drift * 0.57 + i * 1.037));
      final alpha = (0.20 - i * 0.016).clamp(0.08, 0.22).toDouble() * strength;
      _blob(canvas, size, center, radius, color, alpha);
    }

    // The moving specular wash. It covers the whole card, so the top edge does
    // not show the rounded ends of a rotated oval.
    final wash = LinearGradient(
      begin: Alignment(-1.45 + 2.9 * phase, -1),
      end: Alignment(-0.45 + 2.9 * phase, 1),
      colors: [
        Colors.transparent,
        Colors.white.withValues(alpha: 0.07 * strength),
        Color.lerp(
          palette.first,
          Colors.white,
          0.45,
        )!.withValues(alpha: 0.06 * strength),
        Colors.transparent,
      ],
      stops: const [0.0, 0.43, 0.58, 1.0],
    ).createShader(Offset.zero & size);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = wash,
    );

    final echoPhase = (phase + 0.47) % 1.0;
    final echo = LinearGradient(
      begin: Alignment(1.35 - 2.8 * echoPhase, 1),
      end: Alignment(0.35 - 2.8 * echoPhase, -1),
      colors: [
        Colors.transparent,
        Color.lerp(
          palette.last,
          Colors.white,
          0.30,
        )!.withValues(alpha: 0.055 * strength),
        Colors.transparent,
      ],
      stops: const [0.0, 0.52, 1.0],
    ).createShader(Offset.zero & size);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = echo,
    );
  }

  @override
  bool shouldRepaint(covariant _FlowPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.strength != strength ||
      oldDelegate.colors != colors;
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
        paint.color = Color.lerp(
          accent,
          Colors.white,
          0.35,
        )!.withValues(alpha: 0.10 + distance * 0.20);
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

class _CoverPalette {
  static Future<List<Color>> fromPath(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      return const [];
    }
    ui.Codec? codec;
    ui.Image? image;
    try {
      final bytes = await file.readAsBytes();
      codec = await ui.instantiateImageCodec(bytes, targetWidth: 56);
      final frame = await codec.getNextFrame();
      image = frame.image;
      final width = image.width;
      final height = image.height;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) {
        return const [];
      }
      final pixels = data.buffer.asUint8List();
      final buckets = <int, _ColorSample>{};
      for (var y = 0; y < height; y += 2) {
        for (var x = 0; x < width; x += 2) {
          final offset = (y * width + x) * 4;
          final alpha = pixels[offset + 3];
          if (alpha < 150) {
            continue;
          }
          final r = pixels[offset];
          final g = pixels[offset + 1];
          final b = pixels[offset + 2];
          final key = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
          final sample = buckets.putIfAbsent(key, _ColorSample.new);
          sample.count++;
          sample.r += r;
          sample.g += g;
          sample.b += b;
        }
      }
      final candidates = <_PaletteColor>[];
      for (final sample in buckets.values) {
        final count = sample.count;
        final color = Color.fromARGB(
          255,
          sample.r ~/ count,
          sample.g ~/ count,
          sample.b ~/ count,
        );
        final hsv = HSVColor.fromColor(color);
        // Paper white and pure black are background, not part of the palette;
        // they would only wash the flow out.
        if ((hsv.value > 0.96 && hsv.saturation < 0.08) || hsv.value < 0.08) {
          continue;
        }
        final score =
            count * (0.22 + hsv.saturation * 1.6) * (0.45 + hsv.value * 0.75);
        candidates.add(_PaletteColor(color, score, hsv.hue));
      }
      candidates.sort((a, b) => b.score.compareTo(a.score));

      final picked = <Color>[];
      for (final candidate in candidates) {
        if (picked.length >= 5) {
          break;
        }
        final distinct = picked.every((color) {
          final hsv = HSVColor.fromColor(color);
          var distance = (hsv.hue - candidate.hue).abs();
          if (distance > 180) {
            distance = 360 - distance;
          }
          return distance > 22 || hsv.saturation < 0.12;
        });
        if (distinct) {
          picked.add(candidate.color);
        }
      }
      return picked;
    } catch (_) {
      return const [];
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }
}

class _ColorSample {
  int count = 0;
  int r = 0;
  int g = 0;
  int b = 0;
}

class _PaletteColor {
  final Color color;
  final double score;
  final double hue;

  const _PaletteColor(this.color, this.score, this.hue);
}
