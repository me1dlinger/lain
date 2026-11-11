part of '../../layer/home_layer.dart';

extension HomePage on HomeLayerState {
  Widget pageView(BuildContext context) {
    // No title: the hub row below already says where you are, and a centred
    // "主页" only competed with the search icon.
    return myScaffold(
      context: context,
      body: content(context),
      actions: [
        // One global search across songs, albums, artists and playlists, rather
        // than a field that only filters the shelves shown here.
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            globalNavigatorKey.currentState?.push(
              themedRoute(
                (context) => const GlobalSearchPage(),
                picture: backgroundPicture,
              ),
            );
          },
        ),
      ],
    );
  }
}
