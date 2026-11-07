import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/data/config.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/data/loader.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/emby_client.dart';
import 'package:sylvakru/base/services/feiniu_client.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/services/keyboard.dart';
import 'package:sylvakru/base/services/navidrome_client.dart';
import 'package:sylvakru/base/services/stream_client.dart';
import 'package:sylvakru/base/services/system_ui_service.dart';
import 'package:sylvakru/base/services/taskbar_service.dart';
import 'package:sylvakru/base/utils/media_query.dart';
import 'package:sylvakru/base/utils/source_type.dart';
import 'package:sylvakru/base/widgets/server_manager.dart';
import 'package:sylvakru/base/widgets/manage_music_folders.dart';
import 'package:sylvakru/big_picture_view/big_picture_view.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/base/widgets/apple_form.dart';
import 'package:sylvakru/landscape_view/landscape_view.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/mini_view/mini_view.dart';
import 'package:sylvakru/portrait_view/portrait_view.dart';

class ViewEntry extends StatefulWidget {
  const ViewEntry({super.key});

  @override
  State<StatefulWidget> createState() => _ViewEntryState();
}

class _ViewEntryState extends State<ViewEntry> with WidgetsBindingObserver {
  // Bumped to rebuild the PopScope, so it keeps handling the back gesture.
  int keyValue = 0;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addObserver(this);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (Platform.isIOS) {
        if (!firstLaunch) {
          await Future.delayed(Duration(milliseconds: 500));
          await NativeMenu.init();
        }
        await NativeMenu.initIcons();
      } else if (Platform.isMacOS) {
        await NativeMenu.initIcons();
      } else if (Platform.isWindows) {
        setupTaskbar();
      }
    });
  }

  @override
  void dispose() {
    if (Platform.isAndroid) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (Platform.isAndroid) {
      if (state == .resumed) {
        applySystemUiMode(forceApply: true);
        // rebuild PopScope to allow it to handle pop
        setState(() {
          keyValue++;
        });
      } else if (isTV && state == .paused) {
        audioHandler.pause();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return view();
    }
    return PopScope(
      canPop: false,
      key: ValueKey(keyValue),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || isTyping || isTV) {
          return;
        }

        // 1) A detail page (album, artist, playlist, folder) is open: go back to
        //    the list it was opened from. This never reaches the exit flow.
        if (await layersManager.popDetail(currentRootLabel.value)) {
          return;
        }

        // 2) A root page other than the first one (the home hub switches root
        //    layers): go back to the page we came from.
        if (layersManager.popRootLayer()) {
          return;
        }

        // 3) Nothing left to go back to: leave the app straight away, with no
        //    "tap again" prompt.
        SystemNavigator.pop();
      },
      child: view(),
    );
  }

  Widget view() {
    if (firstLaunch) {
      return firstLaunchView();
    }
    return ValueListenableBuilder(
      valueListenable: viewModeNotifier,
      builder: (context, viewMode, child) {
        if (viewMode == .mini) {
          return MiniView();
        }
        if (viewMode == .bigPicture) {
          applyWideLayoutSystemUiMode();

          if (immersiveWideLayoutNotifier.value) {
            return BigPictureView();
          }
          SystemChrome.setSystemUIOverlayStyle(
            const SystemUiOverlayStyle(
              statusBarIconBrightness: Brightness.light,
            ),
          );
          return SafeArea(child: BigPictureView());
        }
        if (isTooNarrow(context)) {
          applySystemUiMode(mode: .manual);
          return PortraitView();
        }
        // immersiveSticky：上滑临时显示的系统栏是透明浮层、不派发 insets
        // 变化也会自动隐藏，全面屏手势可正常完成；immersive 被唤出后会常驻
        applyWideLayoutSystemUiMode();

        if (immersiveWideLayoutNotifier.value) {
          return LandscapeView();
        }
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(statusBarIconBrightness: Brightness.light),
        );
        return SafeArea(child: LandscapeView());
      },
    );
  }

  Widget firstLaunchView() {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 650;

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: MediaQuery.of(context).padding.top == 0
                          ? 20
                          : MediaQuery.of(context).padding.top,
                      bottom: 20,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Center(
                          child: Text(
                            l10n.chooseMusicSource,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    sliver: SliverGrid(
                      delegate: SliverChildListDelegate([
                        _buildSourceCard(
                          thisSourceType: .local,
                          color: iconColor.value,
                        ),
                        _buildSourceCard(
                          thisSourceType: .webdav,
                          color: iconColor.value,
                        ),
                        _buildSourceCard(thisSourceType: .navidrome),
                        _buildSourceCard(thisSourceType: .emby),
                        _buildSourceCard(thisSourceType: .feiniu),
                      ]),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isCompact ? 2 : 4,
                        mainAxisSpacing: 5,
                        crossAxisSpacing: 5,
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 10)),

                  if (sourceType != .local) ...[
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      sliver: SliverToBoxAdapter(
                        child: Card(
                          child: ListTile(
                            leading: Image(
                              image: getSourceTypeImage(sourceType),
                              width: 28,
                              height: 28,
                            ),
                            title: Text(l10n.servers),
                            subtitle: Text(
                              config.serversOf(sourceType).isEmpty
                                  ? l10n.addServer
                                  : config
                                        .serversOf(sourceType)
                                        .map((server) => server.name)
                                        .join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                            ),
                            onTap: () => globalNavigatorKey.currentState?.push(
                              applePageRoute<void>(() => const ServerListPage()),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 10)),
                  ],

                  if (isNotStreamSource) ...[
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      sliver: SliverToBoxAdapter(
                        child: Card(
                          child: ManageMusicFolders(key: ValueKey(sourceType)),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 10)),
                  ],

                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    sliver: SliverToBoxAdapter(
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          mouseCursor: SystemMouseCursors.click,
                          onTap: () async {
                            if (isStreamSource &&
                                streamClient == null &&
                                !await showConfirmDialog(
                                  context,
                                  "${getSourceTypeDisplayName(l10n, sourceType)} ${l10n.notConnected}",
                                )) {
                              return;
                            }
                            setState(() {
                              firstLaunch = false;
                            });

                            if (Platform.isIOS) {
                              WidgetsBinding.instance.addPostFrameCallback((
                                _,
                              ) async {
                                await NativeMenu.init();
                              });
                            }

                            config.save();
                            await Loader.firstSync();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            child: Center(child: Text(l10n.getStart)),
                          ),
                        ),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSourceCard({required SourceType thisSourceType, Color? color}) {
    return AspectRatio(
      aspectRatio: 1,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          onTap: () async {
            final existing = config.serversOf(thisSourceType);
            if (existing.isNotEmpty) {
              // Reuse the server already configured for this kind: it probes its
              // addresses and connects to the one that answers.
              await config.activateServer(existing.first);
            } else {
              sourceType = thisSourceType;
              isStreamSource =
                  sourceType == .navidrome ||
                  sourceType == .emby ||
                  sourceType == .feiniu;
              isNotStreamSource = !isStreamSource;
              streamClient = null;
              config.activeServerId = null;
              await config.save();
            }
            library = Library();
            if (isNotStreamSource) {
              await library.initFolders();
            }
            if (mounted) {
              setState(() {});
            }
          },
          child: Stack(
            children: [
              Transform.scale(
                scale: 0.6,
                child: Center(
                  child: Column(
                    children: [
                      Expanded(
                        child: Image(
                          image: getSourceTypeImage(thisSourceType),
                          color: color,
                        ),
                      ),
                      Text(
                        getSourceTypeDisplayName(
                          AppLocalizations.of(context),
                          thisSourceType,
                        ),
                        style: .new(fontSize: 22),
                      ),
                    ],
                  ),
                ),
              ),

              if (sourceType == thisSourceType)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(Icons.check_circle, color: Colors.black),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
