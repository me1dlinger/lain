import 'package:material_ui/material_ui.dart';
import 'package:lain/base/data/loader.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/services/sync_preview.dart';
import 'package:lain/base/widgets/apple_form.dart';
import 'package:lain/base/widgets/local_music_page.dart';
import 'package:lain/l10n/generated/app_localizations.dart';

class SyncPreviewPage extends StatefulWidget {
  const SyncPreviewPage({super.key});

  @override
  State<SyncPreviewPage> createState() => _SyncPreviewPageState();
}

class _SyncPreviewPageState extends State<SyncPreviewPage> {
  SyncPreview? _preview;
  bool _loading = true;
  bool _applying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final preview = await syncPreviewService.build();
      if (mounted) {
        setState(() {
          _preview = preview;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preview = _preview;
    return opaqueSettingsPage(
      context: context,
      title: l10n.syncPreview,
      actions: [
        if (preview?.hasChanges == true)
          TextButton(
            onPressed: _applying ? null : _apply,
            child: Text(l10n.syncPreviewApply),
          ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorManager.getSpecificTextColor().withAlpha(150),
                  ),
                ),
              ),
            )
          : _content(context, l10n, preview!),
    );
  }

  Widget _content(
    BuildContext context,
    AppLocalizations l10n,
    SyncPreview preview,
  ) {
    final textColor = colorManager.getSpecificTextColor();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        if (!preview.hasChanges)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                l10n.syncPreviewSafe,
                style: TextStyle(fontSize: 14, color: textColor.withAlpha(150)),
              ),
            ),
          )
        else ...[
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.6,
            children: [
              _tile(l10n.syncPreviewAdded, preview.added, textColor),
              _tile(l10n.syncPreviewRemoved, preview.removed, textColor),
              _tile(l10n.syncPreviewChanged, preview.changed, textColor),
              _tile(l10n.syncPreviewUnchanged, preview.unchanged, textColor),
            ],
          ),
          if (preview.removed > 0) ...[
            appleSectionTitle(l10n.syncPreviewCacheImpact),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
              child: Text(
                '${l10n.syncPreviewCacheImpact}: ${preview.cachedRemoved} · '
                '${l10n.syncPreviewPlaylistImpact}: ${preview.playlistRefs}',
                style: TextStyle(fontSize: 13, color: textColor.withAlpha(155)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
              child: Text(
                l10n.syncPreviewWarn,
                style: TextStyle(fontSize: 12, color: textColor.withAlpha(135)),
              ),
            ),
          ],
          if (preview.addedSamples.isNotEmpty) ...[
            appleSectionTitle(l10n.syncPreviewAdded),
            for (final item in preview.addedSamples.take(30))
              _sampleRow(item, textColor, Icons.add_rounded),
          ],
          if (preview.removedSamples.isNotEmpty) ...[
            appleSectionTitle(l10n.syncPreviewRemoved),
            for (final item in preview.removedSamples.take(30))
              _sampleRow(item, textColor, Icons.remove_rounded),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _applying ? null : _apply,
            icon: const Icon(Icons.sync_rounded, size: 20),
            label: Text(l10n.syncPreviewApply),
          ),
        ],
      ],
    );
  }

  Widget _tile(String label, int value, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: textColor.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: textColor.withAlpha(170)),
            ),
          ),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sampleRow(SyncPreviewItem item, Color textColor, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textColor.withAlpha(130)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: textColor),
                ),
                if (item.path.isNotEmpty)
                  Text(
                    item.path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: textColor.withAlpha(110),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _apply() async {
    if (Loader.busy) {
      showCenterMessage(AppLocalizations.of(context).syncingTryLater);
      return;
    }
    setState(() => _applying = true);
    final ok = await Loader.sync();
    if (!mounted) {
      return;
    }
    setState(() => _applying = false);
    showCenterMessage(
      ok
          ? AppLocalizations.of(context).syncDone
          : AppLocalizations.of(context).syncFailed,
    );
    if (ok) {
      Navigator.pop(context);
    }
  }
}
