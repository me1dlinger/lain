import 'dart:async';
import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:lain/base/audio_handler.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/data/lyrics_display_settings.dart';
import 'package:lain/base/services/lyric.dart';
import 'package:lain/base/services/romaji.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:smooth_corner/smooth_corner.dart';

export 'package:lain/base/data/lyrics_display_settings.dart';

final updateLyricsNotifier = ValueNotifier(0);

class LyricsListView extends StatefulWidget {
  final bool expanded;
  final List<LyricLine> lines;
  final bool isKaraoke;
  const LyricsListView({
    super.key,
    required this.expanded,
    required this.lines,
    required this.isKaraoke,
  });

  @override
  State<LyricsListView> createState() => LyricsListViewState();
}

class LyricsListViewState extends State<LyricsListView>
    with WidgetsBindingObserver {
  final ItemScrollController itemScrollController = ItemScrollController();
  bool userDragging = false;

  List<LyricLine> lines = [];
  bool jump = true;
  Timer? timer;

  double? _lastParentHeight;
  bool _initialScrollDone = false;

  /// Line index -> romaji, only for lines that could be romanised. Null while
  /// romaji is off, not generated yet, or when the song has no Japanese text.
  Map<int, String>? _romajiLines;
  int _romajiGeneration = 0;

  void scroll2CurrentIndex() async {
    final currentIndex = currentLyricsIndexNotifier.value;
    if (userDragging || loadingSong) {
      return;
    }
    if (currentIndex < 0 || currentIndex >= lines.length) {
      return;
    }
    if (!itemScrollController.isAttached) {
      return;
    }

    final alignment = widget.expanded ? 0.25 : 0.4;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (jump || reduceMotion) {
      jump = false;
      itemScrollController.jumpTo(
        index: currentIndex + 1,
        alignment: alignment,
      );
    } else {
      itemScrollController.scrollTo(
        index: currentIndex + 1,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: alignment,
      );
    }
  }

  void _onRomajiSettingChanged() {
    _loadRomaji();
  }

  void _loadRomaji() {
    final generation = ++_romajiGeneration;
    if (!lyricsRomajiNotifier.value) {
      if (_romajiLines != null) {
        setState(() => _romajiLines = null);
      }
      return;
    }

    final texts = [for (final line in lines) line.text];
    unawaited(
      romajiService.convertLines(texts).then((result) {
        if (!mounted || generation != _romajiGeneration) {
          return;
        }
        final converted = <int, String>{};
        for (var i = 0; i < result.length; i++) {
          final value = result[i];
          if (value != null && value.trim().isNotEmpty) {
            converted[i] = value.trim();
          }
        }
        setState(() {
          _romajiLines = converted.isEmpty ? null : converted;
        });
      }),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    lines = widget.lines;
    currentLyricsIndexNotifier.addListener(scroll2CurrentIndex);
    lyricsRomajiNotifier.addListener(_onRomajiSettingChanged);
    if (lyricsRomajiNotifier.value) {
      _loadRomaji();
    }
  }

  @override
  void didUpdateWidget(covariant LyricsListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.lines, widget.lines) ||
        oldWidget.expanded != widget.expanded) {
      lines = widget.lines;
      _initialScrollDone = false;
      jump = true;
      if (lyricsRomajiNotifier.value) {
        _loadRomaji();
      } else {
        _romajiLines = null;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    currentLyricsIndexNotifier.removeListener(scroll2CurrentIndex);
    lyricsRomajiNotifier.removeListener(_onRomajiSettingChanged);
    _romajiGeneration++;

    timer?.cancel();
    timer = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        jump = true;
        scroll2CurrentIndex();
        currentLyricsIndexNotifier.addListener(scroll2CurrentIndex);
        break;
      case AppLifecycleState.paused:
        currentLyricsIndexNotifier.removeListener(scroll2CurrentIndex);
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final parentHeight = constraints.maxHeight; // height of the parent
        final heightChanged =
            _lastParentHeight != null &&
            (parentHeight - _lastParentHeight!).abs() > 0.5;
        _lastParentHeight = parentHeight;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          // A resize (rotation, window snap) or the first layout of a song
          // that is already playing needs an immediate alignment; every
          // ordinary line change animates instead.
          if (heightChanged ||
              (!_initialScrollDone && currentLyricsIndexNotifier.value >= 0)) {
            _initialScrollDone = true;
            jump = true;
            scroll2CurrentIndex();
          }
        });

        return NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (notification.direction != ScrollDirection.idle) {
              userDragging = true;
              timer?.cancel();
              timer = null;
            } else {
              timer ??= Timer(const Duration(milliseconds: 2000), () {
                userDragging = false;
                timer = null;
              });
            }
            return false;
          },
          child: ScrollablePositionedList.builder(
            physics: ClampingScrollPhysics(),
            itemCount: lines.length + 2,
            itemScrollController: itemScrollController,
            itemBuilder: (context, index) {
              if (index == 0) {
                return SizedBox(
                  height: widget.expanded
                      ? parentHeight * 0.25
                      : parentHeight * 0.4,
                );
              } else if (index == lines.length + 1) {
                return SizedBox(
                  height: widget.expanded
                      ? parentHeight * 0.65
                      : parentHeight * 0.45,
                );
              }
              return LyricLineWidget(
                index: index - 1,
                line: lines[index - 1],
                expanded: widget.expanded,
                isKaraoke: widget.isKaraoke,
                romaji: _romajiLines?[index - 1],
              );
            },
          ),
        );
      },
    );
  }
}

/// Each lyric line listens to currentIndexNotifier
class LyricLineWidget extends StatelessWidget {
  final int index;
  final LyricLine line;
  final bool expanded;
  final bool isKaraoke;
  final String? romaji;

  const LyricLineWidget({
    super.key,
    required this.line,
    required this.index,
    required this.expanded,
    required this.isKaraoke,
    this.romaji,
  });

  @override
  Widget build(BuildContext context) {
    double paddingHeight = 15;
    double fontSizeOffset = 0;
    if (!isMobile) {
      final pageHeight = MediaQuery.heightOf(context);
      final pageWidth = MediaQuery.widthOf(context);
      paddingHeight += (pageHeight - 700) * 0.025;
      fontSizeOffset = min(
        (pageHeight - 700) * 0.075,
        (pageWidth - 1050) * 0.025,
      ).clamp(0, double.maxFinite);
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: () {
          // add 1ms offset to avoid seeking to last lyric
          audioHandler.seek(line.start + Duration(milliseconds: 1));
        },
        customBorder: SmoothRectangleBorder(
          smoothness: 1,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: expanded
              ? EdgeInsets.fromLTRB(25, paddingHeight, 30, paddingHeight)
              : const EdgeInsets.symmetric(vertical: 5, horizontal: 15),
          child: ListenableBuilder(
            listenable: Listenable.merge([
              lyricsFontSizeOffsetNotifier,
              lyricsFontWeightNotifier,
              lyricsTextAlignNotifier,
              fontFamilyNotifier,
              currentLyricsIndexNotifier,
            ]),
            builder: (context, _) {
              final isCurrent = currentLyricsIndexNotifier.value == index;
              final textAlign = lyricsTextAlignFor(
                lyricsTextAlignNotifier.value,
                expanded: expanded,
              );
              final centered = textAlign == TextAlign.center;

              double fontSize = 16 + lyricsFontSizeOffsetNotifier.value;

              if (expanded) {
                fontSize += isMobile ? 16 : 8;
              }

              fontSize += fontSizeOffset;

              final textColor = viewModeNotifier.value == .mini
                  ? miniViewForegroundColor.value
                  : lyricsPageForegroundColor.value;
              final fontFamily = fontFamilyNotifier.value;

              return AnimatedScale(
                scale: isCurrent ? 1.05 : 0.95,
                duration: Duration(milliseconds: 300),
                alignment: centered ? .center : .centerLeft,
                child: Column(
                  crossAxisAlignment: lyricsCrossAxisAlignmentFor(
                    lyricsTextAlignNotifier.value,
                    expanded: expanded,
                  ),
                  children: [
                    if (isCurrent && isKaraoke)
                      ValueListenableBuilder(
                        valueListenable: updateLyricsNotifier,
                        builder: (context, value, child) {
                          return KaraokeText(
                            line: line,
                            position: audioHandler.getPosition(),
                            fontSize: fontSize,
                            expanded: expanded,
                            textAlign: textAlign,
                          );
                        },
                      )
                    else
                      Text(
                        line.text,
                        textAlign: textAlign,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: lyricsFontWeightNotifier.value,
                          fontFamily: fontFamily,
                          color: isCurrent
                              ? textColor
                              : textColor.withAlpha(128),
                        ),
                      ),
                    if (romaji != null)
                      Text(
                        romaji!,
                        textAlign: textAlign,
                        style: TextStyle(
                          fontSize: fontSize - (expanded ? 8 : 4),
                          fontWeight: FontWeight.normal,
                          fontFamily: fontFamily,
                          height: 1.25,
                          color: textColor.withAlpha(isCurrent ? 175 : 110),
                        ),
                      ),
                    for (final translate in line.translates)
                      Text(
                        translate,
                        textAlign: textAlign,
                        style: TextStyle(
                          fontSize: fontSize - (expanded ? 8 : 4),
                          fontWeight: lyricsFontWeightNotifier.value,
                          fontFamily: fontFamily,
                          color: textColor.withAlpha(128),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class KaraokeText extends StatefulWidget {
  final LyricLine line;
  final Duration position;
  final double fontSize;
  final bool expanded;
  final TextAlign textAlign;
  final bool isDesktopLyrics;

  const KaraokeText({
    super.key,
    required this.line,
    required this.position,
    required this.fontSize,
    required this.expanded,
    this.textAlign = TextAlign.left,
    this.isDesktopLyrics = false,
  });

  @override
  State<KaraokeText> createState() => KaraokeTextState();
}

class KaraokeTextState extends State<KaraokeText>
    with SingleTickerProviderStateMixin {
  late final Ticker ticker;
  late final ValueNotifier<Duration> positionNotifier;

  Duration displayPosition = Duration.zero;
  DateTime lastSyncTime = DateTime.now();

  late Color textColor;

  void _playStateListener() {
    if (isPlayingNotifier.value) {
      lastSyncTime = DateTime.now();
      if (!ticker.isActive) {
        ticker.start();
      }
    } else {
      if (ticker.isActive) {
        ticker.stop();
      }
    }
  }

  @override
  void initState() {
    super.initState();

    displayPosition = widget.position;
    positionNotifier = ValueNotifier(displayPosition);
    ticker = createTicker((_) {
      final now = DateTime.now();
      final elapsed = now.difference(lastSyncTime);
      lastSyncTime = now;
      displayPosition += elapsed;
      positionNotifier.value = displayPosition;
    });

    isPlayingNotifier.addListener(_playStateListener);

    if (isPlayingNotifier.value) {
      ticker.start();
    }

    textColor = widget.isDesktopLyrics
        ? Colors.white
        : viewModeNotifier.value == .mini
        ? miniViewHighlightTextColor.value
        : lyricsPageHighlightTextColor.value;
  }

  @override
  void didUpdateWidget(covariant KaraokeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A seek or a lyric reload rebuilds the parent with the real position;
    // keep the ticker's clock in sync with it so the highlight does not lag.
    if (!identical(oldWidget.line, widget.line) ||
        oldWidget.position != widget.position) {
      displayPosition = widget.position;
      lastSyncTime = DateTime.now();
      positionNotifier.value = displayPosition;
    }
  }

  @override
  void dispose() {
    isPlayingNotifier.removeListener(_playStateListener);
    ticker.dispose();
    positionNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          for (final token in widget.line.tokens)
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: _KaraokeTokenText(
                token: token,
                position: positionNotifier,
                fontSize: widget.fontSize,
                textColor: textColor,
                isDesktopLyrics: widget.isDesktopLyrics,
              ),
            ),
        ],
      ),
      textAlign: widget.textAlign,
    );
  }
}

/// One timed word. It owns its progress so a ticker frame only rebuilds the
/// word whose fill actually moved, not the whole line or page.
class _KaraokeTokenText extends StatefulWidget {
  final LyricToken token;
  final ValueListenable<Duration> position;
  final double fontSize;
  final Color textColor;
  final bool isDesktopLyrics;

  const _KaraokeTokenText({
    required this.token,
    required this.position,
    required this.fontSize,
    required this.textColor,
    required this.isDesktopLyrics,
  });

  @override
  State<_KaraokeTokenText> createState() => _KaraokeTokenTextState();
}

class _KaraokeTokenTextState extends State<_KaraokeTokenText> {
  late double progress;

  @override
  void initState() {
    super.initState();
    progress = _progressAt(widget.position.value);
    widget.position.addListener(_onPosition);
  }

  @override
  void didUpdateWidget(covariant _KaraokeTokenText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.position, widget.position)) {
      oldWidget.position.removeListener(_onPosition);
      widget.position.addListener(_onPosition);
    }
    final next = _progressAt(widget.position.value);
    if ((next - progress).abs() > 0.001) {
      progress = next;
    }
  }

  @override
  void dispose() {
    widget.position.removeListener(_onPosition);
    super.dispose();
  }

  void _onPosition() {
    final next = _progressAt(widget.position.value);
    if ((next - progress).abs() < 0.004) {
      return;
    }
    setState(() => progress = next);
  }

  double _progressAt(Duration rawPosition) {
    final position =
        rawPosition +
        Duration(
          milliseconds: currentSongNotifier.value?.lyricsTimeOffset ?? 0,
        );
    final start = widget.token.start;
    if (position <= start) {
      return 0;
    }
    final end = widget.token.end;
    if (end == null || end <= start) {
      // No end time: a timed word is complete once its start has passed.
      return 1;
    }
    if (position >= end) {
      return 1;
    }
    return (position - start).inMicroseconds / (end - start).inMicroseconds;
  }

  @override
  Widget build(BuildContext context) {
    final token = widget.token;
    final fontFamily = fontFamilyNotifier.value;

    return Stack(
      children: [
        Text(
          token.text,
          style: TextStyle(
            fontSize: widget.fontSize,
            fontFamily: fontFamily,
            color: Colors.transparent,
            shadows: widget.isDesktopLyrics
                ? [
                    Shadow(
                      offset: Offset(2, 2),
                      blurRadius: isMobile ? 5 : 1,
                      color: isMobile ? Colors.black87 : Colors.black54,
                    ),
                  ]
                : null,
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            final p = progress.clamp(0.0, 1.0);
            return LinearGradient(
              colors: [widget.textColor, widget.textColor.withAlpha(128)],
              stops: [p, p],
            ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height));
          },
          child: Text(
            token.text,
            style: TextStyle(
              fontSize: widget.fontSize,
              fontWeight: lyricsFontWeightNotifier.value,
              fontFamily: fontFamily,
              color: widget.textColor,
            ),
          ),
        ),
      ],
    );
  }
}
