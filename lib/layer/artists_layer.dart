import 'package:material_ui/material_ui.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/data/artist_album.dart';
import 'package:lain/base/data/setting.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/widgets/collection_list.dart';
import 'package:lain/l10n/generated/app_localizations.dart';
import 'package:lain/layer/layers_manager.dart';
import 'package:lain/base/asset_images.dart';

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
    // Shuffled order is not offered for artists; see the album list.
    currentPictureList = list.map((e) => e.picture).toList();
    // A singer without an artist image uses one of their album covers; the
    // music note is never shown.
    currentFallbackPictureList = list.map((e) => e.albumCoverPicture).toList();
    currentTextList = list.map((e) => e.name).toList();
    currentOnTapList = list
        .map(
          (e) => () {
            // No waiting for the artwork: an artist whose cover has not loaded
            // (or has none) still opens.
            layersManager.pushDetail('artists', e);
          },
        )
        .toList();
    // Long-pressing an avatar drops that artist's cached biography and image
    // and fetches them again. Only Navidrome can refresh an artist image; the
    // other sources have nothing to ask.
    final l10n = AppLocalizations.of(context);
    currentOnLongPressList = sourceType == .navidrome
        ? list
              .map(
                (e) => () async {
                  vibrateGestureFeedback();
                  final hasImage = await refreshArtistCache(e);
                  updateCurrentList();
                  showCenterMessage(
                    hasImage
                        ? l10n.artistCacheRefreshed
                        : l10n.artistCacheNoImage,
                  );
                },
              )
              .toList()
        : null;

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
