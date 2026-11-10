part of '../../base/widgets/song_list.dart';

extension _SongListPage on _SongListState {
  Widget pageView(BuildContext context) {
    return myScaffold(
      context: context,
      body: contentWithStack(),
      label: rootLabel,
      actions: [
        ValueListenableBuilder(
          valueListenable: currentSongListNotifier,
          builder: (context, value, child) {
            return MySearchField(
              key: ValueKey(getFirstSong(songList)),
              hintText: AppLocalizations.of(context).searchSongs,
              textController: textController,
              useCurrentSong: false,
            );
          },
        ),
        moreButton(context),
      ],
    );
  }

  Widget moreButton(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.more_vert),
      onPressed: () {
        tryVibrate();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useRootNavigator: true,
          builder: (context) {
            return moreSheet(context);
          },
        ).then((value) {
          if (value == true && context.mounted) {
            Navigator.pop(context);
          }
        });
      },
    );
  }

  Widget moreSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return MySheet(
      height: 300,
      Column(
        children: [
          ListTile(
            title: Row(
              children: [
                if (playlist != null)
                  Text("${l10n.playlists}: ", style: TextStyle(fontSize: 15)),
                if (artist != null)
                  Text("${l10n.artists}: ", style: TextStyle(fontSize: 15)),
                if (album != null)
                  Text("${l10n.albums}: ", style: TextStyle(fontSize: 15)),
                if (folder != null)
                  Text("${l10n.folders}: ", style: TextStyle(fontSize: 15)),

                Expanded(
                  child: TextScroll(
                    getTitleText(l10n),
                    style: TextStyle(fontSize: 15),
                    velocity: const .new(pixelsPerSecond: .new(40, 0)),
                    intervalSpaces: 10,
                    pauseBetween: Duration(seconds: 2),
                  ),
                ),
              ],
            ),
          ),
          MyDivider(thickness: 0.5, height: 1, color: dividerColor),
          ListTile(
            leading: ImageIcon(selectImage),
            title: Text(
              l10n.select,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            onTap: () {
              Navigator.pop(context);
              for (var e in isSelectedNotifierMap.values) {
                e.value = false;
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ValueListenableBuilder(
                    valueListenable: currentSongListNotifier,
                    builder: (context, currentSongList, child) {
                      return SelectableSongListPage(
                        songList: currentSongList,
                        playlist: playlist,
                        folder: folder,
                        isFrequently: isFrequently,
                        isRecently: isRecently,
                        isLibrary: isLibrary,
                        reorderable: reorderable,
                        isSelectedNotifierMap: isSelectedNotifierMap,
                      );
                    },
                  ),
                ),
              );
            },
          ),
          // A local playlist can be written out as a list of file paths, the
          // shape it can be imported from again.
          if (playlist != null && isNotStreamSource)
            ListTile(
              leading: Icon(Icons.ios_share_rounded),
              title: Text(
                l10n.exportPlaylist,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
              onTap: () {
                Navigator.pop(context);
                exportPlaylist(playlist!);
              },
            ),
          // The artist view is grouped by album in track order, so a sort order
          // would have nothing to act on and is not offered there.
          if (!isFrequently && !isRecently && !isRecentlyAdded && artist == null)
            ListTile(
              leading: ImageIcon(sequenceImage),
              title: Text(
                l10n.sortSongs,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useRootNavigator: true,
                  builder: (context) {
                    List<(String, int)> orderOptions = [
                      (l10n.defaultText, 0),
                      (l10n.titleAscending, 1),
                      (l10n.titleDescending, 2),
                      (l10n.artistAscending, 3),
                      (l10n.artistDescending, 4),
                      (l10n.albumAscending, 5),
                      (l10n.albumDescending, 6),
                      (l10n.durationAscending, 7),
                      (l10n.durationDescending, 8),
                      (l10n.addedTimeAscending, 13),
                      (l10n.addedTimeDescending, 14),
                      // Only the servers report a play count; Navidrome and
                      // Emby both do, Feiniu has no such field.
                      if (sourceType == .navidrome || sourceType == .emby)
                        (l10n.mostPlayed, 17),
                      // Track order only has a meaning inside an album, so these
                      // two are offered there and nowhere else.
                      if (widget.album != null) ...[
                        (l10n.trackAscending, 15),
                        (l10n.trackDescending, 16),
                      ],
                    ];
                    if (isLibrary && isNotStreamSource || folder != null) {
                      orderOptions.add((l10n.modifiedTimeAscending, 9));
                      orderOptions.add((l10n.modifiedTimedescending, 10));
                      orderOptions.add((l10n.randomizeTemp, 11));
                      orderOptions.add((l10n.randomizePermanent, 12));
                    }
                    List<Widget> orderWidget = [];
                    for (final (text, type) in orderOptions) {
                      orderWidget.add(
                        ValueListenableBuilder(
                          valueListenable: sortTypeNotifier,
                          builder: (context, value, child) {
                            return ListTile(
                              title: Text(text),
                              onTap: () async {
                                if (type == 12) {
                                  if (!await showConfirmDialog(
                                    context,
                                    l10n.cannotBeUndone,
                                  )) {
                                    return;
                                  }
                                  sortTypeNotifier.value = 0;
                                  if (isLibrary) {
                                    library.shuffle();
                                  } else {
                                    folder!.shuffle();
                                  }
                                } else {
                                  if (type == 11 &&
                                      sortTypeNotifier.value == 11) {
                                    updateSongList();
                                  }
                                  sortTypeNotifier.value = type;
                                }
                              },
                              trailing: value == type ? Icon(Icons.check) : null,
                              visualDensity: VisualDensity(
                                horizontal: 0,
                                vertical: -4,
                              ),
                            );
                          },
                        ),
                      );
                    }
                    return MySheet(
                      Column(
                        children: [
                          ListTile(title: Text(l10n.selectSortingType)),
                          MyDivider(
                            thickness: 0.5,
                            height: 1,
                            color: dividerColor,
                          ),

                          Expanded(
                            child: ListView(
                              children: [...orderWidget, SizedBox(height: 50)],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),

          if (playlist != null && playlist!.isNotFavorite && isNotStreamSource)
            ListTile(
              leading: Icon(Icons.drive_file_rename_outline),
              title: Text(
                l10n.rename,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
              onTap: () async {
                final target = playlist!;
                final name = await getInputTextDialog(
                  context,
                  l10n.rename,
                  initial: target.name,
                );
                if (name.trim().isEmpty || name.trim() == target.name) {
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                  return;
                }

                final renamed = await playlistManager.renamePlaylist(
                  target,
                  name,
                );
                if (renamed && context.mounted) {
                  showCenterMessage(l10n.savedSuccessfully);
                }
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
            ),
          if (playlist != null && playlist!.isNotFavorite)
            ListTile(
              leading: ImageIcon(deleteImage),
              title: Text(
                l10n.delete,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
              onTap: () async {
                if (await showConfirmDialog(context, l10n.delete)) {
                  layersManager.removeLayerIfNeed(playlist!);
                  playlistManager.deletePlaylist(playlist!);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
            ),
        ],
      ),
    );
  }

  Widget contentWithStack() {
    return Stack(
      children: [
        NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (notification.direction != ScrollDirection.idle) {
              listIsScrollingNotifier.value = true;
              if (timer != null) {
                timer!.cancel();
                timer = null;
              }
            } else {
              if (listIsScrollingNotifier.value) {
                timer ??= Timer(const Duration(milliseconds: 3000), () {
                  listIsScrollingNotifier.value = false;
                  timer = null;
                });
              }
            }
            return false;
          },
          child: pageContent(),
        ),
        Positioned(
          right: 30,
          bottom: 180,
          child: ValueListenableBuilder(
            valueListenable: listIsScrollingNotifier,
            builder: (context, value, child) {
              if (!value) {
                return SizedBox.shrink();
              }
              return IconButton(
                onPressed: () {
                  scrollController.animateTo(
                    0,
                    duration: Duration(milliseconds: 250),
                    curve: Curves.linear,
                  );
                },
                icon: ImageIcon(topArrowImage),
              );
            },
          ),
        ),

        Positioned(
          right: 30,
          bottom: 120,
          child: MyLocation(
            scrollController: scrollController,
            listIsScrollingNotifier: listIsScrollingNotifier,
            currentSongListNotifier: currentSongListNotifier,
            // Land the row in the middle of the screen rather than near the top.
            offset: -(MediaQuery.heightOf(context) - 60) / 2,
            offsetOf: artist == null
                ? null
                : (song) => artistRowOffsetOf(song, currentSongListNotifier.value),
          ),
        ),
      ],
    );
  }

  Widget pageHeader() {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.of(context).size;
    final shortSide = size.shortestSide;

    bool isPhone = shortSide < 600;

    return Column(
      children: [
        SizedBox(height: 10),
        Row(
          children: [
            SizedBox(width: 20),
            mainCover(isPhone ? 120 : 160),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: AutoSizeText(
                      getTitleText(l10n),
                      maxLines: 1,
                      minFontSize: 20,
                      maxFontSize: 20,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: ValueListenableBuilder(
                      valueListenable: currentSongListNotifier,
                      builder: (context, currentSongList, child) {
                        String prefix = getSourceTypeDisplayName(
                          l10n,
                          sourceType,
                        );
                        return Text(
                          "$prefix: ${l10n.songCount(currentSongList.length)}",
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          playAllButton(),
                          const SizedBox(width: 10),
                          shuffleButton(),
                          if (canFavorite) ...[
                            const SizedBox(width: 10),
                            favoriteButton(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        entityDetails(context),
        SizedBox(height: 20),
      ],
    );
  }

  /// The heart that marks the album/artist being viewed as a favourite.
  Widget favoriteButton() {
    final target = favoriteEntity!;
    return ValueListenableBuilder(
      valueListenable: target.starredNotifier,
      builder: (context, starred, child) {
        return SizedBox(
          width: 40,
          height: 40,
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              tryVibrate();
              toggleEntityFavorite(target);
            },
            icon: Icon(
              starred
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: starred ? Colors.red : colorManager.getSpecificTextColor(),
            ),
          ),
        );
      },
    );
  }

  /// Year, counts, total playing time and size of the album/artist, then its
  /// description. Nothing is shown for a plain song list.
  Widget entityDetails(
    BuildContext context, {
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(20, 6, 20, 0),
  }) {
    final target = favoriteEntity;
    if (target == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final parts = <String>[];
    if (album != null) {
      final year = album!.maxYear;
      if (year != null) {
        parts.add('$year');
      }
      parts.add(l10n.songCount(album!.songList.length));
    } else {
      if (artist!.albumCount > 0) {
        parts.add(l10n.albumCount(artist!.albumCount));
      }
      parts.add(l10n.songCount(artist!.songList.length));
    }
    if (target.playCount > 0) {
      parts.add('${target.playCount} ${l10n.times}');
    }
    if (target.totalDuration > Duration.zero) {
      parts.add(formatDuration(target.totalDuration, ms: false));
    }
    if (target.size > 0) {
      parts.add(formatSize(target.size));
    }
    final description = album != null ? albumDescription : artist!.biography;
    final textColor = colorManager.getSpecificTextColor();
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            parts.join(' · '),
            style: TextStyle(fontSize: 12, color: textColor.withAlpha(150)),
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: textColor.withAlpha(180)),
            ),
          ],
        ],
      ),
    );
  }

  Widget playAllButton() {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder(
      valueListenable: currentSongListNotifier,
      builder: (context, currentSongList, child) {
        return ListenableBuilder(
          listenable: buttonColor.valueNotifier,
          builder: (_, _) {
            final enabled = currentSongList.isNotEmpty;
            return SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: enabled
                    ? () {
                        tryVibrate();
                        audioHandler.setPlayQueue(currentSongList, 0);
                      }
                    : null,
                onLongPress: enabled
                    ? () {
                        // The long press has already changed what this button
                        // does, so the change has to be felt. It is not behind
                        // the app's vibration setting: that one is about
                        // incidental feedback, not a changed action.
                        vibrateGestureFeedback();
                        audioHandler.setPlayQueue(currentSongList, 1);
                      }
                    : null,
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: Text(l10n.playAll),
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor.value,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  visualDensity: const VisualDensity(
                    horizontal: 0,
                    vertical: -2,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// The same list as [playAllButton], shuffled. Icon-only and round, sharing the
/// play button's height so the header stays one clean line; long-pressing "play
/// all" does this too, but a visible button is what most people reach for.
  Widget shuffleButton() {
    return ValueListenableBuilder(
      valueListenable: currentSongListNotifier,
      builder: (context, currentSongList, child) {
        return ListenableBuilder(
          listenable: buttonColor.valueNotifier,
          builder: (_, _) {
            final enabled = currentSongList.isNotEmpty;
            return SizedBox(
              width: 40,
              height: 40,
              child: ElevatedButton(
                onPressed: enabled
                    ? () {
                        tryVibrate();
                        audioHandler.setPlayQueue(currentSongList, 1);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor.value,
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                  visualDensity: const VisualDensity(
                    horizontal: 0,
                    vertical: -2,
                  ),
                ),
                child: const Icon(Icons.shuffle_rounded, size: 20),
              ),
            );
          },
        );
      },
    );
  }

  Widget pageContent() {
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(child: pageHeader()),
        ValueListenableBuilder(
          valueListenable: currentSongListNotifier,
          builder: (context, currentSongList, child) {
            if (prepareing) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: iconColor.value),
                ),
              );
            }
            // An artist is shown as albums: a strip of album cards, then the
            // songs grouped per album in track order.
            if (artist != null) {
              final groups = artistSongGroups(currentSongList);
              return SliverList(
                delegate: SliverChildListDelegate([
                  artistAlbumStrip(context, currentSongList),
                  for (final group in groups) ...[
                    artistGroupHeader(context, group.$1, group.$2),
                    for (var i = 0; i < group.$2.length; i++)
                      SizedBox(
                        height: 60,
                        child: Center(child: songListTile(i, group.$2)),
                      ),
                  ],
                ]),
              );
            }
            return SliverFixedExtentList.builder(
              itemExtent: 60,
              itemCount: currentSongList.length,
              itemBuilder: (context, index) {
                return Center(child: songListTile(index, currentSongList));
              },
            );
          },
        ),
        SliverToBoxAdapter(child: SizedBox(height: 90)),
      ],
    );
  }

  Widget songListTile(int index, List<MyAudioMetadata> currentSongList) {
    final song = currentSongList[index];
    return ValueListenableBuilder(
      valueListenable: song.updateNotifier,
      builder: (context, value, child) {
        return ListTile(
          contentPadding: EdgeInsets.fromLTRB(20, 0, 0, 0),
          // Inside an album, and in an artist's album grouping, the track
          // number is part of the identity of a song.
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (album != null || artist != null)
                SizedBox(
                  width: 24,
                  child: Text(
                    song.track == null ? '' : '${song.track}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorManager.getSpecificTextColor().withAlpha(150),
                    ),
                  ),
                ),
              CoverArtWidget(
                size: 40,
                borderRadius: 4,
                picture: song.picture,
              ),
            ],
          ),
          title: ValueListenableBuilder(
            valueListenable: currentSongNotifier,
            builder: (_, currentSong, _) {
              return ValueListenableBuilder(
                valueListenable: highlightTextColor.valueNotifier,
                builder: (context, value, child) {
                  return Text(
                    getTitle(song),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: song == currentSong ? value : null,
                      fontWeight: song == currentSong ? FontWeight.bold : null,
                    ),
                  );
                },
              );
            },
          ),

          subtitle: Row(
            children: [
              ValueListenableBuilder(
                valueListenable: song.isFavoriteNotifier,
                builder: (_, value, _) {
                  return value
                      ? SizedBox(
                          width: 20,
                          child: Icon(
                            Icons.star_rounded,
                            color: Colors.red,
                            size: 15,
                          ),
                        )
                      : SizedBox();
                },
              ),
              Expanded(
                child: Text(
                  "${getArtist(song)} - ${getAlbum(song)}",
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
          onTap: () =>
              audioHandler.setPlayQueue(currentSongList, 0, targetIndex: index),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isFrequently && sourceType != .emby)
                SizedBox(
                  width: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ImageIcon(playOutlinedImage, size: 15),
                      Text(song.playCount.toString()),
                    ],
                  ),
                ),
              playNextButton(context, song),
              songOptionsButton(index, song),
            ],
          ),
        );
      },
    );
  }

  Widget songOptionsButton(int index, MyAudioMetadata song) {
    return IconButton(
      icon: Icon(Icons.more_vert, size: 20),
      onPressed: () {
        tryVibrate();
        showSongOptions(
          context: context,
          song: song,
          moveToTop: reorderable ? () => moveToTop(index) : null,
          includeGoToArtist: artist == null || artist!.name != song.artist,
          excludedArtist: artist?.name,
          includeGoToAlbum: album == null,
          includeEdit: sourceType == .local && artist == null && album == null,
          playlist: playlist,
          useDialog: false,
        );
      },
    );
  }
}
