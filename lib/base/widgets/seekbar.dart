import 'dart:async';

import 'package:flutter/scheduler.dart' show Ticker;

import 'package:material_ui/material_ui.dart';
import 'package:lain/base/audio_handler.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/utils/common_utils.dart';
import 'package:lain/base/utils/media_query.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:lain/base/widgets/full_width_track_shape.dart';
import 'package:smooth_corner/smooth_corner.dart';

class SeekBar extends StatefulWidget {
  final Color? color;
  final bool isMiniMode;
  final double widgetHeight;
  final double seekBarHeight;

  const SeekBar({
    super.key,
    this.color,
    this.isMiniMode = false,
    required this.widgetHeight,
    required this.seekBarHeight,
  });
  @override
  State<SeekBar> createState() => SeekBarState();
}

class SeekBarState extends State<SeekBar>
    with SingleTickerProviderStateMixin {
  double? dragValue;
  bool isDragging = false; // track if user is touching the thumb
  double horizontalPadding = 0;
  final trackKey = GlobalKey();

  /// The position the bar shows. It is extrapolated between the player's own
  /// position events, so the bar moves every frame instead of stepping.
  final displayPosition = ValueNotifier<Duration>(Duration.zero);

  late final Ticker _ticker;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  Duration _streamDuration = Duration.zero;
  Duration _basePosition = Duration.zero;
  DateTime _baseAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    displayPosition.value = audioHandler.getPosition();
    _basePosition = displayPosition.value;
    _positionSub = audioHandler.getPositionStream().listen(_onPosition);
    _durationSub = audioHandler.getDurationStream().listen((duration) {
      if (mounted) {
        setState(() => _streamDuration = duration);
      }
    });
    isPlayingNotifier.addListener(_onPlayingChanged);
    _ticker = createTicker(_tick);
    if (isPlayingNotifier.value) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    isPlayingNotifier.removeListener(_onPlayingChanged);
    _ticker.dispose();
    _positionSub?.cancel();
    _durationSub?.cancel();
    displayPosition.dispose();
    super.dispose();
  }

  void _onPlayingChanged() {
    if (isPlayingNotifier.value) {
      _basePosition = audioHandler.getPosition();
      _baseAt = DateTime.now();
      if (!_ticker.isActive) {
        _ticker.start();
      }
    } else {
      _ticker.stop();
      displayPosition.value = audioHandler.getPosition();
    }
  }

  void _onPosition(Duration position) {
    _basePosition = position;
    _baseAt = DateTime.now();
    // A jump that is not the normal passage of time (a seek, a switch, a
    // resume) is shown at once; a normal tick waits for the next frame.
    if (!isPlayingNotifier.value ||
        isDragging ||
        (displayPosition.value - position).abs() > const Duration(seconds: 1)) {
      displayPosition.value = position;
    }
  }

  void _tick(Duration _) {
    if (!mounted) {
      return;
    }
    var shown = _basePosition;
    if (isPlayingNotifier.value && !isDragging) {
      final elapsed = DateTime.now().difference(_baseAt);
      // The stream reports often; only bridge a plausible gap, never a stall,
      // pause or seek.
      if (elapsed < const Duration(seconds: 2)) {
        shown += elapsed;
      }
    }
    final duration = _effectiveDuration();
    if (duration > Duration.zero && shown > duration) {
      shown = duration;
    }
    if ((shown - displayPosition.value).abs() >=
        const Duration(milliseconds: 30)) {
      displayPosition.value = shown;
    }
  }

  Duration _effectiveDuration() {
    var duration = _streamDuration;
    if (duration <= Duration.zero) {
      duration = getDuration(currentSongNotifier.value);
    }
    if (duration <= Duration.zero) {
      duration = audioHandler.getCurrentDuration();
    }
    return duration;
  }

  @override
  Widget build(BuildContext context) {
    horizontalPadding = 0;
    if (!isTooNarrow(context) && !widget.isMiniMode) {
      horizontalPadding = 45;
    }

    return ValueListenableBuilder<Duration>(
      valueListenable: displayPosition,
      builder: (context, displayed, child) {
        final duration = _effectiveDuration();
        final durationMs = duration.inMilliseconds.toDouble();
        double sliderValue =
            dragValue ?? displayed.inMilliseconds.toDouble();
        if (playQueue.isEmpty) {
          sliderValue = 0;
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              height: widget.widgetHeight,
              key: trackKey,
              child: Stack(
                alignment: Alignment.centerLeft,
                clipBehavior: Clip.none,
                children: [
                  // Duration labels
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: isMobile ? 0 : 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatDuration(
                            Duration(milliseconds: sliderValue.toInt()),
                          ),
                          style: TextStyle(
                            color: widget.color,
                            fontSize: isMobile
                                ? null
                                : widget.isMiniMode
                                ? 10.5
                                : 12.5,
                          ),
                        ),
                        Text(
                          formatDuration(duration),
                          style: TextStyle(
                            color: widget.color,
                            fontSize: isMobile
                                ? null
                                : widget.isMiniMode
                                ? 10.5
                                : 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Slider visuals
                  SizedBox(
                    height: widget.seekBarHeight,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        thumbColor: widget.color ?? seekBarColor.value,
                        trackHeight: isDragging ? 4 : 2,
                        trackShape: const FullWidthTrackShape(),
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 0,
                        ),
                        overlayShape: SliderComponentShape.noOverlay,
                        activeTrackColor:
                            widget.color ?? seekBarColor.value,
                        inactiveTrackColor: Colors.black12,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        child: ExcludeFocus(
                          child: Slider(
                            min: 0.0,
                            max: durationMs <= 0 ? 1 : durationMs,
                            value: sliderValue.clamp(
                              0.0,
                              durationMs <= 0 ? 1 : durationMs,
                            ),
                            onChanged: (value) {},
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Full-track GestureDetector to capture touches anywhere on the track
                  Positioned.fill(
                    top: (widget.widgetHeight - widget.seekBarHeight) / 2,
                    bottom: (widget.widgetHeight - widget.seekBarHeight) / 2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onVerticalDragStart: (_) {
                        setState(() => isDragging = false);
                      },
                      onTapDown: (_) {
                        if (currentSongNotifier.value == null) {
                          return;
                        }
                        setState(() => isDragging = true);
                      },
                      onHorizontalDragUpdate: (details) {
                        if (currentSongNotifier.value == null) {
                          return;
                        }
                        seekByTouch(
                          details.localPosition.dx,
                          context,
                          durationMs,
                        );
                        setState(() {
                          isDragging = true;
                        });
                      },
                      onHorizontalDragEnd: (_) async {
                        if (currentSongNotifier.value == null) {
                          return;
                        }
                        if (dragValue != null) {
                          final target = Duration(
                            milliseconds: dragValue!.toInt(),
                          );
                          _showAt(target);
                          await audioHandler.seek(target);
                        }
                        setState(() {
                          dragValue = null;
                          isDragging = false;
                        });
                      },
                      onTapUp: (details) async {
                        if (currentSongNotifier.value == null) {
                          return;
                        }
                        seekByTouch(
                          details.localPosition.dx,
                          context,
                          durationMs,
                        );
                        final target = Duration(
                          milliseconds: dragValue!.toInt(),
                        );
                        _showAt(target);
                        await audioHandler.seek(target);
                        setState(() {
                          dragValue = null;
                          isDragging = false;
                        });
                      },
                    ),
                  ),

                  // The time under the finger while dragging.
                  if (isDragging &&
                      dragValue != null &&
                      durationMs > 0 &&
                      !widget.isMiniMode)
                    _timeBubble(
                      context,
                      constraints,
                      dragValue! / durationMs,
                      Duration(milliseconds: dragValue!.toInt()),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _timeBubble(
    BuildContext context,
    BoxConstraints constraints,
    double fraction,
    Duration value,
  ) {
    const bubbleWidth = 58.0;
    final trackWidth = constraints.maxWidth - horizontalPadding * 2;
    final center = horizontalPadding + trackWidth * fraction.clamp(0.0, 1.0);
    final left = (center - bubbleWidth / 2).clamp(
      0.0,
      constraints.maxWidth - bubbleWidth,
    );
    return Positioned(
      left: left,
      bottom: widget.widgetHeight + 2,
      child: IgnorePointer(
        child: Material(
          color: colorManager.getSpecificOpaqueBgColor(),
          elevation: 6,
          shape: SmoothRectangleBorder(
            smoothness: 1,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Container(
            width: bubbleWidth,
            padding: const EdgeInsets.symmetric(vertical: 4),
            alignment: Alignment.center,
            child: Text(
              formatDuration(value),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colorManager.getSpecificTextColor(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Shows a seek target immediately, so clearing the drag value does not
  /// flash the old position for a frame before the player reports the new one.
  void _showAt(Duration position) {
    _basePosition = position;
    _baseAt = DateTime.now();
    displayPosition.value = position;
  }

  /// Map horizontal touch to slider value
  void seekByTouch(double dx, BuildContext context, double durationMs) {
    final box = trackKey.currentContext!.findRenderObject() as RenderBox;

    double relative =
        (dx - horizontalPadding) / (box.size.width - horizontalPadding * 2);
    relative = relative.clamp(0.0, 1.0);
    dragValue = relative * durationMs;
  }
}
