import 'package:material_ui/material_ui.dart';
import 'package:lain/base/services/color_manager.dart';

/// A quiet pulsing placeholder block, used while a list or a grid is being
/// built. It keeps the page layout stable, so the content does not jump when it
/// arrives.
class _Bone extends StatelessWidget {
  final double width;
  final double height;
  final double size;

  const _Bone({
    this.width = 0,
    this.height = 0,
    this.size = 0,
  });

  @override
  Widget build(BuildContext context) {
    final square = size > 0;
    return Container(
      width: square ? size : (width > 0 ? width : null),
      height: square ? size : (height > 0 ? height : null),
      decoration: BoxDecoration(
        color: colorManager.getSpecificTextColor().withAlpha(38),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

/// Drives the pulse shared by every placeholder on one page.
class _SkeletonPulse extends StatefulWidget {
  final Widget Function(BuildContext context, double opacity) builder;

  const _SkeletonPulse({required this.builder});

  @override
  State<_SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<_SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.35, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _opacity,
      builder: (context, child) => widget.builder(context, _opacity.value),
    );
  }
}

/// Rows shaped like a song list: cover, title line and a shorter subtitle line.
class SongListSkeleton extends StatelessWidget {
  final int itemCount;

  const SongListSkeleton({super.key, this.itemCount = 9});

  @override
  Widget build(BuildContext context) {
    return _SkeletonPulse(
      builder: (context, opacity) => Opacity(
        opacity: opacity,
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 8),
          itemCount: itemCount,
          separatorBuilder: (context, index) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const _Bone(size: 46),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Bone(width: 120 + (index * 23) % 90, height: 13),
                        const SizedBox(height: 7),
                        _Bone(width: 80 + (index * 17) % 60, height: 10),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Album/artist/playlist cards: a square cover with two short lines.
class CollectionSkeleton extends StatelessWidget {
  final bool grid;

  const CollectionSkeleton({super.key, this.grid = true});

  @override
  Widget build(BuildContext context) {
    final children = [
      for (var index = 0; index < 8; index++)
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (grid)
                AspectRatio(
                  aspectRatio: 1,
                  child: const _Bone(width: double.infinity, height: 13),
                )
              else
                const Align(
                  alignment: Alignment.centerLeft,
                  child: _Bone(size: 56),
                ),
              const SizedBox(height: 8),
              _Bone(width: 100 + (index * 19) % 50, height: 12),
              const SizedBox(height: 6),
              _Bone(width: 60 + (index * 13) % 30, height: 9),
            ],
          ),
        ),
    ];
    return _SkeletonPulse(
      builder: (context, opacity) => Opacity(
        opacity: opacity,
        child: grid
            ? GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                children: children,
              )
            : ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(8),
                children: children,
              ),
      ),
    );
  }
}
