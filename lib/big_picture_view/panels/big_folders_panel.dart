import 'package:material_ui/material_ui.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:lain/base/data/library.dart';
import 'package:lain/base/services/picture_service.dart';
import 'package:lain/base/utils/media_query.dart';
import 'package:lain/base/utils/zoom_page_route.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/big_picture_view/panels/big_single_folder_panel.dart';

class BigFoldersPanel extends StatefulWidget {
  const BigFoldersPanel({super.key});

  @override
  State<StatefulWidget> createState() => _BigFoldersPanelState();
}

class _BigFoldersPanelState extends State<BigFoldersPanel> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: isTooNarrow(context) ? 20 : 40,
        vertical: 75 + getTopOffset(context),
      ),
      itemCount: library.folderList.length,
      itemBuilder: (_, index) {
        final folder = library.folderList[index];
        return ValueListenableBuilder(
          valueListenable: folder.changeNotifier,
          builder: (context, value, child) {
            final cover = folder.picture;
            return SizedBox(
              height: 120,
              child: InkWell(
                customBorder: SmoothRectangleBorder(
                  smoothness: 1,
                  borderRadius: BorderRadius.circular(15),
                ),
                mouseCursor: SystemMouseCursors.click,
                child: Row(
                  children: [
                    SizedBox(width: 20),
                    ListenableBuilder(
                      listenable: Listenable.merge([cover?.changeNotifier]),
                      builder: (_, _) {
                        return Hero(
                          tag: 'big${cover?.id}${folder.id}',
                          child: CoverArtWidget(
                            size: 100,
                            borderRadius: 10,
                            picture: cover,
                          ),
                        );
                      },
                    ),
                    SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        folder.id,
                        style: TextStyle(overflow: .ellipsis),
                      ),
                    ),
                  ],
                ),
                onTap: () async {
                  final baseColor = await computeColor(
                    folder.picture,
                  );
                  if (!context.mounted) {
                    return;
                  }
                  Navigator.of(context).push(
                    ZoomPageRoute(
                      builder: (context) {
                        return BigSingleFolderPanel(
                          folder: folder,
                          baseColor: baseColor,
                        );
                      },
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
