import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/widgets/my_divider.dart';
import 'package:sylvakru/base/widgets/my_sheet.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';

/// One entry of a sort sheet: the label shown, the value it sets in the
/// ascending form, and - for a key that has two directions - the descending
/// value. A key with no [descValue] has no direction of its own.
class SortEntry {
  final String label;
  final int value;
  final int? descValue;

  const SortEntry(this.label, this.value, {this.descValue});

  bool matches(int current) => current == value || current == descValue;
}

/// The one sort bottom sheet, used by the song list and by the album and artist
/// lists, so every list offers its order the same way: the keys, with the one in
/// use ticked, and an ascending / descending pair beneath them.
///
/// Two models are supported. A list whose sort key is directionless (albums,
/// artists) passes an [ascending] notifier. A list whose sort value encodes the
/// direction (songs) leaves it null; the direction is then read from, and
/// written back to, the entry's values.
Future<void> showSortSheet(
  BuildContext context, {
  required String title,
  required List<SortEntry> entries,
  required ValueNotifier<int> selected,
  ValueNotifier<bool>? ascending,
  Future<bool> Function(int value)? confirm,
  void Function(int value)? onSelected,
}) {
  final l10n = AppLocalizations.of(context);

  SortEntry? currentEntry() {
    for (final entry in entries) {
      if (entry.matches(selected.value)) {
        return entry;
      }
    }
    return null;
  }

  bool isAscending() {
    if (ascending != null) {
      return ascending.value;
    }
    final entry = currentEntry();
    return entry == null ||
        entry.descValue == null ||
        selected.value != entry.descValue;
  }

  void pick(int value) {
    if (onSelected != null) {
      onSelected(value);
    } else {
      selected.value = value;
    }
  }

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (sheetContext) {
      return MySheet(
        Column(
          children: [
            ListTile(title: Text(title)),
            MyDivider(thickness: 0.5, height: 1, color: dividerColor),
            Expanded(
              child: ListenableBuilder(
                listenable: ascending == null
                    ? selected
                    : Listenable.merge([selected, ascending]),
                builder: (context, child) {
                  final order = isAscending();
                  return ListView(
                    children: [
                      for (final entry in entries)
                        ListTile(
                          title: Text(entry.label),
                          trailing: entry.matches(selected.value)
                              ? const Icon(Icons.check)
                              : null,
                          visualDensity: const VisualDensity(
                            horizontal: 0,
                            vertical: -4,
                          ),
                          onTap: () async {
                            if (confirm != null && !await confirm(entry.value)) {
                              return;
                            }
                            pick(
                              (entry.descValue != null && !order)
                                  ? entry.descValue!
                                  : entry.value,
                            );
                          },
                        ),
                      MyDivider(thickness: 0.5, height: 1, color: dividerColor),
                      ListTile(
                        title: Text(l10n.ascending),
                        trailing: order ? const Icon(Icons.check) : null,
                        visualDensity: const VisualDensity(
                          horizontal: 0,
                          vertical: -4,
                        ),
                        onTap: () {
                          if (ascending != null) {
                            ascending.value = true;
                            setting.save();
                            return;
                          }
                          final entry = currentEntry();
                          if (entry?.descValue != null) {
                            pick(entry!.value);
                          }
                        },
                      ),
                      ListTile(
                        title: Text(l10n.descending),
                        trailing: !order ? const Icon(Icons.check) : null,
                        visualDensity: const VisualDensity(
                          horizontal: 0,
                          vertical: -4,
                        ),
                        onTap: () {
                          if (ascending != null) {
                            ascending.value = false;
                            setting.save();
                            return;
                          }
                          final entry = currentEntry();
                          if (entry?.descValue != null) {
                            pick(entry!.descValue!);
                          }
                        },
                      ),
                      const SizedBox(height: 50),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}