import 'package:material_ui/material_ui.dart';
import 'package:lain/base/audio_handler.dart';
import 'package:lain/base/utils/metadata_utils.dart';
import 'package:lain/base/data/setting.dart';
import 'package:lain/base/data/share_card_settings.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/widgets/apple_form.dart';
import 'package:lain/base/widgets/lyric_share_dialog.dart';
import 'package:lain/base/widgets/local_music_page.dart';
import 'package:lain/base/widgets/my_switch.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

/// Controls for the lyric share card, with a live preview.
class ShareCardSettingsPage extends StatefulWidget {
  const ShareCardSettingsPage({super.key});

  @override
  State<ShareCardSettingsPage> createState() => _ShareCardSettingsPageState();
}

class _ShareCardSettingsPageState extends State<ShareCardSettingsPage> {
  late final TextEditingController _topText;

  static const _backgrounds = ShareCardBackground.values;

  @override
  void initState() {
    super.initState();
    _topText = TextEditingController(text: shareCardTopTextNotifier.value);
  }

  @override
  void dispose() {
    _topText.dispose();
    super.dispose();
  }

  String _backgroundLabel(AppLocalizations l10n, ShareCardBackground mode) {
    return switch (mode) {
      ShareCardBackground.blur => l10n.shareCardBlur,
      ShareCardBackground.crop => l10n.shareCardCrop,
      ShareCardBackground.aurora => l10n.shareCardAurora,
      ShareCardBackground.pixelate => l10n.shareCardPixelate,
      ShareCardBackground.halftone => l10n.shareCardHalftone,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();
    return opaqueSettingsPage(
      context: context,
      title: l10n.shareCardSettings,
      body: ListenableBuilder(
        listenable: Listenable.merge([
          currentSongNotifier,
          shareCardTopTextNotifier,
          shareCardBackgroundNotifier,
          shareCardTextSizeNotifier,
          shareCardCoverSizeNotifier,
          shareCardShowTranslationNotifier,
        ]),
        builder: (context, child) {
          final song = currentSongNotifier.value;
          final title = song == null ? 'Sample Song' : getTitle(song);
          final artist = song == null ? 'Lain' : getArtist(song);
          final album = song == null ? '' : getAlbum(song);
          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 160),
            children: [
              Center(
                child: SizedBox(
                  width: 232,
                  height: 413,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: 280,
                      height: 498,
                      child: LyricShareCard(
                        title: title,
                        artist: artist,
                        album: album,
                        lyric: '音乐是流动的建筑',
                        translation: 'Music is liquid architecture',
                        picture: song?.picture,
                      ),
                    ),
                  ),
                ),
              ),
              appleSectionTitle(l10n.shareCardSettings),
              AppleFormSection(
                children: [
                  appleFormRow(
                    l10n.shareCardTopText,
                    TextField(
                      controller: _topText,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (value) {
                        shareCardTopTextNotifier.value = value;
                        setting.save();
                      },
                    ),
                  ),
                ],
              ),
              appleSectionTitle(l10n.shareCardBackground),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final mode in _backgrounds)
                      ChoiceChip(
                        label: Text(_backgroundLabel(l10n, mode)),
                        selected: shareCardBackgroundNotifier.value == mode,
                        onSelected: (_) {
                          shareCardBackgroundNotifier.value = mode;
                          setting.save();
                        },
                        labelStyle: TextStyle(fontSize: 12, color: textColor),
                        backgroundColor: textColor.withAlpha(16),
                        selectedColor: textColor.withAlpha(48),
                        side: BorderSide(color: textColor.withAlpha(60)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppleFormSection(
                children: [
                  _sliderRow(
                    l10n.shareCardTextSize,
                    shareCardTextSizeNotifier,
                    14,
                    32,
                    '${shareCardTextSizeNotifier.value.round()}',
                  ),
                  _sliderRow(
                    l10n.shareCardCoverSize,
                    shareCardCoverSizeNotifier,
                    100,
                    220,
                    '${shareCardCoverSizeNotifier.value.round()}',
                  ),
                  ListTile(
                    title: Text(
                      l10n.shareCardShowTranslation,
                      style: TextStyle(fontSize: 15, color: textColor),
                    ),
                    trailing: SizedBox(
                      width: 50,
                      child: MySwitch(
                        valueNotifier: shareCardShowTranslationNotifier,
                        onToggleCallBack: () => setting.save(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sliderRow(
    String label,
    ValueNotifier<double> notifier,
    double min,
    double max,
    String valueLabel,
  ) {
    final textColor = colorManager.getSpecificTextColor();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 12, 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 15, color: textColor),
            ),
          ),
          Expanded(
            child: Slider(
              min: min,
              max: max,
              value: notifier.value.clamp(min, max),
              onChanged: (value) => notifier.value = value,
              onChangeEnd: (_) => setting.save(),
              activeColor: colorManager.getSpecificIconColor(),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              valueLabel,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, color: textColor.withAlpha(160)),
            ),
          ),
        ],
      ),
    );
  }
}
