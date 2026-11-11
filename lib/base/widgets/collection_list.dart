import 'package:material_ui/material_ui.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/services/picture_service.dart';
import 'package:lain/base/utils/my_gird_delegate.dart';
import 'package:lain/base/widgets/cover_art_widget.dart';
import 'package:lain/base/widgets/my_navigator.dart';
import 'package:lain/base/widgets/my_scaffold.dart';
import 'package:lain/base/widgets/my_sheet.dart';
import 'package:lain/base/widgets/sort_sheet.dart';
import 'package:lain/l10n/generated/app_localizations.dart';
import 'package:lain/landscape_view/title_bar.dart';
import 'package:lain/base/data/setting.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/asset_images.dart';
import 'package:lain/base/widgets/my_divider.dart';
import 'package:lain/base/widgets/my_switch.dart';
import 'package:lain/portrait_view/my_search_field.dart';

part '../../landscape_view/panels/collection_list_panel.dart';
part '../../portrait_view/pages/collection_list_page.dart';

abstract class CollectionList extends StatefulWidget {
  const CollectionList({super.key});
}

abstract class CollectionListState extends State<CollectionList> {
  /// Extra entries for this layer's "more" sheet; layers that need none leave
  /// it alone.
  List<Widget> sheetExtras(BuildContext context) => const [];
  final GlobalKey<NavigatorState> globalKey = GlobalKey();
  final visibleNotifier = ValueNotifier(true);

  List<MyPicture?> currentPictureList = [];
  List<String> currentTextList = [];

  List<int>? currentSubCountList;

  /// Subtitle of each row in list view, when the layer shows more than a song
  /// count (an artist's albums / songs / plays). Takes precedence over
  /// [currentSubCountList].
  List<String>? currentSubtitleList;

  List<Function> currentOnTapList = [];

  /// Optional long-press action per row, for a layer that offers one (the
  /// artist list refreshes that artist's cache).
  List<Function>? currentOnLongPressList;

  final textController = TextEditingController();

  final ScrollController scrollController = ScrollController();

  ValueNotifier<bool>? randomizeNotifier;
  ValueNotifier<bool>? isAscendingNotifier;

  /// Key of the list's own order (name, added time, play count, ...). When set
  /// together with [sortKeyOptions] the "more" sheet offers it.
  ValueNotifier<int>? sortKeyNotifier;
  List<(String, int)> Function()? sortKeyOptions;
  ValueNotifier<bool> useLargePictureNotifier = ValueNotifier(false);

  final changeNotifier = ValueNotifier(0);

  ValueNotifier<bool>? isListViewNotifier;

  String title = '';
  String searchHint = '';

  // for hero tag
  String label = '';

  late final AssetImage image;

  late final String Function(int) countFunction;

  bool preparing = true;

  void updateCurrentList();

  /// "Sort by" entry of the settings sheet: the keys, then ascending and
  /// descending, in the same sheet every list uses. Nothing is hidden when the
  /// order changes, and the sheet stays open so another choice can be made.
  Widget sortKeyTile(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final notifier = sortKeyNotifier!;
    final options = sortKeyOptions!();
    return ListenableBuilder(
      listenable: Listenable.merge([notifier, isAscendingNotifier]),
      builder: (context, child) {
        final current = options.firstWhere(
          (option) => option.$2 == notifier.value,
          orElse: () => options.first,
        );
        final orderLabel = (isAscendingNotifier?.value ?? true)
            ? l10n.ascending
            : l10n.descending;
        return ListTile(
          leading: ImageIcon(sequenceImage),
          title: Text(
            l10n.sortType,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('${current.$1} - $orderLabel'),
          visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
          onTap: () {
            // Close the settings sheet first, then open the sort sheet, so the
            // two are not stacked.
            Navigator.pop(context);
            showSortSheet(
              context,
              title: l10n.selectSortingType,
              entries: [
                for (final option in options) SortEntry(option.$1, option.$2),
              ],
              selected: notifier,
              ascending: isAscendingNotifier,
              onSelected: (value) {
                notifier.value = value;
                randomizeNotifier?.value = false;
                // Favourites read best most-recently-starred first, so picking
                // it flips to descending.
                if (value == 5) {
                  isAscendingNotifier?.value = false;
                }
                setting.save();
              },
            );
          },
        );
      },
    );
  }

  void onSearch() {
    if (preparing) {
      return;
    }
    updateCurrentList();
  }

  @override
  void initState() {
    super.initState();

    isAscendingNotifier?.addListener(updateCurrentList);
    sortKeyNotifier?.addListener(updateCurrentList);
    // The shuffle switch lives in the sort dialog for albums and artists, so
    // nothing else rebuilt the list when it was turned on.
    randomizeNotifier?.addListener(updateCurrentList);
    textController.addListener(onSearch);
  }

  @override
  void dispose() {
    isAscendingNotifier?.removeListener(updateCurrentList);
    sortKeyNotifier?.removeListener(updateCurrentList);
    randomizeNotifier?.removeListener(updateCurrentList);
    textController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return myNavigator(
      key: globalKey,
      visibleNotifier: visibleNotifier,
      pageViewBuilder: () => pageView(context),
      panelViewBuilder: () => panelView(context),
    );
  }
}
