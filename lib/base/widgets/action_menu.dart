import 'package:material_ui/material_ui.dart';
import 'package:lain/base/my_audio_metadata.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/base/widgets/my_sheet.dart';
import 'package:lain/base/widgets/quality_badge.dart';
import 'package:lain/base/utils/metadata_utils.dart';

/// The options of a song, or of the now-playing page, as one sheet: a title
/// with a close button, a song card, and a single rounded card of actions.
///
/// The colours and the card material come from the theme; only the layout is
/// shared, so a light, dark or vivid theme keeps its own look.
class ActionMenuSheet extends StatelessWidget {
  final String title;
  final Widget? info;
  final List<Widget> actions;
  final VoidCallback? onClose;

  const ActionMenuSheet({
    super.key,
    required this.title,
    required this.actions,
    this.info,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = colorManager.getSpecificTextColor();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              if (onClose != null) _closeButton(textColor, onClose!),
            ],
          ),
        ),
        if (info != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: info!,
          ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Container(
              decoration: BoxDecoration(
                color: textColor.withAlpha(12),
                borderRadius: BorderRadius.circular(18),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: actions,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _closeButton(Color textColor, VoidCallback onTap) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: textColor.withAlpha(18),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Icon(Icons.close_rounded, size: 20, color: textColor),
        ),
      ),
    );
  }
}

/// The song card at the top of an action sheet: cover, title, quality and the
/// artist - album line, with an optional copy action.
class SongMenuInfo extends StatelessWidget {
  final MyAudioMetadata song;
  final VoidCallback? onCopy;

  const SongMenuInfo({super.key, required this.song, this.onCopy});

  @override
  Widget build(BuildContext context) {
    final textColor = colorManager.getSpecificTextColor();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: textColor.withAlpha(14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CoverArtWidget(
            size: 58,
            borderRadius: 8,
            picture: song.picture,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  getTitle(song),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    QualityBadge(song: song),
                    Flexible(
                      child: Text(
                        '${getArtist(song)} · ${getAlbum(song)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor.withAlpha(160),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onCopy != null)
            IconButton(
              onPressed: onCopy,
              icon: Icon(
                Icons.copy_all_outlined,
                size: 22,
                color: colorManager.getSpecificIconColor(),
              ),
            ),
        ],
      ),
    );
  }
}

/// One action in the card. The rows have no dividers: the spacing and the
/// rounded card are what group them, as in the reference layout.
class ActionMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const ActionMenuTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = colorManager.getSpecificTextColor();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: colorManager.getSpecificIconColor(),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 16, color: textColor),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: textColor.withAlpha(150),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// A quiet heading between action groups inside the card.
class ActionMenuSectionTitle extends StatelessWidget {
  final String title;

  const ActionMenuSectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final textColor = colorManager.getSpecificTextColor();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textColor.withAlpha(140),
          ),
        ),
      ),
    );
  }
}

/// Shows [content] as a tall bottom sheet with the usual rounded top.
Future<void> showActionMenuSheet(
  BuildContext context,
  Widget content, {
  double maxHeightFactor = 0.86,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (context) => MySheet(
      content,
      maxHeightFactor: maxHeightFactor,
      wrapContent: true,
    ),
  );
}
