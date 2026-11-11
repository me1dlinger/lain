import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:sylvakru/base/widgets/collection_list.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/layer/layers_manager.dart';

final GlobalKey<NavigatorState> albumsKey = GlobalKey();
final albumsVisibleNotifier = ValueNotifier(true);

class AlbumsLayer extends CollectionList {
  const AlbumsLayer({super.key});

  @override
  State<StatefulWidget> createState() => _AlbumsLayerState();
}

class _AlbumsLayerState extends CollectionListState {
  @override
  GlobalKey<NavigatorState> get globalKey => albumsKey;

  @override
  ValueNotifier<bool> get visibleNotifier => albumsVisibleNotifier;

  @override
  AssetImage get image => albumImage;

  @override
  String Function(int) get countFunction =>
      AppLocalizations.of(context).albumCount;

  @override
  String get label => 'albums';

  @override
  void updateCurrentList() {
    preparing = !artistAlbumManager.done;

    final value = textController.text;
    final list = artistAlbumManager.albumList
        .where((e) => (e.name.toLowerCase().contains(value.toLowerCase())))
        .toList();
    // Shuffled order is not offered for albums: the list has its own orders and
    // a random one there is not useful.
    currentPictureList = list.map((e) => e.picture).toList();
    currentTextList = list.map((e) => e.name).toList();

    currentOnTapList = list
        .map(
          (e) => () {
            // No waiting for the artwork; see the artist list.
            layersManager.pushDetail('albums', e);
          },
        )
        .toList();
    changeNotifier.value++;
  }

  @override
  void initState() {
    super.initState();

    randomizeNotifier = artistAlbumManager.getRandomizeNotifier(false);
    isAscendingNotifier = artistAlbumManager.getIsAscendingNotifier(false);
    useLargePictureNotifier = artistAlbumManager.getUseLargePictureNotifier(
      false,
    );
    sortKeyNotifier = albumsSortKeyNotifier;
    sortKeyOptions = () {
      final l10n = AppLocalizations.of(context);
      return [
        (l10n.sortByName, 0),
        (l10n.sortByAddedTime, 1),
        (l10n.sortByPlayCount, 2),
        (l10n.sortBySize, 3),
        (l10n.sortByYear, 4),
        (l10n.sortByFavorite, 5),
      ];
    };

    updateCurrentList();

    artistAlbumManager.updateNotifier.addListener(updateCurrentList);
  }

  @override
  void dispose() {
    artistAlbumManager.updateNotifier.removeListener(updateCurrentList);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    title = l10n.albums;
    searchHint = l10n.searchAlbums;
    return super.build(context);
  }
}
