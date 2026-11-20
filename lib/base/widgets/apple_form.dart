import 'package:material_ui/material_ui.dart';
import 'package:lain/base/app.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/widgets/my_divider.dart';
import 'package:lain/base/widgets/my_switch.dart';

/// Grouped form pieces in the app's own style.
///
/// The layout is borrowed from iOS forms - a heading, then one card holding
/// label/value rows - but every colour comes from the app's colour manager and
/// the card fills are translucent, so the app's page background (and the vivid
/// mode's frosted look) still shows through, and light/dark come from the app's
/// own theme rather than the platform's.

/// Heading above a card.
Widget appleSectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 15,
        color: colorManager.getSpecificTextColor().withAlpha(160),
      ),
    ),
  );
}

/// One card of rows.
class AppleFormSection extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  /// Whether thin dividers are drawn between the rows. Off for sections whose
  /// rows carry enough structure of their own to not need the separation.
  final bool divided;

  const AppleFormSection({
    super.key,
    this.title,
    required this.children,
    this.divided = true,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = colorManager.getSpecificTextColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) appleSectionTitle(title!),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            // Translucent on purpose: the app's own surfaces are, so the cover
            // art background stays visible in vivid mode.
            color: textColor.withAlpha(20),
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (divided && i > 0)
                  MyDivider(thickness: 0.5, height: 1, color: dividerColor),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One label/value line inside a card.
Widget appleFormRow(String label, Widget child) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
    child: Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: colorManager.getSpecificTextColor(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: child),
      ],
    ),
  );
}

/// One label/switch line, with the switch pushed against the right edge so
/// that it lines up with the values of the rows above it.
Widget appleSwitchRow(String label, ValueNotifier<bool> valueNotifier) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
    child: Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: colorManager.getSpecificTextColor(),
          ),
        ),
        const Spacer(),
        MySwitch(valueNotifier: valueNotifier),
      ],
    ),
  );
}

/// A borderless, right aligned field, coloured by the app's theme.
Widget appleTextField(
  TextEditingController controller, {
  bool number = false,
  bool obscure = false,
  int maxLines = 1,
  String? placeholder,
  TextAlign? textAlign,
  ValueChanged<String>? onSubmitted,
  ValueChanged<String>? onChanged,
}) {
  final textColor = colorManager.getSpecificTextColor();

  return TextField(
    controller: controller,
    onSubmitted: onSubmitted,
    onChanged: onChanged,
    keyboardType: number ? TextInputType.number : null,
    obscureText: obscure,
    maxLines: maxLines,
    minLines: maxLines > 1 ? 3 : 1,
    textAlign: textAlign ?? (maxLines > 1 ? TextAlign.start : TextAlign.right),
    style: TextStyle(fontSize: 15, color: textColor),
    cursorColor: textColor,
    decoration: InputDecoration(
      isDense: true,
      border: InputBorder.none,
      hintText: placeholder,
      hintStyle: TextStyle(fontSize: 15, color: textColor.withAlpha(110)),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
    ),
  );
}

/// A label/value row with a plain text field.
Widget appleTextFieldRow(
  String label,
  TextEditingController controller, {
  bool number = false,
  bool obscure = false,
  String? placeholder,
  TextAlign? textAlign,
  ValueChanged<String>? onSubmitted,
  ValueChanged<String>? onChanged,
}) {
  return appleFormRow(
    label,
    appleTextField(
      controller,
      number: number,
      obscure: obscure,
      placeholder: placeholder,
      textAlign: textAlign,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
    ),
  );
}

/// An equally wide segmented picker, centred as a whole: every option keeps the
/// same width, so the selection sits in the middle of the card instead of
/// drifting to where the longest label happens to be.
Widget appleSegmented<T>(
  List<T> values,
  String Function(T) labelOf,
  T selected,
  ValueChanged<T> onChanged,
) {
  final textColor = colorManager.getSpecificTextColor();

  return Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    child: Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: textColor.withAlpha(24),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          for (final value in values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(value),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: value == selected
                          ? textColor.withAlpha(38)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      labelOf(value),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: textColor),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// A small rounded choice pill drawn from the app's own colours instead of
/// Material's chip surface. On the vivid theme a default chip paints a white
/// card over the tinted page; this keeps every pill on the same translucent
/// text colour the rest of the page uses.
Widget applePill(
  String label, {
  bool selected = false,
  bool showCheck = false,
  bool compact = false,
  VoidCallback? onTap,
}) {
  final textColor = colorManager.getSpecificTextColor();
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 9, vertical: 5)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: textColor.withAlpha(selected ? 48 : 14),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: textColor.withAlpha(selected ? 0 : 45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected && showCheck) ...[
            Icon(Icons.check_rounded, size: 13, color: textColor),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: textColor,
            ),
          ),
        ],
      ),
    ),
  );
}

/// The app's primary action: a rounded pill in the app's button colour.
Widget appleFilledButton(
  String label,
  VoidCallback? onPressed, {
  bool busy = false,
}) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor.value,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Text(label),
        ],
      ),
    ),
  );
}

/// A plain text action, for cancel / destructive actions.
Widget appleTextButton(String label, VoidCallback? onPressed, {Color? color}) {
  return TextButton(
    onPressed: onPressed,
    child: Text(
      label,
      style: TextStyle(
        color: color ?? colorManager.getSpecificTextColor(),
        fontSize: 15,
      ),
    ),
  );
}

/// A route for these pages: not opaque, so the app's own background - and the
/// vivid mode's frosted cover art - stays visible behind them, as it is on every
/// other page.
Route<T> applePageRoute<T>(Widget Function() builder) {
  return PageRouteBuilder<T>(
    // Opaque: these pages paint the app's opaque page colour, so letting the
    // page below stay visible only made their own text overlap with it.
    opaque: true,
    barrierColor: Colors.transparent,
    pageBuilder: (context, animation, secondaryAnimation) => builder(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}
