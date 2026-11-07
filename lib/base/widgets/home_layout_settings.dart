import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/data/home_layout.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/widgets/my_switch.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';

/// Chooses what the home page shows - the buttons at the very top and the
/// shelves below them - and in which order. Hidden entries keep their place, so
/// showing one again does not move it.
class HomeLayoutSettings extends StatefulWidget {
  const HomeLayoutSettings({super.key});

  @override
  State<HomeLayoutSettings> createState() => _HomeLayoutSettingsState();
}

class _HomeLayoutSettingsState extends State<HomeLayoutSettings> {
  /// One visibility switch per entry, since [MySwitch] drives its own notifier.
  final _visibility = <String, ValueNotifier<bool>>{};

  @override
  void dispose() {
    for (final notifier in _visibility.values) {
      notifier.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // The panel colour is translucent by design, so a pushed page composites it
    // into an opaque one instead of showing the navigator underneath.
    return Scaffold(
      backgroundColor: colorManager.getSpecificOpaqueBgColor(),
      body: SafeArea(
        child: Column(
          children: [
            _header(l10n),
            Expanded(
              // Let a reorder or a switch redraw the list it belongs to.
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  homeButtonOrder,
                  homeButtonHidden,
                  homeShelfOrder,
                  homeShelfHidden,
                ]),
                builder: (context, child) {
                  return ListView(
                    padding: const EdgeInsets.only(bottom: 30),
                    children: [
                      _sectionTitle(l10n.homeTopButtons),
                      _orderList<HomeButton>(
                        tag: 'button',
                        order: homeButtonOrder,
                        hidden: homeButtonHidden,
                        label: (button) => switch (button) {
                          HomeButton.artists => l10n.artists,
                          HomeButton.albums => l10n.albums,
                          HomeButton.songs => l10n.songs,
                          HomeButton.playlists => l10n.playlists,
                          HomeButton.favorites => l10n.favorites,
                          HomeButton.listeningReport => l10n.listeningReport,
                        },
                      ),
                      _sectionTitle(l10n.homeSections),
                      _orderList<HomeShelf>(
                        tag: 'shelf',
                        order: homeShelfOrder,
                        hidden: homeShelfHidden,
                        label: (shelf) => switch (shelf) {
                          HomeShelf.albums => l10n.albums,
                          HomeShelf.frequently => l10n.frequently,
                          HomeShelf.recentlyAdded => l10n.recentlyAdded,
                          HomeShelf.recently => l10n.recently,
                          HomeShelf.playlists => l10n.playlists,
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(AppLocalizations l10n) {
    final textColor = colorManager.getSpecificTextColor();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              l10n.homeLayout,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          color: colorManager.getSpecificTextColor().withAlpha(160),
        ),
      ),
    );
  }

  Widget _orderList<T extends Enum>({
    required String tag,
    required ValueNotifier<List<T>> order,
    required ValueNotifier<Set<T>> hidden,
    required String Function(T item) label,
  }) {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        // The callback reports the index before the item is taken out.
        if (newIndex > oldIndex) {
          newIndex -= 1;
        }
        final rearranged = List<T>.of(order.value);
        rearranged.insert(newIndex, rearranged.removeAt(oldIndex));
        order.value = rearranged;
        setting.save();
      },
      children: [
        for (var index = 0; index < order.value.length; index++)
          _row<T>(
            key: ValueKey('$tag-${order.value[index].name}'),
            tag: tag,
            item: order.value[index],
            index: index,
            label: label(order.value[index]),
            hidden: hidden,
          ),
      ],
    );
  }

  Widget _row<T extends Enum>({
    required Key key,
    required String tag,
    required T item,
    required int index,
    required String label,
    required ValueNotifier<Set<T>> hidden,
  }) {
    final textColor = colorManager.getSpecificTextColor();

    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 2),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Icon(
                Icons.drag_handle_rounded,
                size: 22,
                color: textColor.withAlpha(150),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 15, color: textColor)),
          ),
          SizedBox(
            width: 50,
            child: MySwitch(valueNotifier: _visibleNotifier(tag, item, hidden)),
          ),
        ],
      ),
    );
  }

  /// Whether [item] is shown, wired to the stored set of hidden entries.
  ValueNotifier<bool> _visibleNotifier<T extends Enum>(
    String tag,
    T item,
    ValueNotifier<Set<T>> hidden,
  ) {
    return _visibility.putIfAbsent('$tag-${item.name}', () {
      final notifier = ValueNotifier<bool>(!hidden.value.contains(item));
      notifier.addListener(() {
        final updated = Set<T>.of(hidden.value);
        if (notifier.value) {
          updated.remove(item);
        } else {
          updated.add(item);
        }
        hidden.value = updated;
        setting.save();
      });
      return notifier;
    });
  }
}