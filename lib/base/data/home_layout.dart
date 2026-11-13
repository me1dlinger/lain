import 'package:material_ui/material_ui.dart';

/// What the home page shows, and in which order.
///
/// Each group is stored as an order plus a set of hidden entries, so hiding
/// something does not move it: it comes back where it was.

/// The buttons in the row at the very top of the home page.
enum HomeButton { artists, albums, songs, playlists, favorites, listeningReport }

/// The shelves below it.
///
/// [HomeShelf.stats] is the Navidrome-only statistics card; on any other
/// source the home page simply skips it.
enum HomeShelf {
  albums,
  frequently,
  recentlyAdded,
  recently,
  playlists,
  stats,
}

final homeButtonOrder = ValueNotifier<List<HomeButton>>(
  List.of(HomeButton.values),
);

final homeButtonHidden = ValueNotifier<Set<HomeButton>>({});

final homeShelfOrder = ValueNotifier<List<HomeShelf>>(List.of(HomeShelf.values));

final homeShelfHidden = ValueNotifier<Set<HomeShelf>>({});

/// The hub buttons to draw, in the user's order.
List<HomeButton> get visibleHomeButtons => [
  for (final button in homeButtonOrder.value)
    if (!homeButtonHidden.value.contains(button)) button,
];

/// The shelves to draw, in the user's order.
List<HomeShelf> get visibleHomeShelves => [
  for (final shelf in homeShelfOrder.value)
    if (!homeShelfHidden.value.contains(shelf)) shelf,
];

/// Reads a stored order back. Names this build does not know are dropped, and
/// entries the stored copy does not mention - a newer build's - are appended,
/// so updating the app cannot lose the arrangement.
List<T> restoredHomeOrder<T extends Enum>(Object? stored, List<T> defaults) {
  final ordered = <T>[];

  if (stored is List) {
    for (final name in stored.map((e) => '$e')) {
      for (final value in defaults) {
        if (value.name == name && !ordered.contains(value)) {
          ordered.add(value);
        }
      }
    }
  }

  for (final value in defaults) {
    if (!ordered.contains(value)) {
      ordered.add(value);
    }
  }

  return ordered;
}

/// Reads the stored set of hidden entries; unknown names are ignored.
Set<T> restoredHomeHidden<T extends Enum>(Object? stored, List<T> defaults) {
  if (stored is! List) {
    return {};
  }

  final names = stored.map((e) => '$e').toSet();

  return {
    for (final value in defaults)
      if (names.contains(value.name)) value,
  };
}
