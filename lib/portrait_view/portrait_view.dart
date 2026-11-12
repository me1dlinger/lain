import 'package:material_ui/material_ui.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/layer/layers_manager.dart';
import 'package:lain/portrait_view/play_bar.dart';

final GlobalKey<ScaffoldState> portraitKey = GlobalKey();
final endDrawerNotifier = ValueNotifier(false);

class PortraitView extends StatefulWidget {
  const PortraitView({super.key});

  @override
  State<StatefulWidget> createState() => _PortraitViewState();
}

class _PortraitViewState extends State<PortraitView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<Offset> _backSlideAnimation;

  void slideBegin() {
    _controller.forward(from: 0);
  }

  void statusListener(AnimationStatus status) {
    if (status != .completed) {
      return;
    }
    if (layersManager.bottomRootPage != null) {
      layersManager.bottomRootPage = null;
      layersManager.rootGoingBack = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  void updateDrawerSetting() {
    setState(() {
      _slideAnimation =
          Tween<Offset>(
            begin: Offset(endDrawerNotifier.value ? 1.0 : -1.0, 0.0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: _controller, curve: Curves.linearToEaseOut),
          );
      _backSlideAnimation =
          Tween<Offset>(
            begin: Offset.zero,
            end: Offset(endDrawerNotifier.value ? 1.0 : -1.0, 0.0),
          ).animate(
            CurvedAnimation(parent: _controller, curve: Curves.linearToEaseOut),
          );
    });
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      // The same length as the settings sub-page transition and the app's
      // standard page transition, so drawer moves feel like one system.
      duration: const Duration(milliseconds: 300),
    );

    _controller.addStatusListener(statusListener);

    _slideAnimation =
        Tween<Offset>(
          begin: Offset(endDrawerNotifier.value ? 1.0 : -1.0, 0.0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: _controller, curve: Curves.linearToEaseOut),
        );
    _backSlideAnimation =
        Tween<Offset>(
          begin: Offset.zero,
          end: Offset(endDrawerNotifier.value ? 1.0 : -1.0, 0.0),
        ).animate(
          CurvedAnimation(parent: _controller, curve: Curves.linearToEaseOut),
        );

    endDrawerNotifier.addListener(updateDrawerSetting);
    layersManager.switchNotifier.addListener(slideBegin);
    _controller.forward(from: 1);
  }

  @override
  void dispose() {
    endDrawerNotifier.removeListener(updateDrawerSetting);
    layersManager.switchNotifier.removeListener(slideBegin);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: portraitKey,
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          ValueListenableBuilder(
            valueListenable: layersManager.switchNotifier,
            builder: (context, _, _) {
              // A step back slides the old page out, revealing the page it
              // came from; a forward step slides the new page in. This keeps
              // back the reverse of forward at the root layer too, as it
              // already is for settings sub-pages.
              if (layersManager.rootGoingBack &&
                  layersManager.bottomRootPage != null &&
                  layersManager.topRootPage != null) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    layersManager.topRootPage!,
                    SlideTransition(
                      position: _backSlideAnimation,
                      child: layersManager.bottomRootPage!,
                    ),
                  ],
                );
              }
              return Stack(
                children: [
                  ...layersManager.rootPageMap.values
                      .where((page) => page != layersManager.topRootPage)
                      .map((page) {
                        return Visibility(
                          visible: page == layersManager.bottomRootPage,
                          maintainState: true,
                          child: page,
                        );
                      }),
                  if (layersManager.bottomRootPage == null)
                    layersManager.topRootPage!
                  else
                    SlideTransition(
                      position: _slideAnimation,
                      child: layersManager.topRootPage,
                    ),
                ],
              );
            },
          ),

          Positioned(left: 20, right: 20, bottom: 40, child: PlayBar()),
        ],
      ),
    );
  }
}
