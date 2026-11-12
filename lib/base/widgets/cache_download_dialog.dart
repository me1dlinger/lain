import 'package:material_ui/material_ui.dart';

import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/cache_download_manager.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/l10n/generated/app_localizations.dart';
import 'package:smooth_corner/smooth_corner.dart';

/// Starts caching [songs] and shows a progress window for it.
///
/// The window is deliberately modal instead of the old global spinner: back and
/// the gesture bar ask whether to cancel or let the task continue in the
/// background, and choosing background closes the window while the downloads
/// keep going.
Future<void> showCacheDownloadDialog(
  BuildContext context,
  Iterable<MyAudioMetadata> songs,
) async {
  final l10n = AppLocalizations.of(context);
  final manager = cacheDownloadManager;

  final list = songs.where((song) => !song.cacheExist).toList();
  if (list.isEmpty) {
    showCenterMessage(l10n.cacheEmpty);
    return;
  }
  if (manager.isRunning) {
    showCenterMessage(l10n.cacheTaskBusy);
    return;
  }

  final task = manager.start(list);
  if (!manager.isRunning) {
    showCenterMessage(l10n.cacheEmpty);
    return;
  }

  final result = await showAnimationDialog<String>(
    context: context,
    barrierDismissible: false,
    child: _CacheDownloadDialog(l10n: l10n),
  );

  // Null means the route went away without an answer (for example the app was
  // rebuilt): stop it rather than leave a task with no window owning it.
  if (result == null || result == 'canceled') {
    manager.cancel();
    await task;
    if (result == null) {
      return;
    }
    showCenterMessage(l10n.cacheTaskCanceled);
    return;
  }

  if (result == 'background') {
    showCenterMessage(l10n.cacheMovedToBackground);
  }

  await task;
  final progress = manager.notifier.value;
  showCenterMessage(
    progress.failed > 0
        ? '${l10n.cacheTaskDone} · ${l10n.cacheFailedCount(progress.failed)}'
        : l10n.cacheTaskDone,
  );
}

class _CacheDownloadDialog extends StatefulWidget {
  final AppLocalizations l10n;

  const _CacheDownloadDialog({required this.l10n});

  @override
  State<_CacheDownloadDialog> createState() => _CacheDownloadDialogState();
}

class _CacheDownloadDialogState extends State<_CacheDownloadDialog> {
  bool _askingBack = false;
  bool _closing = false;
  bool _finishScheduled = false;

  @override
  void initState() {
    super.initState();
    cacheDownloadManager.notifier.addListener(_onProgress);
  }

  @override
  void dispose() {
    cacheDownloadManager.notifier.removeListener(_onProgress);
    super.dispose();
  }

  void _onProgress() {
    if (!mounted || _closing) {
      return;
    }
    final progress = cacheDownloadManager.notifier.value;
    if (!progress.isRunning) {
      _finish(progress.phase == CacheTaskPhase.canceled ? 'canceled' : 'done');
      return;
    }
    setState(() {});
  }

  void _finish(String result) {
    if (_closing) {
      return;
    }
    _closing = true;
    Navigator.of(context).pop(result);
  }

  void _cancel() {
    cacheDownloadManager.cancel();
    _finish('canceled');
  }

  void _background() => _finish('background');

  void _onBack() {
    if (_closing) {
      return;
    }
    // Back while the question is already showing means "keep waiting"; this
    // avoids a second dialog and an accidental cancellation.
    setState(() => _askingBack = !_askingBack);
  }

  @override
  Widget build(BuildContext context) {
    final progress = cacheDownloadManager.notifier.value;
    if (!progress.isRunning && !_closing && !_finishScheduled) {
      // Completed before the dialog was first built.
      _finishScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_closing) {
          _finish(
            progress.phase == CacheTaskPhase.canceled ? 'canceled' : 'done',
          );
        }
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _onBack();
        }
      },
      child: SizedBox(
        width: 330,
        child: Material(
          shape: SmoothRectangleBorder(
            smoothness: 1,
            borderRadius: BorderRadius.circular(10),
          ),
          color: Color.alphaBlend(
            colorManager.getSpecificBgColor(),
            colorManager.getSpecificBgBaseColor(),
          ),
          clipBehavior: Clip.antiAliasWithSaveLayer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.l10n.cacheTaskTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (!_askingBack)
                  ..._progressContent(progress)
                else
                  _backPrompt(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _progressContent(CacheTaskProgress progress) {
    final counts = StringBuffer('${progress.done} / ${progress.total}');
    if (progress.failed > 0) {
      counts.write(' · ${widget.l10n.cacheFailedCount(progress.failed)}');
    }
    return [
      LinearProgressIndicator(value: progress.fraction),
      const SizedBox(height: 8),
      Text(counts.toString(), style: const TextStyle(fontSize: 12)),
      const SizedBox(height: 14),
      Wrap(
        alignment: WrapAlignment.end,
        spacing: 4,
        children: [
          TextButton(onPressed: _cancel, child: Text(widget.l10n.cancel)),
          TextButton(
            onPressed: _background,
            child: Text(widget.l10n.cacheBackground),
          ),
        ],
      ),
    ];
  }

  Widget _backPrompt() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.l10n.cacheBackPrompt, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 4,
          runSpacing: 4,
          children: [
            TextButton(
              onPressed: () => setState(() => _askingBack = false),
              child: Text(widget.l10n.cacheKeepRunning),
            ),
            TextButton(onPressed: _cancel, child: Text(widget.l10n.cancel)),
            TextButton(
              onPressed: _background,
              child: Text(widget.l10n.cacheBackground),
            ),
          ],
        ),
      ],
    );
  }
}
