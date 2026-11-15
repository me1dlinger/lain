import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/services/metadata_write.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/widgets/apple_form.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/base/widgets/lyric_timeline_page.dart';
import 'package:lain/base/widgets/metadata_scrape_dialog.dart';
import 'package:lain/base/widgets/settings_page_route.dart';
import 'package:lain/l10n/generated/app_localizations.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:permission_handler/permission_handler.dart';

class EditMetadata extends StatefulWidget {
  final MyAudioMetadata song;

  const EditMetadata({super.key, required this.song});

  @override
  State<StatefulWidget> createState() => _EditMetadataState();
}

class _EditMetadataState extends State<EditMetadata> {
  late final MyAudioMetadata song;

  final TextEditingController _titleTextController = TextEditingController();
  final TextEditingController _artistTextController = TextEditingController();
  final TextEditingController _albumTextController = TextEditingController();
  final TextEditingController _albumArtistTextController =
      TextEditingController();
  final TextEditingController _genreTextController = TextEditingController();
  final TextEditingController _yearTextController = TextEditingController();
  final TextEditingController _trackTextController = TextEditingController();
  final TextEditingController _discTextController = TextEditingController();
  final TextEditingController _lyricsTextController = TextEditingController();
  late final ValueNotifier<String?> _picturePathNotifier;
  late final String _originalPicturePath;

  @override
  void initState() {
    super.initState();
    song = widget.song;
    _titleTextController.text = song.title ?? '';
    _artistTextController.text = song.artist ?? '';
    _albumTextController.text = song.album ?? '';
    _albumArtistTextController.text = song.albumArtist ?? '';
    _genreTextController.text = song.genre ?? '';
    _yearTextController.text = song.year?.toString() ?? '';
    _trackTextController.text = song.track?.toString() ?? '';
    _discTextController.text = song.disc?.toString() ?? '';
    _lyricsTextController.text = song.lyrics ?? '';
    _picturePathNotifier = ValueNotifier(song.picture.path);
    _originalPicturePath = song.picture.path;
  }

  @override
  void dispose() {
    _titleTextController.dispose();
    _artistTextController.dispose();
    _albumTextController.dispose();
    _albumArtistTextController.dispose();
    _genreTextController.dispose();
    _yearTextController.dispose();
    _trackTextController.dispose();
    _discTextController.dispose();
    _lyricsTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final shortSide = size.shortestSide;

    bool isPhone = shortSide < 600;
    return SizedBox(
      height: max(350, size.height * 0.7),
      width: isPhone ? 300 : 400,
      child: _content(context, isPhone),
    );
  }

  Widget _content(BuildContext context, bool isPhone) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();

    return Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
        child: Column(
          children: [
            Text(
              l10n.editMetadata,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 10),
                children: [
                  Center(child: _coverArt(context, song, isPhone)),
                  AppleFormSection(
                    divided: false,
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.search_rounded,
                          size: 22,
                          color: iconColor.value,
                        ),
                        title: Text(l10n.searchTags),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _searchTags(context),
                      ),
                    ],
                  ),
                  AppleFormSection(
                    children: [
                      appleTextFieldRow(l10n.title, _titleTextController),
                      appleTextFieldRow(l10n.artist, _artistTextController),
                      appleTextFieldRow(l10n.album, _albumTextController),
                      appleTextFieldRow(
                        l10n.albumArtist,
                        _albumArtistTextController,
                      ),
                    ],
                  ),
                  AppleFormSection(
                    children: [
                      appleTextFieldRow(l10n.genre, _genreTextController),
                      appleTextFieldRow(
                        l10n.year,
                        _yearTextController,
                        number: true,
                      ),
                      appleTextFieldRow(
                        l10n.track,
                        _trackTextController,
                        number: true,
                      ),
                      appleTextFieldRow(
                        l10n.disc,
                        _discTextController,
                        number: true,
                      ),
                    ],
                  ),
                  AppleFormSection(
                    children: [
                      appleFormRow(
                        l10n.lyrics,
                        appleTextField(_lyricsTextController, maxLines: 6),
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.timer_outlined,
                          size: 22,
                          color: iconColor.value,
                        ),
                        title: Text(l10n.lyricTimeline),
                        subtitle: Text(
                          l10n.lyricTimelineHint,
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor.withAlpha(150),
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _openLyricTimeline(context),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: appleFilledButton(
                      l10n.confirm,
                      () => _tryWriteMetadata(context, song),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: appleTextButton(
                      l10n.cancel,
                      () => Navigator.pop(context, false),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
    );
  }

  Widget _coverArt(BuildContext context, MyAudioMetadata song, bool isPhone) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: ValueListenableBuilder(
        valueListenable: _picturePathNotifier,
        builder: (context, picturePath, child) {
          return Tooltip(
            message: l10n.replacePicture,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () async {
                  final result = await FilePicker.pickFile(
                    type: FileType.image,
                  );

                  if (result == null) {
                    return;
                  }

                  _picturePathNotifier.value = result.path;
                },
                child: CoverArtWidget(
                  picture: song.picture,
                  picturePath: picturePath,
                  size: isPhone ? 150 : 180,
                  borderRadius: 10,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _tryWriteMetadata(
    BuildContext context,
    MyAudioMetadata song,
  ) async {
    final l10n = AppLocalizations.of(context);

    if (await showConfirmDialog(context, l10n.updateMedata)) {
      if (Platform.isAndroid) {
        if (await Permission.manageExternalStorage.request() == .denied) {
          if (context.mounted) {
            showCenterMessage(l10n.updateFailed);
          }
          return;
        }
      }
      String writeTitle = _titleTextController.text;
      String writeArtist = _artistTextController.text;
      String writeAlbum = _albumTextController.text;
      String writeAlbumArtist = _albumArtistTextController.text;
      String writeGenre = _genreTextController.text;
      String writeLyrics = _lyricsTextController.text;
      int? writeYear = int.tryParse(_yearTextController.text);
      int? writeTrack = int.tryParse(_trackTextController.text);
      int? writeDisc = int.tryParse(_discTextController.text);

      Uint8List? writePictureBytes;
      final pictureChanged = _picturePathNotifier.value != _originalPicturePath;
      if (_picturePathNotifier.value != null) {
        File pictureFile = File(_picturePathNotifier.value!);
        if (await pictureFile.exists()) {
          writePictureBytes = await pictureFile.readAsBytes();
        }
      }

      final lyricsChanged = writeLyrics != (song.lyrics ?? '');
      final success = await writeSongTags(
        song: song,
        title: writeTitle,
        artist: writeArtist,
        album: writeAlbum,
        albumArtist: writeAlbumArtist,
        genre: writeGenre,
        lyrics: writeLyrics,
        year: writeYear,
        track: writeTrack,
        disc: writeDisc,
        // Only a cover the user actually picked is written; otherwise the
        // existing artwork stays untouched.
        pictureBytes: pictureChanged ? writePictureBytes : null,
        lyricsChanged: lyricsChanged,
      );

      if (context.mounted) {
        showCenterMessage(
          success ? l10n.updateSuccessfully : l10n.updateFailed,
        );
        if (success) {
          Navigator.pop(context);
        }
      }
    }
  }

  Future<void> _searchTags(BuildContext context) async {
    final applied = await showAnimationDialog<bool>(
      context: context,
      child: MetadataScrapeDialog(song: song),
    );
    if (applied == true && mounted) {
      _syncControllersFromSong();
    }
  }

  void _syncControllersFromSong() {
    _titleTextController.text = song.title ?? '';
    _artistTextController.text = song.artist ?? '';
    _albumTextController.text = song.album ?? '';
    _albumArtistTextController.text = song.albumArtist ?? '';
    _genreTextController.text = song.genre ?? '';
    _yearTextController.text = song.year?.toString() ?? '';
    _trackTextController.text = song.track?.toString() ?? '';
    _discTextController.text = song.disc?.toString() ?? '';
    _lyricsTextController.text = song.lyrics ?? '';
    setState(() {});
  }

  Future<void> _openLyricTimeline(BuildContext context) async {
    final text = await Navigator.of(context).push<String>(
      settingsPageRoute<String>(
        () => LyricTimelinePage(song: song, returnOnly: true),
      ),
    );
    if (text != null && mounted) {
      _lyricsTextController.text = text;
      setState(() {});
    }
  }
}
