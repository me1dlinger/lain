import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/services/picture_service.dart';
import 'package:sylvakru/base/utils/my_gird_delegate.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/widgets/my_navigator.dart';
import 'package:sylvakru/base/widgets/my_scaffold.dart';
import 'package:sylvakru/base/widgets/my_sheet.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/landscape_view/title_bar.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/widgets/my_divider.dart';
import 'package:sylvakru/base/widgets/my_switch.dart';
import 'package:sylvakru/portrait_view/my_search_field.dart';

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
  List<Function> currentOnTapList = [];

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

  /// "Sort by" entry of the sheet: the list of keys, the tick on the one in
  /// use, and a picker that writes the value back to the settings.
  Widget sortKeyTile(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final notifier = sortKeyNotifier!;
    final options = sortKeyOptions!();
    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (context, value, child) {
        final current = options.firstWhere(
          (option) => option.$2 == value,
          orElse: () => options.first,
        );
        return ListTile(
          leading: ImageIcon(sequenceImage),
          title: Text(
            l10n.sortType,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(current.$1),
          visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useRootNavigator: true,
              builder: (sheetContext) {
                return MySheet(
                  Column(
                    children: [
                      ListTile(title: Text(l10n.sortType)),
                      MyDivider(thickness: 0.5, height: 1, color: dividerColor),
                      Expanded(
                        child: ListView(
                          children: [
                            for (final option in options)
                              ListTile(
                                title: Text(option.$1),
                                trailing: value == option.$2
                                    ? const Icon(Icons.check)
                                    : null,
                                onTap: () {
                                  notifier.value = option.$2;
                                  setting.save();
                                  Navigator.pop(sheetContext);
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
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
    textController.addListener(onSearch);
  }

  @override
  void dispose() {
    isAscendingNotifier?.removeListener(updateCurrentList);
    sortKeyNotifier?.removeListener(updateCurrentList);
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
