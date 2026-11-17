import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lain/base/services/backup_service.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/widgets/apple_form.dart';
import 'package:lain/base/widgets/local_music_page.dart';
import 'package:lain/base/widgets/my_switch.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

/// Moves the parts of the app that are not the music itself - settings,
/// servers, playlists and listening statistics - into one file and back.
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  BackupSelection _selection = const BackupSelection();
  bool _working = false;

  final _settingsSwitch = ValueNotifier(true);
  final _serversSwitch = ValueNotifier(true);
  final _playlistsSwitch = ValueNotifier(true);
  final _statsSwitch = ValueNotifier(true);

  @override
  void dispose() {
    _settingsSwitch.dispose();
    _serversSwitch.dispose();
    _playlistsSwitch.dispose();
    _statsSwitch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();
    return opaqueSettingsPage(
      context: context,
      title: l10n.backupData,
      body: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 80),
        children: [
          appleSectionTitle(l10n.backupExport),
          _toggle(
            Icons.tune_rounded,
            l10n.backupSettings,
            _selection.settings,
            (value) => setState(() {
              _selection = _selection.copyWith(settings: value);
            }),
            notifier: _settingsSwitch,
          ),
          _toggle(
            Icons.dns_rounded,
            l10n.backupServers,
            _selection.servers,
            (value) => setState(() {
              _selection = _selection.copyWith(servers: value);
            }),
            notifier: _serversSwitch,
          ),
          _toggle(
            Icons.queue_music_rounded,
            l10n.backupPlaylists,
            _selection.playlists,
            (value) => setState(() {
              _selection = _selection.copyWith(playlists: value);
            }),
            notifier: _playlistsSwitch,
          ),
          _toggle(
            Icons.insights_rounded,
            l10n.backupStatistics,
            _selection.statistics,
            (value) => setState(() {
              _selection = _selection.copyWith(statistics: value);
            }),
            notifier: _statsSwitch,
          ),
          if (_selection.servers)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
              child: Text(
                l10n.backupPrivacy,
                style: TextStyle(
                  fontSize: 12,
                  color: textColor.withAlpha(130),
                ),
              ),
            ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FilledButton.icon(
              onPressed: _working ? null : _export,
              icon: _working
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_alt_rounded, size: 19),
              label: Text(l10n.backupExport),
            ),
          ),
          const SizedBox(height: 12),
          appleSectionTitle(l10n.backupImport),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: OutlinedButton.icon(
              onPressed: _working ? null : _import,
              icon: const Icon(Icons.settings_backup_restore_rounded, size: 19),
              label: Text(l10n.backupImport),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggle(
    IconData icon,
    String title,
    bool value,
    ValueChanged<bool> onChanged, {
    required ValueNotifier<bool> notifier,
  }) {
    final textColor = colorManager.getSpecificTextColor();
    return ListTile(
      leading: Icon(
        icon,
        size: 24,
        color: colorManager.getSpecificIconColor(),
      ),
      title: Text(title, style: TextStyle(color: textColor)),
      trailing: SizedBox(
        width: 50,
        child: MySwitch(
          valueNotifier: notifier,
          onToggleCallBack: () => onChanged(notifier.value),
        ),
      ),
    );
  }

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _working = true);
    try {
      final bytes = await backupService.export(selection: _selection);
      final stamp = DateTime.now()
          .toIso8601String()
          .substring(0, 19)
          .replaceAll(':', '-');
      final saved = await FilePicker.saveFile(
        fileName: 'lain-backup-$stamp.json',
        bytes: bytes,
        mimeType: 'application/json',
        dialogTitle: l10n.backupExport,
      );
      if (!mounted) {
        return;
      }
      if (saved != null) {
        showCenterMessage(l10n.backupSaved);
      }
    } catch (e) {
      if (mounted) {
        showCenterMessage('${l10n.operationFailed}: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  Future<void> _import() async {
    final l10n = AppLocalizations.of(context);
    final file = await FilePicker.pickFile(
      dialogTitle: l10n.backupImport,
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    BackupPreview preview;
    String text;
    try {
      text = utf8.decode(await file.readAsBytes());
      preview = backupService.inspect(text);
    } catch (_) {
      showCenterMessage(l10n.backupInvalid);
      return;
    }

    if (!mounted) {
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      l10n.backupRestoreConfirm,
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _working = true);
    try {
      final rollback = await backupService.restore(text);
      if (!mounted) {
        return;
      }
      final created = preview.createdAt;
      showCenterMessage(
        l10n.backupRestoreDone +
            (created == null ? '' : '  ·  ${created.toLocal()}'),
      );
      debugPrint('[backup] restored, rollback at $rollback');
    } catch (e) {
      if (mounted) {
        showCenterMessage('${l10n.operationFailed}: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }
}
