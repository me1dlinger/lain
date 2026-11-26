import 'package:material_ui/material_ui.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/audio_handler.dart';
import 'package:lain/base/data/font_manager.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/data/lyrics_display_settings.dart';
import 'package:lain/base/data/setting.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/widgets/my_switch.dart';
import 'package:lain/base/widgets/my_sheet.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

/// The lyric style controls shared by the portrait player, the landscape
/// player and the full lyrics page. All values are the ones the lyrics page
/// already uses: the size offset and weight live beside the lyric widgets,
/// and the font is the app-wide font family from settings.
Future<void> showLyricsStyleSheet(
  BuildContext context, {
  bool fullscreen = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _LyricsStyleSheet(fullscreen: fullscreen),
  );
}

class _LyricsStyleSheet extends StatelessWidget {
  final bool fullscreen;

  const _LyricsStyleSheet({required this.fullscreen});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return MySheet(
      ListenableBuilder(
        listenable: Listenable.merge([
          lyricsPageForegroundColor.valueNotifier,
          lyricsFontSizeOffsetNotifier,
          lyricsFullscreenFontSizeOffsetNotifier,
          lyricsFontWeightNotifier,
          lyricsFullscreenFontWeightNotifier,
          lyricsTextAlignNotifier,
          lyricsFullscreenTextAlignNotifier,
          lyricsRomajiNotifier,
          fontFamilyNotifier,
        ]),
        builder: (context, child) {
          final textColor = lyricsPageForegroundColor.value;
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Row(
                    children: [
                      Text(
                        l10n.adjustLyrics,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: textColor,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        color: textColor,
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
                _fontSizeRow(l10n, textColor),
                _offsetRow(l10n, textColor),
                _fontWeightRow(context, textColor),
                _fontFamilyRow(context, l10n, textColor),
                _alignmentRow(l10n, textColor),
                _romajiRow(l10n, textColor),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
      maxHeightFactor: 0.88,
      wrapContent: true,
    );
  }

  Widget _fontSizeRow(AppLocalizations l10n, Color textColor) {
    final notifier = fullscreen
        ? lyricsFullscreenFontSizeOffsetNotifier
        : lyricsFontSizeOffsetNotifier;
    final offset = notifier.value;
    return _LyricsRow(
      label: l10n.fontSize,
      textColor: textColor,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            color: textColor,
            onPressed: offset <= -6
                ? null
                : () {
                    notifier.value = offset - 2;
                    setting.save();
                  },
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 44,
            child: Text(
              offset == 0 ? '0' : '${offset > 0 ? '+' : ''}${offset.toInt()}',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
            ),
          ),
          IconButton(
            color: textColor,
            onPressed: offset >= 24
                ? null
                : () {
                    notifier.value = offset + 2;
                    setting.save();
                  },
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }

  Widget _offsetRow(AppLocalizations l10n, Color textColor) {
    if (fullscreen) {
      return const SizedBox.shrink();
    }
    final currentSong = currentSongNotifier.value;
    if (currentSong == null) {
      return const SizedBox.shrink();
    }
    return _LyricsRow(
      label: l10n.offset,
      textColor: textColor,
      child: StatefulBuilder(
        builder: (context, setSheetState) {
          var saving = false;
          Future<void> shift(int milliseconds) async {
            if (saving) {
              return;
            }
            saving = true;
            currentSong.lyricsTimeOffset += milliseconds;
            await library.updateLyricsTimeOffset(currentSong);
            if (!context.mounted) {
              return;
            }
            setSheetState(() {});
            saving = false;
          }

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                color: textColor,
                onPressed: () => shift(-100),
                icon: const Icon(Icons.remove_rounded),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  '${(currentSong.lyricsTimeOffset / 1000).toStringAsFixed(1)} s',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              IconButton(
                color: textColor,
                onPressed: () => shift(100),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _fontWeightRow(BuildContext context, Color textColor) {
    const weights = [
      FontWeight.w100,
      FontWeight.w200,
      FontWeight.w300,
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w800,
      FontWeight.w900,
    ];
    final notifier = fullscreen
        ? lyricsFullscreenFontWeightNotifier
        : lyricsFontWeightNotifier;
    final index = weights.indexOf(notifier.value);
    final sliderIndex = index < 0 ? 6 : index;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
      child: Row(
        children: [
          Text(
            AppLocalizations.of(context).fontWeight,
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: textColor,
                inactiveTrackColor: textColor,
                thumbColor: textColor,
                overlayColor: Colors.transparent,
                tickMarkShape: const RoundSliderTickMarkShape(
                  tickMarkRadius: 1.5,
                ),
                activeTickMarkColor: textColor.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white,
                inactiveTickMarkColor: textColor.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
              ),
              child: Slider(
                value: sliderIndex.toDouble(),
                min: 0,
                max: (weights.length - 1).toDouble(),
                divisions: weights.length - 1,
                onChanged: (value) {
                  notifier.value = weights[value.round()];
                },
                onChangeEnd: (_) => setting.save(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fontFamilyRow(
    BuildContext context,
    AppLocalizations l10n,
    Color textColor,
  ) {
    if (fullscreen) {
      return const SizedBox.shrink();
    }
    return InkWell(
      onTap: () {
        if (!isPremiumNotifier.value) {
          showPremiumDialog(context);
          return;
        }
        tryVibrate();
        showLyricsFontSheet(context);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
        child: Row(
          children: [
            Text(
              l10n.lyricsFont,
              style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
            ),
            const Spacer(),
            SizedBox(
              width: 160,
              child: Text(
                fontFamilyNotifier.value ?? l10n.defaultText,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: fontFamilyNotifier.value,
                  color: textColor.withAlpha(170),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: textColor.withAlpha(120),
            ),
          ],
        ),
      ),
    );
  }

  Widget _alignmentRow(AppLocalizations l10n, Color textColor) {
    Widget option(LyricsTextAlign value, IconData icon, String label) {
      final notifier = fullscreen
          ? lyricsFullscreenTextAlignNotifier
          : lyricsTextAlignNotifier;
      final selected = notifier.value == value;
      return IconButton(
        color: selected ? textColor : textColor.withAlpha(120),
        style: IconButton.styleFrom(
          backgroundColor: selected ? textColor.withAlpha(28) : null,
        ),
        tooltip: label,
        onPressed: () {
          notifier.value = value;
          setting.save();
        },
        icon: Icon(icon, size: 20),
      );
    }

    return _LyricsRow(
      label: l10n.lyricsAlignment,
      textColor: textColor,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          option(
            LyricsTextAlign.auto,
            Icons.auto_awesome_mosaic_outlined,
            l10n.lyricsAlignAuto,
          ),
          option(
            LyricsTextAlign.start,
            Icons.format_align_left_rounded,
            l10n.lyricsAlignLeft,
          ),
          option(
            LyricsTextAlign.center,
            Icons.format_align_center_rounded,
            l10n.lyricsAlignCenter,
          ),
        ],
      ),
    );
  }

  Widget _romajiRow(AppLocalizations l10n, Color textColor) {
    if (fullscreen) {
      return const SizedBox.shrink();
    }
    return _LyricsRow(
      label: l10n.lyricsRomaji,
      textColor: textColor,
      child: SizedBox(
        width: 50,
        child: MySwitch(
          valueNotifier: lyricsRomajiNotifier,
          onToggleCallBack: setting.save,
        ),
      ),
    );
  }
}

class _LyricsRow extends StatelessWidget {
  final String label;
  final Color textColor;
  final Widget child;

  const _LyricsRow({
    required this.label,
    required this.textColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 12, 2),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
          const Spacer(),
          child,
        ],
      ),
    );
  }
}

Future<void> showLyricsFontSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final fonts = availableFonts();
      final textColor = lyricsPageForegroundColor.value;

      void select(String? font) {
        fontFamilyNotifier.value = font;
        setting.save();
        Navigator.pop(sheetContext);
      }

      return MySheet(
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
              child: Row(
                children: [
                  Text(
                    l10n.lyricsFont,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    color: textColor,
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: fonts.length + 1,
                itemBuilder: (context, index) {
                  final String? font = index == 0 ? null : fonts[index - 1];
                  final selected = fontFamilyNotifier.value == font;
                  return ListTile(
                    title: Text(
                      font ?? l10n.defaultText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: font, color: textColor),
                    ),
                    trailing: selected
                        ? Icon(Icons.check_rounded, color: textColor)
                        : null,
                    onTap: () => select(font),
                  );
                },
              ),
            ),
          ],
        ),
        height: 440,
        maxHeightFactor: 0.8,
      );
    },
  );
}
