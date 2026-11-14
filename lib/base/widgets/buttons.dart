import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:lain/base/audio_handler.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/asset_images.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/widgets/play_queue_sheet.dart';
import 'package:lain/l10n/generated/app_localizations.dart';
import 'package:lain/landscape_view/pages/play_queue_page.dart';
import 'package:smooth_corner/smooth_corner.dart';

/// Play order: tapping it cycles list loop -> shuffle -> repeat one and the icon
/// follows. No menu and no label - one tap, one mode.
Widget playModeButton(double? size, {Color? iconColor}) {
  return ValueListenableBuilder(
    valueListenable: playModeNotifier,
    builder: (context, playMode, _) {
      final l10n = AppLocalizations.of(context);
      final modeIcon = ImageIcon(
        playMode == 0
            ? loopImage
            : playMode == 1
            ? shuffleImage
            : repeatImage,
        size: size,
      );
      final label = switch (playMode) {
        0 => l10n.loop,
        1 => l10n.shuffle,
        _ => l10n.repeat,
      };
      return Tooltip(
        message: '$label · ${l10n.holdForRepeatOne}',
        child: GestureDetector(
          // Long press puts the same queue into repeat one directly, from list
          // loop or from shuffle; a tap only switches between the two.
          onLongPress: () {
            if (playQueue.isEmpty) {
              return;
            }
            // A long press is not visible on the button itself, so the hand
            // has to confirm that the gesture was recognised.
            vibrateGestureFeedback();
            audioHandler.setRepeatOne();
          },
          child: IconButton(
            color: iconColor,
            icon: modeIcon,
            onPressed: () {
              if (playQueue.isEmpty) {
                return;
              }
              tryVibrate();
              audioHandler.toggleListAndShuffle();
            },
          ),
        ),
      );
    },
  );
}

Widget rewindButton(double size, {Color? iconColor}) {
  return IconButton(
    color: iconColor,
    icon: ImageIcon(rewindImage, size: size),
    onPressed: () {
      if (playQueue.isEmpty) {
        return;
      }
      if (audioHandler.getPosition() > Duration(seconds: 15)) {
        audioHandler.seek(audioHandler.getPosition() - Duration(seconds: 15));
      } else {
        audioHandler.seek(Duration.zero);
      }
    },
  );
}

Widget skip2PreviousButton(double size, {Color? iconColor}) {
  return IconButton(
    color: iconColor,
    icon: ImageIcon(previousButtonImage, size: size),
    onPressed: () {
      audioHandler.skipToPrevious();
    },
  );
}

Widget playOrPauseButton(double size, {Color? iconColor}) {
  return IconButton(
    autofocus: viewModeNotifier.value == .bigPicture,
    color: iconColor,
    icon: ValueListenableBuilder(
      valueListenable: isPlayingNotifier,
      builder: (_, isPlaying, _) {
        return Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: size,
        );
      },
    ),
    onPressed: () {
      audioHandler.togglePlay();
    },
  );
}

Widget forwardButton(double size, {Color? iconColor}) {
  return IconButton(
    color: iconColor,
    icon: ImageIcon(forwardImage, size: size),
    onPressed: () {
      if (playQueue.isEmpty) {
        return;
      }
      if (audioHandler.getPosition() + Duration(seconds: 15) <
          currentSongNotifier.value!.duration!) {
        audioHandler.seek(audioHandler.getPosition() + Duration(seconds: 15));
      } else {
        audioHandler.seek(currentSongNotifier.value!.duration!);
      }
    },
  );
}

Widget skip2NextButton(double size, {Color? iconColor}) {
  return IconButton(
    color: iconColor,
    icon: ImageIcon(nextButtonImage, size: size),
    onPressed: () {
      audioHandler.skipToNext();
    },
  );
}

Widget showPlayQueueButton(double size, {Color? iconColor}) {
  return Builder(
    builder: (context) {
      return IconButton(
        color: iconColor,
        icon: ImageIcon(playQueueImage, size: size),
        onPressed: () {
          if (playQueue.isEmpty) {
            return;
          }
          if (!isMobile || isTV) {
            Navigator.push(
              context,
              _NoSecondaryAnimationPageRoute(
                opaque: false,
                barrierColor: Colors.black.withAlpha(25),
                barrierDismissible: true,
                pageBuilder: (_, _, _) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 75, bottom: 100),
                      child: ValueListenableBuilder(
                        valueListenable: currentSongNotifier,
                        builder: (context, value, child) {
                          return Material(
                            elevation: 1,
                            color: Colors.transparent,
                            shape: SmoothRectangleBorder(
                              smoothness: 1,
                              borderRadius: BorderRadius.horizontal(
                                left: Radius.circular(10),
                              ),
                            ),
                            clipBehavior: Clip.antiAliasWithSaveLayer,
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 250),
                              color: Color.alphaBlend(
                                colorManager.getSpecificBgColor(),
                                colorManager.getSpecificBgBaseColor(),
                              ),
                              width: max(
                                350,
                                MediaQuery.widthOf(context) * 0.2,
                              ),
                              child: PlayQueuePage(),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
                transitionsBuilder: (_, animation, _, child) {
                  return SlideTransition(
                    position: Tween(begin: const Offset(1, 0), end: Offset.zero)
                        .animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                    child: child,
                  );
                },
              ),
            );
            return;
          }
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) {
              return PlayQueueSheet();
            },
          );
        },
      );
    },
  );
}

class _NoSecondaryAnimationPageRoute<T> extends PageRouteBuilder {
  _NoSecondaryAnimationPageRoute({
    required super.pageBuilder,
    required super.transitionsBuilder,
    super.opaque,
    super.barrierColor,
    super.barrierDismissible,
  });

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      (context, animation, secondaryAnimation, allowSnapshotting, child) {
        return child;
      };
}
