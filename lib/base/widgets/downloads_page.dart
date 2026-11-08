import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/download_manager.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/utils/source_type.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';

/// What the user has downloaded: which server each file came from, where it is,
/// how big it is - and a way to drop it again.
class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  @override
  void initState() {
    super.initState();
    downloadManager.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // A pushed page: composite the translucent panel colour into an opaque one.
    return Scaffold(
      backgroundColor: colorManager.getSpecificOpaqueBgColor(),
      body: SafeArea(
        child: Column(
          children: [
            _header(l10n),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: downloadsNotifier,
                builder: (context, items, child) {
                  if (items.isEmpty) {
                    return Center(child: Text(l10n.noDownloads));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 30),
                    itemCount: items.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _folderLine(l10n);
                      }
                      return _row(items[index - 1], l10n);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(AppLocalizations l10n) {
    final textColor = colorManager.getSpecificTextColor();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              l10n.downloads,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  /// Where the files live, so they can be found in a file manager.
  Widget _folderLine(AppLocalizations l10n) {
    final textColor = colorManager.getSpecificTextColor();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Text(
        Platform.isAndroid
            ? 'Download/$downloadFolderName'
            : '${downloadFolderName}',
        style: TextStyle(fontSize: 12, color: textColor.withAlpha(160)),
      ),
    );
  }

  Widget _row(DownloadedSong item, AppLocalizations l10n) {
    final textColor = colorManager.getSpecificTextColor();
    final sourceType = item.sourceType;
    final size = '${(item.bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    final time =
        '${item.time.year}-'
        '${item.time.month.toString().padLeft(2, '0')}-'
        '${item.time.day.toString().padLeft(2, '0')}';

    return ListTile(
      leading: SizedBox(
        width: 40,
        child: Center(
          child: sourceType == null
              ? Icon(Icons.cloud_outlined, size: 22, color: textColor)
              : ImageIcon(getSourceTypeImage(sourceType), size: 26),
        ),
      ),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 15, color: textColor),
      ),
      subtitle: Text(
        [
          if (item.artist.isNotEmpty) item.artist,
          if (sourceType != null) getSourceTypeDisplayName(l10n, sourceType),
          time,
          size,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: textColor.withAlpha(160)),
      ),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline, size: 20, color: textColor),
        onPressed: () async {
          if (!await showConfirmDialog(context, item.fileName)) {
            return;
          }
          await downloadManager.delete(item);
        },
      ),
    );
  }
}