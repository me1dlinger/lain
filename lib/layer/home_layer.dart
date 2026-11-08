import 'dart:async';
import 'dart:math';

import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/data/history.dart';
import 'package:sylvakru/base/data/home_layout.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/utils/media_query.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/widgets/my_navigator.dart';
import 'package:sylvakru/base/widgets/my_scaffold.dart';
import 'package:sylvakru/base/widgets/play_next_button.dart';
import 'package:sylvakru/base/widgets/stats_page.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/landscape_view/title_bar.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/layer/lyrics_page_layer.dart';
import 'package:sylvakru/portrait_view/my_search_field.dart';

part '../landscape_view/panels/home_panel.dart';
part '../portrait_view/pages/home_page.dart';

final GlobalKey<NavigatorState> homeKey = GlobalKey();
final homeVisibleNotifier = ValueNotifier(true);

class HomeLayer extends StatefulWidget {
  const HomeLayer({super.key});

  @override
  State<StatefulWidget> createState() => HomeLayerState();
}

class HomeLayerState extends State<HomeLayer> {
  final albumsSC = ScrollController();
  final frequentlySC = ScrollController();
  final recentlySC = ScrollController();
  final recentlyAddedSC = ScrollController();
  final playlistsSC = ScrollController();

  final albumsDisplayIconNotifier = ValueNotifier(false);
  final frequentlyDisplayIconNotifier = ValueNotifier(false);
  final recentlyDisplayIconNotifier = ValueNotifier(false);
  final recentlyAddedDisplayIconNotifier = ValueNotifier(false);
  final playlistsDisplayIconNotifier = ValueNotifier(false);

  final albumsChangeNotifier = ValueNotifier(0);
  final frequentlyChangeNotifier = ValueNotifier(0);
  final recentlyChangeNotifier = ValueNotifier(0);
  final recentlyAddedChangeNotifier = ValueNotifier(0);
  final playlistsChangeNotifier = ValueNotifier(0);

  final textController = TextEditingController();
  final searchChangeNotifier = ValueNotifier(0);

  Timer? searchTimer;

  String get searchValue => textController.text;

  @override
  void initState() {
    super.initState();
    textController.addListener(onSearchChanged);
  }

  void onSearchChanged() {
    searchTimer?.cancel();
    searchTimer = Timer(Duration(milliseconds: 300), () {
      for (final scrollController in [
        albumsSC,
        frequentlySC,
        recentlySC,
        playlistsSC,
      ]) {
        if (scrollController.hasClients) {
          scrollController.jumpTo(0);
        }
      }
      albumsChangeNotifier.value++;
      frequentlyChangeNotifier.value++;
      recentlyChangeNotifier.value++;
      playlistsChangeNotifier.value++;
      searchChangeNotifier.value++;
    });
  }

  @override
  void dispose() {
    searchTimer?.cancel();
    textController.dispose();
    searchChangeNotifier.dispose();
    albumsSC.dispose();
    frequentlySC.dispose();
    recentlySC.dispose();
    playlistsSC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return myNavigator(
      key: homeKey,
      visibleNotifier: homeVisibleNotifier,
      pageViewBuilder: () => pageView(context),
      panelViewBuilder: () => panelView(context),
    );
  }

  Widget content(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    double extraSize = max(0, (shortestSide - 750) * 0.2);

    // Which blocks the home page draws, and in which order, is the user's
    // choice (settings -> home layout), so the page follows that list.
    return ListenableBuilder(
      listenable: Listenable.merge([
        homeButtonOrder,
        homeButtonHidden,
        homeShelfOrder,
        homeShelfHidden,
      ]),
      builder: (context, child) {
        return ListView(
          children: [
            if (visibleHomeButtons.isNotEmpty) hubRow(context),

            for (final shelf in visibleHomeShelves)
              ...shelfBlock(shelf, context, extraSize),

            if (isTooNarrow(context)) SizedBox(height: 60),
          ],
        );
      },
    );
  }

  /// The row of buttons at the very top. It spreads them across the page when
  /// they fit and scrolls sideways when the user kept more of them than fit,
  /// rather than overflowing.
  Widget hubRow(BuildContext context) {
    return SizedBox(
      height: 84,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth - 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final button in visibleHomeButtons)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: homeNavButtonFor(button, context),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget homeNavButtonFor(HomeButton button, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (button) {
      case HomeButton.artists:
        return homeNavButton(
          l10n.artists,
          Icons.person_outline_rounded,
          'artists',
        );
      case HomeButton.albums:
        return homeNavButton(l10n.albums, Icons.album_outlined, 'albums');
      case HomeButton.songs:
        return homeNavButton(l10n.songs, Icons.music_note_outlined, 'songs');
      case HomeButton.playlists:
        return homeNavButton(
          l10n.playlists,
          Icons.queue_music_rounded,
          'playlists',
        );
      case HomeButton.favorites:
        return homeNavButton(
          l10n.favorites,
          Icons.favorite_outline_rounded,
          '_Favorite',
        );
      case HomeButton.listeningReport:
        return homeNavAction(l10n.listeningReport, Icons.insights_rounded, () {
          globalNavigatorKey.currentState?.push(
            MaterialPageRoute(builder: (context) => const StatsPage()),
          );
        });
    }
  }

  /// One shelf: the heading that opens its full list, and the list itself.
  List<Widget> shelfBlock(
    HomeShelf shelf,
    BuildContext context,
    double extraSize,
  ) {
    final l10n = AppLocalizations.of(context);
    switch (shelf) {
      case HomeShelf.albums:
        return [
          Row(
            mainAxisSize: .min,
            children: [
              SizedBox(width: 20),
              GestureDetector(
                onTap: () {
                  layersManager.switchRootLayer('albums');
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Row(
                    children: [
                      Text(
                        l10n.albums,
                        style: .new(fontWeight: .bold, fontSize: 20),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),

          mouseRegionForScroll(
            child: SizedBox(
              height: 180 + extraSize,
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  artistAlbumManager.updateNotifier,
                  searchChangeNotifier,
                ]),
                builder: (context, child) {
                  final lowerValue = searchValue.toLowerCase();
                  final albumList = searchValue.isEmpty
                      ? artistAlbumManager.albumList
                      : artistAlbumManager.albumList
                            .where(
                              (album) =>
                                  album.name.toLowerCase().contains(lowerValue),
                            )
                            .toList();
                  return ListView.separated(
                    controller: albumsSC,
                    scrollDirection: .horizontal,
                    itemCount: albumList.length + 1,
                    separatorBuilder: (context, index) {
                      return SizedBox(width: 15);
                    },
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return SizedBox(width: 5);
                      }
                      index--;
                      final album = albumList[index];
                      return Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              layersManager.pushDetail('home', album);
                            },
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Hero(
                                tag: '${album.picture.id}home${album.name}',
                                transitionOnUserGestures: true,
                                child: CoverArtWidget(
                                  size: 150 + extraSize,
                                  borderRadius: 15,
                                  picture: album.picture,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 5),
                          SizedBox(
                            width: 140 + extraSize,
                            child: Text(
                              album.name,
                              style: .new(overflow: .ellipsis, fontSize: 15),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            scrollController: albumsSC,
            displayIconNotifier: albumsDisplayIconNotifier,
            changeNotifier: albumsChangeNotifier,
            iconTop: 55 + extraSize / 2,
          ),

          SizedBox(height: 15),
        ];
      case HomeShelf.frequently:
        return [
          Row(
            mainAxisSize: .min,
            children: [
              SizedBox(width: 20),
              GestureDetector(
                onTap: () {
                  layersManager.switchRootLayer('frequently');
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Row(
                    children: [
                      Text(
                        l10n.frequently,
                        style: .new(fontWeight: .bold, fontSize: 20),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),

          mouseRegionForScroll(
            child: ListenableBuilder(
              listenable: Listenable.merge([
                history.frequentlyChangeNotifier,
                searchChangeNotifier,
              ]),
              builder: (context, child) {
                return songListView(
                  filterSongList(history.frequentlySongList, searchValue),
                  frequentlySC,
                );
              },
            ),
            scrollController: frequentlySC,
            displayIconNotifier: frequentlyDisplayIconNotifier,
            changeNotifier: frequentlyChangeNotifier,
            iconTop: 67,
          ),

          SizedBox(height: 15),
        ];
      case HomeShelf.recentlyAdded:
        return [
          Row(
            mainAxisSize: .min,
            children: [
              SizedBox(width: 20),
              GestureDetector(
                onTap: () {
                  layersManager.switchRootLayer('recentlyAdded');
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Row(
                    children: [
                      Text(
                        l10n.recentlyAdded,
                        style: .new(fontWeight: .bold, fontSize: 20),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),

          mouseRegionForScroll(
            child: ListenableBuilder(
              listenable: Listenable.merge([
                library.changeNotifier,
                searchChangeNotifier,
              ]),
              builder: (context, child) {
                return songListView(
                  filterSongList(library.recentlyAddedSongList, searchValue),
                  recentlyAddedSC,
                );
              },
            ),
            scrollController: recentlyAddedSC,
            displayIconNotifier: recentlyAddedDisplayIconNotifier,
            changeNotifier: recentlyAddedChangeNotifier,
            iconTop: 67,
          ),

          SizedBox(height: 15),
        ];
      case HomeShelf.recently:
        return [
          Row(
            mainAxisSize: .min,
            children: [
              SizedBox(width: 20),
              GestureDetector(
                onTap: () {
                  layersManager.switchRootLayer('recently');
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Row(
                    children: [
                      Text(
                        l10n.recently,
                        style: .new(fontWeight: .bold, fontSize: 20),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),

          mouseRegionForScroll(
            child: ListenableBuilder(
              listenable: Listenable.merge([
                history.recentlyChangeNotifier,
                searchChangeNotifier,
              ]),
              builder: (context, child) {
                return songListView(
                  filterSongList(history.recentlySongList, searchValue),
                  recentlySC,
                );
              },
            ),
            scrollController: recentlySC,
            displayIconNotifier: recentlyDisplayIconNotifier,
            changeNotifier: frequentlyChangeNotifier,
            iconTop: 67,
          ),

          SizedBox(height: 15),
        ];
      case HomeShelf.playlists:
        return [
          Row(
            mainAxisSize: .min,
            children: [
              SizedBox(width: 20),
              GestureDetector(
                onTap: () {
                  layersManager.switchRootLayer('playlists');
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Row(
                    children: [
                      Text(
                        l10n.playlists,
                        style: .new(fontWeight: .bold, fontSize: 20),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),

          mouseRegionForScroll(
            child: SizedBox(
              height: 180 + extraSize,
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  playlistManager.updateNotifier,
                  searchChangeNotifier,
                ]),
                builder: (context, child) {
                  final lowerValue = searchValue.toLowerCase();
                  final playlists = searchValue.isEmpty
                      ? playlistManager.playlists
                      : playlistManager.playlists
                            .where(
                              (playlist) => (playlist.isFavorite
                                      ? l10n.favorites
                                      : playlist.name)
                                  .toLowerCase()
                                  .contains(lowerValue),
                            )
                            .toList();
                  return ListView.separated(
                    controller: playlistsSC,
                    scrollDirection: .horizontal,
                    itemCount: playlists.length + 1,
                    separatorBuilder: (context, index) {
                      return SizedBox(width: 15);
                    },
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return SizedBox(width: 5);
                      }
                      index--;
                      final playlist = playlists[index];
                      return ValueListenableBuilder(
                        valueListenable: playlist.changeNotifier,
                        builder: (context, value, child) {
                          return Column(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  layersManager.pushDetail('home', playlist);
                                },
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: Hero(
                                    tag:
                                        '${playlist.picture?.id ?? ''}home${playlist.isFavorite ? l10n.favorites : playlist.name}',
                                    transitionOnUserGestures: true,
                                    child: CoverArtWidget(
                                      size: 150 + extraSize,
                                      borderRadius: 15,
                                      picture: playlist.picture,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 5),
                              SizedBox(
                                width: 140 + extraSize,
                                child: Text(
                                  playlist.isFavorite
                                      ? l10n.favorites
                                      : playlist.name,
                                  style: .new(overflow: .ellipsis, fontSize: 15),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            scrollController: playlistsSC,
            displayIconNotifier: playlistsDisplayIconNotifier,
            changeNotifier: playlistsChangeNotifier,
            iconTop: 55 + extraSize / 2,
          ),
          SizedBox(height: 15),
        ];
    }
  }

  Widget songListView(
    List<MyAudioMetadata> songList,
    ScrollController scrollController,
  ) {
    // One column fills a phone's width, so the per-song overflow button ends up
    // on the right edge (as in the song lists) instead of roughly mid-screen;
    // wider screens keep the multi-column shelf.
    final available = MediaQuery.of(context).size.width - 15;
    final columns = (available / 300).floor().clamp(1, 4);
    final itemWidth = available / columns;

    return SizedBox(
      height: 180,
      child: MouseRegion(
        child: ListView.builder(
          padding: .zero,
          controller: scrollController,
          scrollDirection: .horizontal,
          itemCount: songList.length ~/ 3 + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return SizedBox(width: 15);
            }
            index -= 1;
            return SizedBox(
              width: itemWidth,
              child: Column(
                mainAxisSize: .min,
                children: List.generate(min(3, songList.length - index * 3), (
                  j,
                ) {
                  final song = songList[index * 3 + j];
                  return InkWell(
                    onTap: isMobile
                        ? () {
                            audioHandler.setPlayQueue(
                              songList,
                              0,
                              targetIndex: index * 3 + j,
                            );
                          }
                        : null,
                    onDoubleTap: isMobile
                        ? null
                        : () {
                            audioHandler.setPlayQueue(
                              songList,
                              0,
                              targetIndex: index * 3 + j,
                            );
                          },
                    customBorder: SmoothRectangleBorder(
                      smoothness: 1,
                      borderRadius: .circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          SizedBox(width: 5),
                          CoverArtWidget(
                            size: 50,
                            borderRadius: 5,
                            picture: song.picture,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: .start,
                              children: [
                                Text(
                                  getTitle(song),
                                  style: .new(
                                    fontSize: 15,
                                    overflow: .ellipsis,
                                  ),
                                ),
                                Text(
                                  '${getArtist(song)} - ${getAlbum(song)}',
                                  style: .new(
                                    fontSize: 12,
                                    overflow: .ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          playNextButton(context, song),
                          IconButton(
                            onPressed: () {
                              showSongOptions(
                                context: context,
                                song: song,
                                includeGoToArtist: true,
                                includeGoToAlbum: true,
                                useDialog: !isTooNarrow(context),
                              );
                            },
                            icon: Icon(Icons.more_vert_rounded, size: 20),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget mouseRegionForScroll({
    required Widget child,
    required ScrollController scrollController,
    required ValueNotifier<bool> displayIconNotifier,
    required ValueNotifier<int> changeNotifier,
    required double iconTop,
  }) {
    bool isScrolling = false;
    final scrollDistance = MediaQuery.sizeOf(context).width / 2;
    return MouseRegion(
      onEnter: (event) {
        displayIconNotifier.value = true;
      },
      onExit: (event) {
        displayIconNotifier.value = false;
      },
      child: Stack(
        children: [
          child,
          ListenableBuilder(
            listenable: Listenable.merge([displayIconNotifier, changeNotifier]),
            builder: (context, child) {
              if (isMobile ||
                  !displayIconNotifier.value ||
                  scrollController.position.pixels == 0) {
                return SizedBox.shrink();
              }
              return Positioned(
                top: iconTop,
                left: 20,
                child: Center(
                  child: ValueListenableBuilder(
                    valueListenable: iconColor.valueNotifier,
                    builder: (context, value, child) {
                      return GlassContainer(
                        settings: LiquidGlassSettings(
                          glassColor: glassColor.value,
                        ),
                        shape: const LiquidRoundedSuperellipse(
                          borderRadius: 30,
                        ),
                        child: IconButton(
                          color: value,
                          onPressed: () async {
                            if (isScrolling) {
                              return;
                            }
                            isScrolling = true;
                            await scrollController.animateTo(
                              (scrollController.offset - scrollDistance).clamp(
                                0.0,
                                scrollController.position.maxScrollExtent,
                              ),
                              duration: Duration(milliseconds: 500),
                              curve: Curves.easeInOutCubic,
                            );
                            isScrolling = false;
                            changeNotifier.value++;
                          },
                          icon: Icon(Icons.arrow_back_ios_new_rounded),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),

          ListenableBuilder(
            listenable: Listenable.merge([displayIconNotifier, changeNotifier]),
            builder: (context, child) {
              if (isMobile ||
                  !scrollController.position.hasContentDimensions ||
                  !displayIconNotifier.value ||
                  scrollController.position.extentAfter <= 0) {
                return SizedBox.shrink();
              }
              return Positioned(
                top: iconTop,
                right: 20,
                child: Center(
                  child: ValueListenableBuilder(
                    valueListenable: iconColor.valueNotifier,
                    builder: (context, value, child) {
                      return GlassContainer(
                        settings: LiquidGlassSettings(
                          glassColor: glassColor.value,
                        ),
                        shape: const LiquidRoundedSuperellipse(
                          borderRadius: 30,
                        ),
                        child: IconButton(
                          color: value,
                          onPressed: () async {
                            if (isScrolling) {
                              return;
                            }
                            isScrolling = true;

                            await scrollController.animateTo(
                              (scrollController.offset + scrollDistance).clamp(
                                0.0,
                                scrollController.position.maxScrollExtent,
                              ),
                              duration: Duration(milliseconds: 500),
                              curve: Curves.easeInOutCubic,
                            );

                            isScrolling = false;
                            changeNotifier.value++;
                          },
                          icon: Icon(Icons.arrow_forward_ios_rounded),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Icon + label tile used by the home hub row.
Widget homeNavButton(String label, IconData icon, String layer) {
  return homeNavAction(
    label,
    icon,
    () => layersManager.switchRootLayer(layer),
  );
}

/// [label] under [icon], doing [onTap] - a button of the home hub row, whether
/// it switches to a layer or opens a page.
Widget homeNavAction(String label, IconData icon, void Function() onTap) {
  // The colour depends on whether the playing page is up, on the theme and on
  // the view mode, and the home page is not rebuilt when such a page is merely
  // dismissed - so the button watches the palette itself rather than painting a
  // colour captured while the playing page was still on screen.
  return ListenableBuilder(
    listenable: Listenable.merge([
      displayLyricsPageNotifier,
      textColor.valueNotifier,
      lyricsPageForegroundColor.valueNotifier,
      viewModeNotifier,
    ]),
    builder: (context, child) {
      final textColor = colorManager.getSpecificTextColor();
      // Sized to its own content (no fixed slot), so the row still starts at the
      // page margin while the icon stays centred over its label.
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 26, color: textColor),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: textColor),
              ),
            ],
          ),
        ),
      );
    },
  );
}
