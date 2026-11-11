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
                showSortSheet(
                  context,
                  title: l10n.selectSortingType,
                  entries: [
                    SortEntry(l10n.defaultText, 0),
                    SortEntry(l10n.title, 1, descValue: 2),
                    SortEntry(l10n.artist, 3, descValue: 4),
                    SortEntry(l10n.album, 5, descValue: 6),
                    SortEntry(l10n.duration, 7, descValue: 8),
                    SortEntry(l10n.addedTime, 13, descValue: 14),
                    if (sourceType == .navidrome || sourceType == .emby)
                      SortEntry(l10n.playCountLabel, 17),
                    if (widget.album != null)
                      SortEntry(l10n.track, 15, descValue: 16),
                    if ((isLibrary && isNotStreamSource) || folder != null) ...[
                      SortEntry(l10n.modifiedTime, 9, descValue: 10),
                      SortEntry(l10n.randomizeTemp, 11),
                      SortEntry(l10n.randomizePermanent, 12),
                    ],
                  ],
                  selected: sortTypeNotifier,
                  confirm: (value) async {
                    if (value == 12) {
                      return await showConfirmDialog(
                        context,
                        l10n.cannotBeUndone,
                      );
                    }
                    return true;
                  },
                  onSelected: (value) {
                    if (value == 12) {
                      sortTypeNotifier.value = 0;
                      if (isLibrary) {
                        library.shuffle();
                      } else {
                        folder!.shuffle();
                      }
                      return;
                    }
                    if (value == 11 && sortTypeNotifier.value == 11) {
                      updateSongList();
                    }
                    sortTypeNotifier.value = value;
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
    if (album != null) {
      return albumHeader(context, l10n);
    }

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
                    // The artist page's counts are in the details line below; repeating
                    // a bare song count under the name adds nothing.
                    subtitle: artist != null
                        ? null
                        : ValueListenableBuilder(
                            valueListenable: currentSongListNotifier,
                            builder: (context, currentSongList, child) {
                              return Text(
                                l10n.songCount(currentSongList.length),
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
        _descriptionSection(context, l10n),
        SizedBox(height: 20),
      ],
    );
  }

  /// Album page: a large cover, then the album's information - name, artist,
  /// year, quality, the play buttons and the song/time/year figures - with the
  /// description underneath. The song list follows this header.
  Widget albumHeader(BuildContext context, AppLocalizations l10n) {
    final width = MediaQuery.of(context).size.width;
    final coverSize = math.min(width * 0.62, 320.0);
    final textColor = colorManager.getSpecificTextColor();
    final muted = textColor.withAlpha(150);
    final songs = currentSongListNotifier.value.isNotEmpty
        ? currentSongListNotifier.value
        : album!.songList;
    final first = songs.isNotEmpty ? songs.first : null;
    final year = album!.maxYear;
    final quality = first == null ? null : _qualityText(first);
    final artist = first == null ? null : getArtist(first);

    return Column(
      children: [
        const SizedBox(height: 14),
        Center(child: mainCover(coverSize)),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Text(
                getTitleText(l10n),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (artist != null && artist.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  artist,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, color: muted),
                ),
              ],
              if (year != null) ...[
                const SizedBox(height: 4),
                Text('$year', style: TextStyle(fontSize: 13, color: muted)),
              ],
              if (quality != null) ...[
                const SizedBox(height: 4),
                Text(quality, style: TextStyle(fontSize: 13, color: muted)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: _pillButton(
                  icon: Icons.play_arrow_rounded,
                  label: l10n.playAll,
                  filled: true,
                  onTap: () {
                    tryVibrate();
                    audioHandler.setPlayQueue(songs, 0);
                  },
                  onLongPress: () {
                    vibrateGestureFeedback();
                    audioHandler.setPlayQueue(songs, 1);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _pillButton(
                  icon: Icons.shuffle_rounded,
                  label: l10n.shuffle,
                  filled: false,
                  onTap: () {
                    tryVibrate();
                    audioHandler.setPlayQueue(songs, 1);
                  },
                ),
              ),
              if (canFavorite) ...[
                const SizedBox(width: 8),
                favoriteButton(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        _albumStatsRow(context, songs, l10n, year),
        const SizedBox(height: 6),
        _descriptionSection(context, l10n),
        const SizedBox(height: 6),
      ],
    );
  }

  /// "24 bits 48000 Hz"-style quality line from the first song's sample rate
  /// and bitrate; null when the source reports neither.
  String? _qualityText(MyAudioMetadata song) {
    final parts = <String>[];
    final rate = song.samplerate;
    if (rate != null && rate > 0) {
      parts.add('${(rate / 1000).toStringAsFixed(rate % 1000 == 0 ? 0 : 1)} kHz');
    }
    final bitrate = song.bitrate;
    if (bitrate != null && bitrate > 0) {
      parts.add('$bitrate kbps');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Widget _pillButton({
    required IconData icon,
    required String label,
    required bool filled,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return SizedBox(
      height: 46,
      child: ElevatedButton.icon(
        onPressed: onTap,
        onLongPress: onLongPress,
        icon: Icon(icon, size: 22),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: filled
              ? buttonColor.value
              // A lighter tint of the accent, so "shuffle" reads as the
              // secondary action next to "play all" instead of shouting.
              : buttonColor.value.withAlpha(38),
          foregroundColor: filled ? null : colorManager.getSpecificTextColor(),
          elevation: 0,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
        ),
      ),
    );
  }

  /// Song count, total playing time and year, the three figures under the play
  /// buttons of an album page.
  Widget _albumStatsRow(
    BuildContext context,
    List<MyAudioMetadata> songs,
    AppLocalizations l10n,
    int? year,
  ) {
    var duration = Duration.zero;
    for (final song in songs) {
      duration += song.duration ?? Duration.zero;
    }
    final textColor = colorManager.getSpecificTextColor();
    Widget cell(String value, String label) {
      return Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: textColor.withAlpha(150),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          cell('${songs.length}', l10n.songUnit),
          cell(formatDuration(duration), l10n.duration),
          if (year != null) cell('$year', l10n.year),
        ],
      ),
    );
  }

  /// The album description / artist biography, truncated to a few lines, that
  /// opens a full-text popup when tapped.
  Widget _descriptionSection(BuildContext context, AppLocalizations l10n) {
    final raw = album != null ? albumDescription : artist?.biography;
    final description = raw == null ? null : cleanRichText(raw);
    if (description == null || description.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showFullTextDialog(
          context,
          album != null ? l10n.description : l10n.biography,
          description,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: colorManager.getSpecificTextColor().withAlpha(190),
              height: 1.4,
            ),
          ),
        ),
      ),
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

  /// Year, counts, total playing time and size of the album/artist. Nothing is
  /// shown for a plain song list; the description is shown by
  /// _descriptionSection, so it can be tapped open.
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
    final textColor = colorManager.getSpecificTextColor();
    return Padding(
      padding: padding,
      child: Text(
        parts.join(' · '),
        style: TextStyle(fontSize: 12, color: textColor.withAlpha(150)),
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
        if (album != null)
          SliverToBoxAdapter(child: contributingArtistsSection(context)),
        SliverToBoxAdapter(child: SizedBox(height: 90)),
      ],
    );
  }

  /// The artists credited on this album, as rows with their own cover, how many
  /// of the album's songs they are on, and a play button.
  Widget contributingArtistsSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final songs = <String, List<MyAudioMetadata>>{};
    for (final song in album!.songList) {
      for (final name in getArtists(getArtist(song))) {
        songs.putIfAbsent(name, () => []).add(song);
      }
    }
    if (songs.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 4),
          child: Text(
            l10n.contributingArtists,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        for (final entry in songs.entries)
          _albumArtistRow(context, entry.key, entry.value),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _albumArtistRow(
    BuildContext context,
    String name,
    List<MyAudioMetadata> songs,
  ) {
    final artist = artistAlbumManager.artistMap[name];
    final textColor = colorManager.getSpecificTextColor();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: CoverArtWidget(
        size: 44,
        borderRadius: 22,
        picture: artist?.picture,
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        AppLocalizations.of(context).songCount(songs.length),
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.play_arrow_rounded, color: textColor),
            onPressed: () {
              tryVibrate();
              audioHandler.setPlayQueue(songs, 0);
            },
          ),
          IconButton(
            icon: Icon(Icons.queue_music_rounded, color: textColor),
            onPressed: () {
              tryVibrate();
              for (final song in songs) {
                audioHandler.add2Last(song);
              }
            },
          ),
        ],
      ),
      onTap: artist == null
          ? null
          : () {
              pushArtistDetail(artist);
            },
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
