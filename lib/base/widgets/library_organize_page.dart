import 'dart:io';

import 'package:lain/base/app.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/data/loader.dart';
import 'package:lain/base/data/organize_outcome.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/services/library_organizer.dart';
import 'package:lain/base/services/logger.dart';
import 'package:lain/base/widgets/apple_form.dart';
import 'package:lain/base/widgets/local_music_page.dart';
import 'package:lain/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

/// Previews and then applies the naming templates to a set of local songs.
///
/// The preview is read-only; nothing moves until the user confirms, and a
/// conflict or a file outside the library's folders is never moved. After a run
/// the page offers a single-step undo for as long as it stays open.
class LibraryOrganizePage extends StatefulWidget {
  /// The songs to organize; null means the whole local library.
  final List<MyAudioMetadata>? songs;

  /// Overrides the app bar title, for the artist page's "organize folder".
  final String? title;

  const LibraryOrganizePage({super.key, this.songs, this.title});

  @override
  State<LibraryOrganizePage> createState() => _LibraryOrganizePageState();
}

class _LibraryOrganizePageState extends State<LibraryOrganizePage> {
  OrganizePreview? _preview;
  bool _loading = false;
  String? _error;
  bool _executing = false;
  OrganizeResult? _result;
  final ValueNotifier<(int, int)> _progress = ValueNotifier((0, 0));
  bool _stopRequested = false;
  bool _undoing = false;

  @override
  void initState() {
    super.initState();
    _generatePreview();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  List<MyAudioMetadata> get _songs => widget.songs ?? library.songList;

  Future<void> _generatePreview({bool keepResult = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (!keepResult) {
        _result = null;
      }
    });
    try {
      final preview = await LibraryOrganizer.instance.preview(_songs);
      if (!mounted) {
        return;
      }
      setState(() {
        _preview = preview;
        _loading = false;
      });
    } catch (e) {
      logger.output('[organize] preview failed: $e');
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _start() async {
    final preview = _preview;
    if (preview == null || _executing) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    if (Loader.busy) {
      showCenterMessage(l10n.syncingWait);
      return;
    }
    if (!await showConfirmDialog(context, l10n.organizeFiles)) {
      return;
    }
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.request() == .denied) {
        if (mounted) {
          showCenterMessage(l10n.updateFailed);
        }
        return;
      }
    }
    if (!mounted) {
      return;
    }

    _stopRequested = false;
    _progress.value = (0, preview.count(OrganizeStatus.normal));
    setState(() => _executing = true);

    showAnimationDialog<void>(
      context: context,
      barrierDismissible: false,
      child: _ProgressDialog(
        progress: _progress,
        onStop: () => _stopRequested = true,
      ),
    );

    final result = await LibraryOrganizer.instance.execute(
      preview,
      onProgress: (done, total) => _progress.value = (done, total),
      isCancelled: () => _stopRequested,
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context, rootNavigator: true).pop();
    setState(() {
      _executing = false;
      _result = result;
    });
    showCenterMessage(
      l10n.organizeResultMessage(result.moved, result.skipped, result.failed),
    );
    // The preview is kept: its items still carry the old and new names, and the
    // result's moved paths turn them into "organized" rows. Rebuilding it now
    // would turn every moved file into "skip" and lose that.
  }

  Future<void> _undo() async {
    final l10n = AppLocalizations.of(context);
    if (_undoing || !LibraryOrganizer.instance.canUndo) {
      return;
    }
    if (!await showConfirmDialog(context, l10n.undoOrganize)) {
      return;
    }
    setState(() => _undoing = true);
    final ok = await LibraryOrganizer.instance.undo();
    if (!mounted) {
      return;
    }
    setState(() {
      _undoing = false;
      if (ok) {
        _result = null;
      }
    });
    showCenterMessage(ok ? l10n.undoSuccessfully : l10n.undoFailed);
    if (ok) {
      await _generatePreview();
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(isLocalLibrary);
    final l10n = AppLocalizations.of(context);
    final preview = _preview;

    return opaqueSettingsPage(
      context: context,
      title: widget.title ?? l10n.organizeFiles,
      actions: [
        if (!_loading &&
            preview != null &&
            preview.hasExecutable &&
            _result == null)
          TextButton(
            onPressed:
                preview.hasExecutable &&
                    !_executing &&
                    !(_result?.stopped ?? false)
                ? _start
                : null,
            child: Text(
              l10n.startOrganizing,
              style: TextStyle(
                fontSize: 15,
                color: colorManager.getSpecificTextColor(),
              ),
            ),
          ),
      ],
      body: _body(context, l10n, preview),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    OrganizePreview? preview,
  ) {
    final textColor = colorManager.getSpecificTextColor();

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: const TextStyle(fontSize: 14, color: Colors.red),
            ),
            TextButton(onPressed: _generatePreview, child: Text(l10n.retry)),
          ],
        ),
      );
    }
    if (preview == null || preview.isEmpty) {
      return Center(
        child: Text(
          l10n.noData,
          style: TextStyle(fontSize: 14, color: textColor.withAlpha(150)),
        ),
      );
    }

    final rows = preview.items;
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      itemCount: rows.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _overview(context, l10n, preview);
        }
        if (index == rows.length + 1) {
          return _footer(context, l10n);
        }
        return _changeRow(context, l10n, rows[index - 1]);
      },
    );
  }

  Widget _overview(
    BuildContext context,
    AppLocalizations l10n,
    OrganizePreview preview,
  ) {
    final textColor = colorManager.getSpecificTextColor();
    final directories = <String, int>{};
    for (final item in preview.items) {
      if (item.status != OrganizeStatus.normal || item.newPath == null) {
        continue;
      }
      final dir = p.dirname(item.newPath!);
      directories[dir] = (directories[dir] ?? 0) + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        appleSectionTitle(l10n.overview),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              for (final status in OrganizeStatus.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: textColor.withAlpha(38),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${preview.count(status)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _statusLabel(context, status),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor.withAlpha(160),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (directories.isNotEmpty) appleSectionTitle(l10n.directoryPreview),
        if (directories.isNotEmpty)
          AppleFormSection(
            children: [
              for (final entry in directories.entries)
                ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.folder_outlined,
                    color: iconColor.value,
                  ),
                  title: Text(
                    entry.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    '${entry.value}',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withAlpha(160),
                    ),
                  ),
                ),
            ],
          ),
        appleSectionTitle(l10n.changeList),
      ],
    );
  }

  String _statusLabel(BuildContext context, OrganizeStatus status) {
    final l10n = AppLocalizations.of(context);
    return switch (status) {
      OrganizeStatus.normal => l10n.organizeNormal,
      OrganizeStatus.skip => l10n.organizeSkip,
      OrganizeStatus.conflict => l10n.organizeConflict,
      OrganizeStatus.blocked => l10n.organizeBlocked,
    };
  }

  /// What happened to [item] in the run that just finished, or what the preview
  /// says when no run has happened yet.
  OrganizeOutcomeKind _outcomeOf(OrganizeItem item) {
    final result = _result;
    if (result != null) {
      if (result.movedPaths.contains(item.oldPath)) {
        return OrganizeOutcomeKind.organized;
      }
      if (result.failedPaths.contains(item.oldPath)) {
        return OrganizeOutcomeKind.failed;
      }
    }
    return switch (item.status) {
      OrganizeStatus.normal => OrganizeOutcomeKind.pending,
      OrganizeStatus.skip => OrganizeOutcomeKind.skipped,
      OrganizeStatus.conflict => OrganizeOutcomeKind.conflict,
      OrganizeStatus.blocked => OrganizeOutcomeKind.blocked,
    };
  }

  String _outcomeLabel(AppLocalizations l10n, OrganizeOutcomeKind kind) {
    return switch (kind) {
      OrganizeOutcomeKind.organized => l10n.organizeDone,
      OrganizeOutcomeKind.skipped => l10n.organizeSkip,
      OrganizeOutcomeKind.conflict => l10n.organizeConflict,
      OrganizeOutcomeKind.blocked => l10n.organizeBlocked,
      OrganizeOutcomeKind.failed => l10n.organizeFailed,
      OrganizeOutcomeKind.pending =>
        _result == null ? l10n.organizeNormal : l10n.organizePending,
    };
  }

  String _reasonLabel(BuildContext context, String? reason) {
    if (reason == null) {
      return '';
    }
    final l10n = AppLocalizations.of(context);
    return switch (reason) {
      'unchanged' => l10n.organizeReasonUnchanged,
      'targetExists' || 'duplicateTarget' => l10n.organizeReasonTargetExists,
      'missingFile' => l10n.organizeReasonMissingFile,
      'missingPath' => l10n.organizeReasonMissingPath,
      'outsideLibrary' => l10n.organizeReasonOutsideLibrary,
      'fileProvider' => l10n.organizeReasonFileProvider,
      'pathTooLong' => l10n.organizeReasonPathTooLong,
      'targetIsFolder' => l10n.organizeReasonTargetIsFolder,
      'invalidTemplate' => l10n.organizeReasonInvalidTemplate,
      _ => reason,
    };
  }

  Widget _changeRow(
    BuildContext context,
    AppLocalizations l10n,
    OrganizeItem item,
  ) {
    final textColor = colorManager.getSpecificTextColor();
    final kind = _outcomeOf(item);
    final statusColor = switch (kind) {
      OrganizeOutcomeKind.organized => textColor,
      OrganizeOutcomeKind.skipped => textColor.withAlpha(150),
      OrganizeOutcomeKind.pending => textColor,
      OrganizeOutcomeKind.conflict ||
      OrganizeOutcomeKind.blocked ||
      OrganizeOutcomeKind.failed => Colors.red,
    };
    final reason = _reasonLabel(context, item.reason);
    final oldName = item.oldPath.isEmpty ? '' : p.basename(item.oldPath);
    final newName = item.newPath == null ? '' : p.basename(item.newPath!);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  oldName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor.withAlpha(150),
                  ),
                ),
                if (item.status == OrganizeStatus.normal ||
                    item.status == OrganizeStatus.conflict)
                  Text(
                    newName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, color: statusColor),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _outcomeLabel(l10n, kind),
                style: TextStyle(fontSize: 12, color: statusColor),
              ),
              if (reason.isNotEmpty)
                Text(
                  reason,
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor.withAlpha(200),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context, AppLocalizations l10n) {
    final result = _result;
    if (result == null) {
      return const SizedBox.shrink();
    }
    final textColor = colorManager.getSpecificTextColor();
    final canUndo = LibraryOrganizer.instance.canUndo;
    final outcomes = <OrganizeOutcome>[
      for (final item in _preview?.items ?? const <OrganizeItem>[])
        OrganizeOutcome(
          directory: _directoryOf(item),
          kind: _outcomeOf(item),
        ),
    ];
    final summaries = summarizeOrganizeOutcomes(outcomes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        appleSectionTitle(l10n.organizeComplete),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Text(
            result.stopped
                ? l10n.organizeStopped(result.moved)
                : l10n.organizeResultMessage(
                    result.moved,
                    result.skipped,
                    result.failed,
                  ),
            style: TextStyle(fontSize: 13, color: textColor.withAlpha(170)),
          ),
        ),
        if (summaries.isNotEmpty)
          AppleFormSection(
            children: [
              for (final summary in summaries)
                ListTile(
                  dense: true,
                  leading: Icon(Icons.album_outlined, color: iconColor.value),
                  title: Text(
                    summary.directory.isEmpty
                        ? l10n.noData
                        : p.basename(summary.directory),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    _summaryCounts(l10n, summary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withAlpha(150),
                    ),
                  ),
                  trailing: Text(
                    '${summary.total}',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withAlpha(160),
                    ),
                  ),
                ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: canUndo
              ? TextButton(
                  onPressed: _undoing ? null : _undo,
                  child: Text(l10n.undoOrganize),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  String? _directoryOf(OrganizeItem item) {
    if (item.newPath != null && item.newPath!.isNotEmpty) {
      return p.dirname(item.newPath!);
    }
    if (item.oldPath.isNotEmpty) {
      return p.dirname(item.oldPath);
    }
    return null;
  }

  String _summaryCounts(AppLocalizations l10n, AlbumOrganizeSummary summary) {
    final parts = <String>[
      if (summary.organized > 0)
        '${l10n.organizeDone} ${summary.organized}',
      if (summary.skipped > 0) '${l10n.organizeSkip} ${summary.skipped}',
      if (summary.conflict > 0)
        '${l10n.organizeConflict} ${summary.conflict}',
      if (summary.blocked > 0) '${l10n.organizeBlocked} ${summary.blocked}',
      if (summary.failed > 0) '${l10n.organizeFailed} ${summary.failed}',
      if (summary.pending > 0) '${l10n.organizePending} ${summary.pending}',
    ];
    return parts.join(' · ');
  }
}

class _ProgressDialog extends StatelessWidget {
  final ValueNotifier<(int, int)> progress;
  final VoidCallback onStop;

  const _ProgressDialog({required this.progress, required this.onStop});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: 300,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.organizing,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorManager.getSpecificTextColor(),
              ),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<(int, int)>(
              valueListenable: progress,
              builder: (context, value, child) {
                return Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text('${value.$1} / ${value.$2}'),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onStop, child: Text(l10n.stop)),
          ],
        ),
      ),
    );
  }
}
