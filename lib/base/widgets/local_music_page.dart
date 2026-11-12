import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:lain/base/app.dart';
import 'package:lain/base/asset_images.dart';
import 'package:lain/base/data/folder_scan_settings.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/data/loader.dart';
import 'package:lain/base/data/setting.dart';
import 'package:lain/base/services/bookmark_service.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/services/logger.dart';
import 'package:lain/base/utils/path.dart';
import 'package:lain/base/widgets/my_scaffold.dart';
import 'package:lain/base/widgets/my_switch.dart';
import 'package:lain/base/widgets/settings_page_route.dart';
import 'package:lain/base/widgets/tv_dir_picker.dart';
import 'package:lain/l10n/generated/app_localizations.dart';
import 'package:lain/layer/layers_manager.dart';

/// A settings page for the local source's folders: add/remove them, choose
/// whether each scans its subdirectories, block folders, and skip short clips.
class LocalMusicSettingsPage extends StatelessWidget {
  const LocalMusicSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return opaqueSettingsPage(
      context: context,
      title: l10n.localMusicSource,
      body: const LocalMusicPage(),
    );
  }
}

/// The same page background the other pushed settings pages use, so nothing
/// shows through while the page slides in.
Widget opaqueSettingsPage({
  required BuildContext context,
  required String title,
  required Widget body,
}) {
  return ListenableBuilder(
    listenable: Listenable.merge([
      layersManager.backgroundChangeNotifier,
      panelColor.valueNotifier,
      pageBackgroundColor.valueNotifier,
    ]),
    builder: (context, child) {
      return Container(
        color: colorManager.getSpecificOpaqueBgColor(),
        child: myScaffold(
          context: context,
          body: body,
          label: '__pushed__',
          title: title,
        ),
      );
    },
  );
}

class LocalMusicPage extends StatefulWidget {
  const LocalMusicPage({super.key});

  @override
  State<LocalMusicPage> createState() => _LocalMusicPageState();
}

class _LocalMusicPageState extends State<LocalMusicPage> {
  List<String> _folderIds = [];
  bool _loaded = false;

  File get _folderIdFile =>
      File('${getFolderConfigPath(SourceType.local)}/folder_id_list.json');

  @override
  void initState() {
    super.initState();
    _loadFolderIds();
  }

  Future<void> _loadFolderIds() async {
    final ids = <String>[];
    try {
      final file = _folderIdFile;
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString());
        if (raw is List) {
          ids.addAll(raw.map((e) => e.toString()));
        }
      }
    } catch (e) {
      logger.output('[local music] folder list: $e');
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _folderIds = ids;
      _loaded = true;
    });
  }

  Future<void> _saveFolderIds() async {
    final file = _folderIdFile;
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(_folderIds));
    if (sourceType == .local) {
      await library.updateFolders(_folderIds);
    }
  }

  Future<String?> _pickDirectory() async {
    if (isTV) {
      return showAnimationDialog<String>(
        context: context,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.8,
          width: 300,
          child: const TvDirPicker(),
        ),
      );
    }
    return FilePicker.getDirectoryPath();
  }

  /// iOS needs a security-scoped bookmark for a picked folder; everywhere
  /// else the path itself is the id.
  Future<String?> _folderIdFor(String path) async {
    if (!Platform.isIOS) {
      return path;
    }
    final l10n = AppLocalizations.of(context);
    final onMyPhone = isFileProviderStorePath(path);
    if (!onMyPhone && !path.contains(appDocsDir.path)) {
      showCenterMessage(l10n.folderNotSupportedYet);
      return null;
    }
    if (onMyPhone && !await BookmarkService.active(path)) {
      showCenterMessage(l10n.getPermissionFailed);
      return null;
    }
    if (onMyPhone) {
      setIOSFileProviderStorageIfNeed(path);
    }
    return convertIOSPath(path);
  }

  Future<void> _addFolder() async {
    final path = await _pickDirectory();
    if (path == null || !mounted) {
      return;
    }
    final id = await _folderIdFor(path);
    if (id == null || !mounted) {
      return;
    }
    if (_folderIds.contains(id)) {
      showCenterMessage(AppLocalizations.of(context).folderExist);
      return;
    }
    setState(() => _folderIds.add(id));
    await _saveFolderIds();
  }

  Future<void> _removeFolder(String id) async {
    setState(() => _folderIds.remove(id));
    await _saveFolderIds();
  }

  Future<void> _configureFolder(String id) async {
    final l10n = AppLocalizations.of(context);
    await showAnimationDialog<void>(
      context: context,
      child: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(id, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            SwitchListTile(
              value: folderScansSubdirectories(id),
              title: Text(l10n.scanSubdirectories),
              onChanged: (value) {
                folderScanSubdirectories[id] = value;
                setting.save();
                // The dialog lives on the root navigator; the page's context
                // points at the settings navigator underneath it.
                Navigator.of(context, rootNavigator: true).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editMinDuration() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(
      text: minAudioSecondsNotifier.value.toString(),
    );
    final result = await showAnimationDialog<int>(
      context: context,
      child: SizedBox(
        width: 300,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.minimumAudioLength,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).pop(),
                    child: Text(l10n.cancel),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(
                        context,
                        rootNavigator: true,
                      ).pop(int.tryParse(controller.text.trim()));
                    },
                    child: Text(l10n.confirm),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (result != null && result > 0) {
      minAudioSecondsNotifier.value = result;
      setting.save();
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _startScan() async {
    final l10n = AppLocalizations.of(context);
    showCenterLoading();
    try {
      if (sourceType != .local) {
        await Loader.switchToLocal();
        tryVibrate();
        showCenterMessage(l10n.syncDone);
      } else {
        final synced = await Loader.sync();
        tryVibrate();
        showCenterMessage(synced ? l10n.syncDone : l10n.syncFailed);
      }
    } catch (e) {
      logger.output('[local music] scan: $e');
      showCenterMessage('$e');
    } finally {
      removeCenterLoading();
    }
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: colorManager.getSpecificTextColor().withAlpha(150),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      children: [
        ListTile(
          leading: ImageIcon(reloadImage, size: 30),
          title: Text(l10n.startScan),
          onTap: _startScan,
        ),
        _sectionTitle(context, l10n.customFolders),
        for (final id in _folderIds)
          ListTile(
            leading: ImageIcon(folderImage, size: 30),
            title: Text(id, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => _removeFolder(id),
            ),
            onTap: () => _configureFolder(id),
          ),
        ListTile(
          leading: Icon(
            Icons.create_new_folder_outlined,
            size: 30,
            color: iconColor.value,
          ),
          title: Text(l10n.addCustomFolder),
          onTap: _addFolder,
        ),
        const Divider(),
        _sectionTitle(context, l10n.settings),
        ListTile(
          leading: Icon(Icons.timer_outlined, size: 30, color: iconColor.value),
          title: Text(l10n.skipShortAudio(minAudioSecondsNotifier.value)),
          trailing: SizedBox(
            width: 50,
            child: MySwitch(
              valueNotifier: skipShortAudioNotifier,
              onToggleCallBack: setting.save,
            ),
          ),
          onTap: _editMinDuration,
        ),
        ListTile(
          leading: Icon(Icons.block_rounded, size: 30, color: iconColor.value),
          title: Text(l10n.blockedFolders),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            pushSettingsPage<void>(
              context,
              settingsPageRoute<void>(() => const BlockedFoldersPage()),
            );
          },
        ),
        ListTile(
          leading: Icon(
            Icons.sd_storage_outlined,
            size: 30,
            color: iconColor.value,
          ),
          title: Text(l10n.manageStoragePermission),
          onTap: () {
            openAppSettings();
          },
        ),
      ],
    );
  }
}

class BlockedFoldersPage extends StatelessWidget {
  const BlockedFoldersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return opaqueSettingsPage(
      context: context,
      title: l10n.blockedFolders,
      body: const _BlockedFoldersBody(),
    );
  }
}

class _BlockedFoldersBody extends StatefulWidget {
  const _BlockedFoldersBody();

  @override
  State<_BlockedFoldersBody> createState() => _BlockedFoldersBodyState();
}

class _BlockedFoldersBodyState extends State<_BlockedFoldersBody> {
  Future<String?> _pickDirectory() async {
    if (isTV) {
      return showAnimationDialog<String>(
        context: context,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.8,
          width: 300,
          child: const TvDirPicker(),
        ),
      );
    }
    return FilePicker.getDirectoryPath();
  }

  Future<void> _add() async {
    final path = await _pickDirectory();
    if (path == null || !mounted) {
      return;
    }
    final current = blockedFoldersNotifier.value;
    if (current.contains(path)) {
      return;
    }
    blockedFoldersNotifier.value = [...current, path];
    setting.save();
    if (mounted) {
      setState(() {});
    }
  }

  void _remove(String path) {
    final current = List<String>.of(blockedFoldersNotifier.value)..remove(path);
    blockedFoldersNotifier.value = current;
    setting.save();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<List<String>>(
      valueListenable: blockedFoldersNotifier,
      builder: (context, blocked, child) {
        return ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 100),
          children: [
            for (final path in blocked)
              ListTile(
                leading: ImageIcon(folderImage, size: 30),
                title: Text(path, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => _remove(path),
                ),
              ),
            if (blocked.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(l10n.noBlockedFolders),
              ),
            ListTile(
              leading: Icon(
                Icons.create_new_folder_outlined,
                size: 30,
                color: iconColor.value,
              ),
              title: Text(l10n.addBlockedFolder),
              onTap: _add,
            ),
          ],
        );
      },
    );
  }
}
