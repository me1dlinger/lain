import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lain/base/audio_handler.dart';
import 'package:lain/base/data/car_display.dart';
import 'package:lain/base/data/cover_broadcast_mode.dart';
import 'package:lain/base/data/setting.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/services/broadcast_inspector.dart';
import 'package:lain/base/services/stream_relay.dart';
import 'package:lain/base/widgets/my_switch.dart';
import 'package:lain/base/widgets/apple_form.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/base/widgets/local_music_page.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

/// The head unit's text layout: two or three lines, each a freely ordered mix
/// of lyric original/translation, title, artist and album, plus the classic
/// Bluetooth cover variants.
class CarDisplaySettingsPage extends StatefulWidget {
  const CarDisplaySettingsPage({super.key});

  @override
  State<CarDisplaySettingsPage> createState() =>
      _CarDisplaySettingsPageState();
}

class _CarDisplaySettingsPageState extends State<CarDisplaySettingsPage> {
  static const _separatorChoices = ['', '-', '·', '/', '|'];

  int _tab = 0;
  bool _livePreview = false;

  String _tokenLabel(AppLocalizations l10n, CarDisplayToken token) {
    return switch (token) {
      CarDisplayToken.lyricOriginal => l10n.carTokenLyricOriginal,
      CarDisplayToken.lyricTranslation => l10n.carTokenLyricTranslation,
      CarDisplayToken.title => l10n.carTokenTitle,
      CarDisplayToken.artist => l10n.carTokenArtist,
      CarDisplayToken.album => l10n.carTokenAlbum,
    };
  }

  String _coverLabel(AppLocalizations l10n, ClassicCoverMode mode) {
    return switch (mode) {
      ClassicCoverMode.bitmap => l10n.classicCoverBitmap,
      ClassicCoverMode.bitmapUri => l10n.classicCoverBitmapUri,
      ClassicCoverMode.largeBitmap => l10n.classicCoverLarge,
      ClassicCoverMode.relayUri => l10n.classicCoverRelay,
    };
  }

  String _coverModeLabel(AppLocalizations l10n, CoverBroadcastMode mode) {
    return switch (mode) {
      CoverBroadcastMode.bitmap => l10n.coverBroadcastBitmap,
      CoverBroadcastMode.server => l10n.coverBroadcastServer,
      CoverBroadcastMode.relay => l10n.coverBroadcastRelay,
      CoverBroadcastMode.content => l10n.coverBroadcastContent,
      CoverBroadcastMode.auto => l10n.coverBroadcastAuto,
      CoverBroadcastMode.relayOriginal => l10n.coverBroadcastRelayOriginal,
    };
  }

  void _update(CarDisplayConfig Function(CarDisplayConfig) change) {
    final next = change(carDisplayConfigNotifier.value.copy());
    carDisplayConfigNotifier.value = next;
    setting.save();
    audioHandler.refreshServiceMediaItem();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return opaqueSettingsPage(
      context: context,
      title: l10n.carDisplay,
      body: ListenableBuilder(
        listenable: Listenable.merge([
          carDisplayConfigNotifier,
          currentSongNotifier,
          currentLyricsIndexNotifier,
          coverBroadcastModeNotifier,
          relayAddressNotifier,
          classicCoverModeNotifier,
          controlCenterLyricsNotifier,
        ]),
        builder: (context, child) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
                child: appleSegmented<int>(
                  const [0, 1, 2],
                  (value) => switch (value) {
                    0 => l10n.carTabLayout,
                    1 => l10n.carTabCover,
                    _ => l10n.carTabLyrics,
                  },
                  _tab,
                  (value) => setState(() => _tab = value),
                ),
              ),
              Expanded(child: _tabBody(context, l10n)),
            ],
          );
        },
      ),
    );
  }

  Widget _tabBody(BuildContext context, AppLocalizations l10n) {
    final config = carDisplayConfigNotifier.value;
    if (_tab == 1) {
      return ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 130),
        children: _coverControls(context, l10n),
      );
    }
    if (_tab == 2) {
      return ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 130),
        children: _lyricsControls(context, l10n),
      );
    }

    final preview = _CarPreview(
      config: config,
      song: currentSongNotifier.value,
      lyricIndex: currentLyricsIndexNotifier.value,
      live: _livePreview,
      englishLocale: Localizations.localeOf(context).languageCode == 'en',
      onLiveChanged: (value) => setState(() => _livePreview = value),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 700) {
          return ListView(
            padding: const EdgeInsets.only(top: 4, bottom: 130),
            children: [
              preview,
              ..._layoutControls(context, l10n, config),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: ListView(
                padding: const EdgeInsets.only(top: 4, bottom: 130),
                children: [preview],
              ),
            ),
            Expanded(
              flex: 6,
              child: ListView(
                padding: const EdgeInsets.only(top: 4, bottom: 130),
                children: _layoutControls(context, l10n, config),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _layoutControls(
    BuildContext context,
    AppLocalizations l10n,
    CarDisplayConfig config,
  ) {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: appleSegmented<int>(
          const [2, 3],
          (value) => value == 2 ? l10n.carLinesTwo : l10n.carLinesThree,
          config.lineCount,
          (value) {
            _update((next) => next..lineCount = value);
          },
        ),
      ),
      for (var i = 0; i < config.lineCount; i++)
        _LineEditor(
          key: ValueKey('car-line-$i'),
          index: i,
          line: config.lines[i],
          tokenLabel: (token) => _tokenLabel(l10n, token),
          lineLabel: i == 0
              ? l10n.carLine1
              : i == 1
              ? l10n.carLine2
              : l10n.carLine3,
          separatorLabel: l10n.carSeparator,
          separatorSpace: l10n.carSeparatorSpace,
          separatorChoices: _separatorChoices,
          onChanged: (line) {
            _update((next) => next..lines[i] = line);
          },
          addFieldLabel: l10n.carAddField,
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: appleTextButton(
          l10n.carReset,
          () {
            carDisplayConfigNotifier.value = defaultCarDisplayConfig();
            setting.save();
            audioHandler.refreshServiceMediaItem();
          },
        ),
      ),
    ];
  }

  List<Widget> _coverControls(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final textColor = colorManager.getSpecificTextColor();
    return [
      ListTile(
        leading: Icon(
          Icons.album_rounded,
          size: 24,
          color: colorManager.getSpecificIconColor(),
        ),
        title: Text(l10n.coverBroadcast),
        trailing: Text(
          '${_coverModeLabel(l10n, coverBroadcastModeNotifier.value)}  ',
          style: TextStyle(fontSize: 13, color: textColor.withAlpha(170)),
        ),
        onTap: () async {
          final choice = await showAnimationDialog<CoverBroadcastMode>(
            context: context,
            child: Builder(
              builder: (dialogContext) => SizedBox(
                width: 300,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final mode in CoverBroadcastMode.values)
                        ListTile(
                          title: Text(_coverModeLabel(l10n, mode)),
                          trailing: coverBroadcastModeNotifier.value == mode
                              ? const Icon(Icons.check_rounded)
                              : null,
                          onTap: () =>
                              Navigator.pop(dialogContext, mode),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
          if (choice == null) {
            return;
          }
          coverBroadcastModeNotifier.value = choice;
          setting.save();
          audioHandler.refreshServiceMediaItem();
        },
      ),
      _relayTile(context, l10n),
      Builder(
        builder: (context) {
          final base = streamRelay.lanBaseUrl;
          if (base == null) {
            return const SizedBox.shrink();
          }
          final host = Uri.tryParse(base)?.host;
          if (host == null || host.isEmpty) {
            return const SizedBox.shrink();
          }
          final url = 'http://$host:${BroadcastInspector.httpPort}';
          return ListTile(
            leading: Icon(
              Icons.monitor_heart_outlined,
              size: 24,
              color: colorManager.getSpecificIconColor(),
            ),
            title: Text(l10n.pcInspector),
            subtitle: Text(url),
            trailing: const Icon(Icons.copy_all_outlined, size: 18),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: url));
              showCenterMessage(l10n.copied);
            },
          );
        },
      ),
      appleSectionTitle(l10n.classicCoverMode),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final mode in ClassicCoverMode.values)
              ChoiceChip(
                label: Text(
                  _coverLabel(l10n, mode),
                  style: TextStyle(fontSize: 12, color: textColor),
                ),
                selected: classicCoverModeNotifier.value == mode,
                onSelected: (_) {
                  classicCoverModeNotifier.value = mode;
                  setting.save();
                  audioHandler.refreshServiceMediaItem();
                },
                backgroundColor: textColor.withAlpha(16),
                selectedColor: textColor.withAlpha(48),
                side: BorderSide(color: textColor.withAlpha(60)),
              ),
          ],
        ),
      ),
    ];
  }

  Widget _relayTile(BuildContext context, AppLocalizations l10n) {
    final textColor = colorManager.getSpecificTextColor();
    final resolved = streamRelay.lanBaseUrl;
    final label = relayAddressNotifier.value.isEmpty
        ? '${l10n.relayAddressAuto}${resolved == null ? '' : ' · ${Uri.tryParse(resolved)?.host ?? resolved}'}'
        : relayAddressNotifier.value;
    return ListTile(
      leading: Icon(
        Icons.lan_outlined,
        size: 24,
        color: colorManager.getSpecificIconColor(),
      ),
      title: Text(l10n.relayAddress),
      trailing: Text(
        '$label  ',
        style: TextStyle(fontSize: 13, color: textColor.withAlpha(170)),
      ),
      onTap: () async {
        final candidates = await streamRelay.discoverLanAddresses();
        if (!context.mounted) {
          return;
        }
        final choice = await showAnimationDialog<String>(
          context: context,
          child: SizedBox(
            width: 320,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Builder(
                    builder: (dialogContext) => ListTile(
                      title: Text(l10n.relayAddressAuto),
                      trailing: relayAddressNotifier.value.isEmpty
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () => Navigator.pop(dialogContext, ''),
                    ),
                  ),
                  for (final candidate in candidates)
                    Builder(
                      builder: (dialogContext) => ListTile(
                        title: Text(
                          '${candidate.interfaceName} · ${candidate.address}',
                        ),
                        trailing:
                            relayAddressNotifier.value == candidate.address
                            ? const Icon(Icons.check_rounded)
                            : null,
                        onTap: () =>
                            Navigator.pop(dialogContext, candidate.address),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
        if (choice == null) {
          return;
        }
        relayAddressNotifier.value = choice;
        setting.save();
        audioHandler.refreshServiceMediaItem();
      },
    );
  }

  List<Widget> _lyricsControls(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return [
      ListTile(
        leading: Icon(
          Icons.closed_caption_rounded,
          size: 24,
          color: colorManager.getSpecificIconColor(),
        ),
        title: Text(l10n.broadcastLyrics),
        trailing: SizedBox(
          width: 50,
          child: MySwitch(
            valueNotifier: controlCenterLyricsNotifier,
            onToggleCallBack: () {
              setting.save();
              audioHandler.refreshServiceMediaItem();
            },
          ),
        ),
      ),
    ];
  }
}

class _CarPreview extends StatelessWidget {
  final CarDisplayConfig config;
  final MyAudioMetadata? song;
  final int lyricIndex;
  final bool live;
  final bool englishLocale;
  final ValueChanged<bool> onLiveChanged;

  const _CarPreview({
    required this.config,
    required this.song,
    required this.lyricIndex,
    required this.live,
    required this.englishLocale,
    required this.onLiveChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();
    final active = live ? song : null;
    final hasSong = active != null;

    final title = active != null ? getTitle(active) : 'Lain';
    final artist = active != null ? getArtist(active) : 'Lain';
    final album = active != null ? getAlbum(active) : 'Lain';

    var original = englishLocale
        ? '这是一行歌词示例'
        : 'This is a sample lyric line';
    var translation = englishLocale
        ? 'This is a sample lyric line'
        : '这是一行歌词示例';
    if (active != null) {
      final lines = active.parsedLyrics?.lines;
      if (lines != null && lyricIndex >= 0 && lyricIndex < lines.length) {
        final pair = carLyricPair(
          text: lines[lyricIndex].text,
          translations: lines[lyricIndex].translates,
          englishLocale: englishLocale,
        );
        original = pair.original;
        translation = pair.translation;
      }
    }

    final lines = live && !hasSong
        ? const <String>[]
        : composeCarDisplayLines(
            config,
            title: title,
            artist: artist,
            album: album,
            lyric: original,
            translation: translation,
            lyricsEnabled: live ? controlCenterLyricsNotifier.value : true,
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: textColor.withAlpha(14),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  l10n.carPreview,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textColor.withAlpha(160),
                  ),
                ),
                const Spacer(),
                _liveToggle(l10n, textColor),
              ],
            ),
            const SizedBox(height: 14),
            _previewCover(hasSong ? active : null, textColor),
            const SizedBox(height: 14),
            if (live && !hasSong)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 26),
                child: Text(
                  l10n.carNoSong,
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor.withAlpha(150),
                  ),
                ),
              )
            else
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.08),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  key: ValueKey(lines.join('-')),
                  children: [
                    for (var i = 0; i < lines.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          lines[i].isEmpty ? '—' : lines[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: i == 0 ? 18 : 14,
                            fontWeight: i == 0
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: i == 0
                                ? textColor
                                : textColor.withAlpha(190),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _liveToggle(AppLocalizations l10n, Color textColor) {
    Widget option(String label, bool selected, bool value) {
      return GestureDetector(
        onTap: () => onLiveChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? textColor.withAlpha(48) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? textColor : textColor.withAlpha(140),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: textColor.withAlpha(10),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          option(l10n.carPreviewBuiltin, !live, false),
          option(l10n.carPreviewLive, live, true),
        ],
      ),
    );
  }

  Widget _previewCover(MyAudioMetadata? active, Color textColor) {
    if (active != null && active.picture.isExist) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CoverArtWidget(
          size: 82,
          picture: active.picture,
          useResize: false,
        ),
      );
    }
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        color: textColor.withAlpha(12),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: SvgPicture.asset(
        'assets/images/app_icon.svg',
        width: 60,
        height: 60,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _LineEditor extends StatefulWidget {
  final int index;
  final CarDisplayLine line;
  final String Function(CarDisplayToken) tokenLabel;
  final String lineLabel;
  final String separatorLabel;
  final String separatorSpace;
  final List<String> separatorChoices;
  final String addFieldLabel;
  final ValueChanged<CarDisplayLine> onChanged;

  const _LineEditor({
    super.key,
    required this.index,
    required this.line,
    required this.tokenLabel,
    required this.lineLabel,
    required this.separatorLabel,
    required this.separatorSpace,
    required this.separatorChoices,
    required this.addFieldLabel,
    required this.onChanged,
  });

  @override
  State<_LineEditor> createState() => _LineEditorState();
}

class _LineEditorState extends State<_LineEditor> {
  late final TextEditingController _separator;

  @override
  void initState() {
    super.initState();
    _separator = TextEditingController(text: widget.line.separator);
  }

  @override
  void didUpdateWidget(_LineEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_separator.text != widget.line.separator) {
      _separator.text = widget.line.separator;
    }
  }

  @override
  void dispose() {
    _separator.dispose();
    super.dispose();
  }

  void _change({List<CarDisplayToken>? tokens, String? separator}) {
    widget.onChanged(
      CarDisplayLine(
        tokens: tokens ?? List.of(widget.line.tokens),
        separator: separator ?? widget.line.separator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = colorManager.getSpecificTextColor();
    final remaining = [
      for (final token in CarDisplayToken.values)
        if (!widget.line.tokens.contains(token)) token,
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: textColor.withAlpha(14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.lineLabel,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < widget.line.tokens.length; i++)
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.tokenLabel(widget.line.tokens[i]),
                    style: TextStyle(fontSize: 13, color: textColor),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.keyboard_arrow_up_rounded,
                    size: 20,
                    color: textColor.withAlpha(i == 0 ? 70 : 190),
                  ),
                  onPressed: i == 0
                      ? null
                      : () {
                          final tokens = List.of(widget.line.tokens);
                          final moved = tokens.removeAt(i);
                          tokens.insert(i - 1, moved);
                          _change(tokens: tokens);
                        },
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: textColor.withAlpha(
                      i == widget.line.tokens.length - 1 ? 70 : 85,
                    ),
                  ),
                  onPressed: i == widget.line.tokens.length - 1
                      ? null
                      : () {
                          final tokens = List.of(widget.line.tokens);
                          final moved = tokens.removeAt(i);
                          tokens.insert(i + 1, moved);
                          _change(tokens: tokens);
                        },
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: textColor.withAlpha(150),
                  ),
                  onPressed: () {
                    final tokens = List.of(widget.line.tokens)..removeAt(i);
                    _change(tokens: tokens);
                  },
                ),
              ],
            ),
          if (remaining.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final token in remaining)
                    ActionChip(
                      label: Text(
                        widget.tokenLabel(token),
                        style: TextStyle(fontSize: 11, color: textColor),
                      ),
                      backgroundColor: textColor.withAlpha(10),
                      side: BorderSide(color: textColor.withAlpha(45)),
                      onPressed: () => _change(
                        tokens: [...widget.line.tokens, token],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 70,
                child: Text(
                  widget.separatorLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withAlpha(150),
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _separator,
                  style: TextStyle(fontSize: 12, color: textColor),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: widget.separatorSpace,
                    border: InputBorder.none,
                  ),
                  onChanged: (value) => _change(separator: value),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 4,
            children: [
              for (final choice in widget.separatorChoices)
                GestureDetector(
                  onTap: () {
                    _separator.text = choice;
                    _change(separator: choice);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(top: 2, right: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: textColor.withAlpha(
                        choice == widget.line.separator ? 42 : 12,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      choice.isEmpty ? widget.separatorSpace : choice,
                      style: TextStyle(fontSize: 11, color: textColor),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
