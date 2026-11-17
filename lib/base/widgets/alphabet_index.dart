import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// A thin A-Z strip along the edge of a list. Tapping a letter jumps there;
/// dragging down the strip walks through the letters and shows which one is
/// under the finger. Only the letters the list actually contains are shown,
/// so a list of Chinese titles still gives one letter per pinyin initial.
class AlphabetIndex extends StatefulWidget {
  final List<String> letters;
  final ValueChanged<String> onSelected;
  final Color color;

  const AlphabetIndex({
    super.key,
    required this.letters,
    required this.onSelected,
    required this.color,
  });

  @override
  State<AlphabetIndex> createState() => _AlphabetIndexState();
}

class _AlphabetIndexState extends State<AlphabetIndex> {
  String? _active;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _select(String letter, {bool keepBubble = true}) {
    _hideTimer?.cancel();
    if (_active != letter) {
      setState(() => _active = letter);
    }
    widget.onSelected(letter);
    if (!keepBubble) {
      _hideTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() => _active = null);
        }
      });
    }
  }

  void _pick(double dy, double height, {bool keepBubble = true}) {
    if (widget.letters.isEmpty || height <= 0) {
      return;
    }
    final index = (dy / height * widget.letters.length)
        .floor()
        .clamp(0, widget.letters.length - 1);
    _select(widget.letters[index], keepBubble: keepBubble);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: IgnorePointer(
              child: AnimatedOpacity(
              opacity: _active == null ? 0 : 1,
              duration: const Duration(milliseconds: 150),
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.color.withAlpha(26),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    _active ?? '',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: widget.color,
                    ),
                  ),
                ),
              ),
            ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    _pick(details.localPosition.dy, constraints.maxHeight);
                  },
                  onVerticalDragStart: (details) {
                    _pick(details.localPosition.dy, constraints.maxHeight);
                  },
                  onVerticalDragUpdate: (details) {
                    _pick(details.localPosition.dy, constraints.maxHeight);
                  },
                  onVerticalDragEnd: (_) {
                    _hideTimer?.cancel();
                    _hideTimer = Timer(const Duration(milliseconds: 250), () {
                      if (mounted) {
                        setState(() => _active = null);
                      }
                    });
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final letter in widget.letters)
                        Expanded(
                          child: Center(
                            child: Text(
                              letter,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: widget.color.withAlpha(185),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
