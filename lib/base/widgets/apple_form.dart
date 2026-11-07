import 'package:flutter/cupertino.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/color_manager.dart';

/// iOS-style form pieces shared by the app's dialogs.
///
/// The values are grouped in inset cards with the label on the left and the
/// value right aligned, which is what makes a form read as a native iOS form;
/// the filled button uses the app's text colour as its tint so it stays
/// monochrome instead of taking Material's accent colour.

/// Wraps [child] with a Cupertino theme that follows the app's own light/dark
/// setting (Cupertino would otherwise follow the platform's).
Widget appleFormTheme({required Widget child}) {
  return CupertinoTheme(
    data: CupertinoThemeData(
      brightness: mainPageThemeNotifier.value == .dark
          ? Brightness.dark
          : Brightness.light,
      primaryColor: colorManager.getSpecificTextColor(),
    ),
    child: child,
  );
}

/// One inset card, optionally with a small heading above it.
class AppleFormSection extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const AppleFormSection({super.key, this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return CupertinoFormSection.insetGrouped(
      header: title == null ? null : Text(title!),
      children: children,
    );
  }
}

/// One label/value line inside a section.
Widget appleFormRow(String label, Widget child) {
  return CupertinoFormRow(
    prefix: Text(label, style: const TextStyle(fontSize: 15)),
    child: child,
  );
}

/// A borderless, right aligned text field as used inside a form row.
Widget appleTextField(
  TextEditingController controller, {
  bool number = false,
  bool obscure = false,
  int maxLines = 1,
  String? placeholder,
}) {
  return CupertinoTextField(
    controller: controller,
    placeholder: placeholder,
    keyboardType: number ? TextInputType.number : null,
    obscureText: obscure,
    maxLines: maxLines,
    minLines: maxLines > 1 ? 3 : 1,
    textAlign: maxLines > 1 ? TextAlign.start : TextAlign.right,
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: const BoxDecoration(),
    style: const TextStyle(fontSize: 15),
  );
}

/// A label/value row with a plain text field.
Widget appleTextFieldRow(
  String label,
  TextEditingController controller, {
  bool number = false,
  bool obscure = false,
  String? placeholder,
}) {
  return appleFormRow(
    label,
    appleTextField(
      controller,
      number: number,
      obscure: obscure,
      placeholder: placeholder,
    ),
  );
}

/// Apple's primary action: a filled pill, monochrome.
Widget appleFilledButton(String label, VoidCallback? onPressed) {
  return CupertinoButton.filled(
    borderRadius: BorderRadius.circular(14),
    padding: const EdgeInsets.symmetric(vertical: 14),
    onPressed: onPressed,
    child: Text(label),
  );
}

/// A plain text action, for cancel / destructive actions.
Widget appleTextButton(
  String label,
  VoidCallback? onPressed, {
  Color? color,
}) {
  return CupertinoButton(
    onPressed: onPressed,
    child: Text(label, style: TextStyle(color: color)),
  );
}