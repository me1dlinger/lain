part of '../../layer/home_layer.dart';

extension HomePage on HomeLayerState {
  Widget pageView(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // No title: the hub row below already says where you are, and a centred
    // "主页" only competed with the search icon.
    return myScaffold(
      context: context,
      body: content(context),
      actions: [
        MySearchField(hintText: l10n.searchHome, textController: textController),
      ],
    );
  }
}
