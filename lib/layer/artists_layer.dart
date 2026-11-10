import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:sylvakru/base/widgets/collection_list.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/base/asset_images.dart';

final GlobalKey<NavigatorState> artistsKey = GlobalKey();
final artistsVisibleNotifier = ValueNotifier(true);

class ArtistsLayer extends CollectionList {
  const ArtistsLayer({super.key});

  @override
  State<StatefulWidget> createState() => _ArtistsLayerState();
}

class _ArtistsLayerState extends CollectionListState {
  @override
  GlobalKey<NavigatorState> get globalKey => artistsKey;

  @override
  ValueNotifier<bool> get visibleNotifier => artistsVisibleNotifier;

  @override
  AssetImage get image => artistImage;

  @override
  String Function(int) get countFunction =>
      AppLocalizations.of(context).artistCount;

  @override
  String get label => 'artists';

  @override
  void updateCurrentList() {
    preparing = !artistAlbumManager.done;

    final value = textController.text;
    final list = artistAlbumManager.artistList
        .where((e) => (e.name.toLowerCase().contains(value.toLowerCase())))
        .toList();
    if (randomizeNotifier!.value) {
      list.shuffle();
    }
    currentPictureList = list.map((e) => e.picture).toList();
    currentTextList = list.map((e) => e.name).toList();
    // List view carries what the list of artists actually knows: how many
    // albums and songs each has, and how often they were played.
    final l10n = AppLocalizations.of(context);
    currentSubtitleList = list.map((e) {
      final parts = <String>[
        if (e.albumCount > 0) l10n.albumCount(e.albumCount),
        l10n.songCount(e.songList.length),
        if (e.playCount > 0) '${e.playCount} ${l10n.times}',
      ];
      return parts.join(' · ');
    }).toList();
    currentOnTapList = list
        .map(
          (e) => () {
            if (e.picture.isLoaded) {
              layersManager.pushDetail('artists', e);
            }
          },
        )
        .toList();

    changeNotifier.value++;
  }

  @override
  void initState() {
    super.initState();

    randomizeNotifier = artistAlbumManager.getRandomizeNotifier(true);
    isAscendingNotifier = artistAlbumManager.getIsAscendingNotifier(true);
    useLargePictureNotifier = artistAlbumManager.getUseLargePictureNotifier(
      true,
    );

    isListViewNotifier = artistsIsListViewNotifier;

    sortKeyNotifier = artistsSortKeyNotifier;
    sortKeyOptions = () {
      final l10n = AppLocalizations.of(context);
      return [
        (l10n.sortByName, 0),
        (l10n.sortByAlbumCount, 1),
        (l10n.sortBySongCount, 2),
        (l10n.sortBySize, 3),
        (l10n.sortByPlayCount, 4),
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
    title = l10n.artists;
    searchHint = l10n.searchArtists;
    return super.build(context);
  }
}
