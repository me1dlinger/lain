import 'package:lain/base/app.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/data/library_naming.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/widgets/album_timeline_page.dart';
import 'package:lain/base/widgets/apple_form.dart';
import 'package:lain/base/widgets/library_health_page.dart';
import 'package:lain/base/widgets/library_naming_page.dart';
import 'package:lain/base/widgets/library_organize_page.dart';
import 'package:lain/base/widgets/local_music_page.dart';
import 'package:lain/base/widgets/metadata_completion_page.dart';
import 'package:lain/base/widgets/settings_page_route.dart';
import 'package:lain/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The local library's tools: naming, organizing, tag completion and the album
/// timeline. It only exists for the on-device source; a streamed or WebDAV
/// source never reaches this page.
class LocalLibraryToolsPage extends StatelessWidget {
  const LocalLibraryToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    assert(isLocalLibrary);
    final l10n = AppLocalizations.of(context);
    return opaqueSettingsPage(
      context: context,
      title: l10n.localLibraryTools,
      body: const _LocalLibraryToolsBody(),
    );
  }
}

class _LocalLibraryToolsBody extends StatelessWidget {
  const _LocalLibraryToolsBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();

    return ListenableBuilder(
      listenable: Listenable.merge([
        library.changeNotifier,
        library.folderListChangeNotifier,
        libraryDirTemplateNotifier,
        libraryFileTemplateNotifier,
      ]),
      builder: (context, child) {
        final missing = countSongsMissingTags(library.songList);
        return ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 100),
          children: [
            appleSectionTitle(l10n.organizeSection),
            AppleFormSection(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.drive_file_rename_outline_rounded,
                    size: 30,
                    color: iconColor.value,
                  ),
                  title: Text(l10n.namingFormat),
                  subtitle: Text(
                    '${libraryDirTemplateNotifier.value} · '
                    '${libraryFileTemplateNotifier.value}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withAlpha(150),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    pushSettingsPage<void>(
                      context,
                      settingsPageRoute<void>(() => const LibraryNamingPage()),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.drive_file_move_rounded,
                    size: 30,
                    color: iconColor.value,
                  ),
                  title: Text(l10n.organizeFiles),
                  subtitle: Text(
                    l10n.organizeFilesHint,
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withAlpha(150),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    pushSettingsPage<void>(
                      context,
                      settingsPageRoute<void>(
                        () => const LibraryOrganizePage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.edit_note_rounded,
                    size: 30,
                    color: iconColor.value,
                  ),
                  title: Text(l10n.metadataCompletion),
                  subtitle: Text(
                    l10n.songsMissingTags(missing),
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withAlpha(150),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    pushSettingsPage<void>(
                      context,
                      settingsPageRoute<void>(
                        () => const MetadataCompletionPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.health_and_safety_outlined,
                    size: 30,
                    color: iconColor.value,
                  ),
                  title: Text(l10n.libraryHealth),
                  subtitle: Text(
                    l10n.healthTotal(library.songList.length),
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withAlpha(150),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    pushSettingsPage<void>(
                      context,
                      settingsPageRoute<void>(() => const LibraryHealthPage()),
                    );
                  },
                ),
              ],
            ),
            appleSectionTitle(l10n.browseSection),
            AppleFormSection(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.timeline_rounded,
                    size: 30,
                    color: iconColor.value,
                  ),
                  title: Text(l10n.albumTimeline),
                  subtitle: Text(
                    l10n.albumTimelineHint,
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withAlpha(150),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    pushSettingsPage<void>(
                      context,
                      settingsPageRoute<void>(
                        () => const AlbumTimelinePage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
