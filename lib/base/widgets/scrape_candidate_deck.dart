import 'dart:typed_data';

import 'package:lain/base/data/scrape_deck.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/metadata_scraper.dart';
import 'package:lain/base/widgets/scrape_candidate_card.dart';
import 'package:lain/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The rotating deck of scrape candidates for one song.
///
/// One card is centred at a time; the arrows turn the deck (wrapping in both
/// directions) and the counter shows where the deck is. Tapping a card selects
/// it, long-pressing applies it. The card itself, including its cover loading,
/// is shared with the batch swipe stack.
class ScrapeCandidateDeck extends StatefulWidget {
  final List<ScrapedCandidate> cards;
  final int selectedIndex;

  /// Changes when the deck shows another result set, so the page position
  /// starts over instead of staying on an index that no longer exists.
  final String deckKey;

  final String Function(ScrapedCandidate candidate) sourceName;
  final Future<Uint8List?> Function(ScrapedCandidate candidate) coverLoader;
  final ValueChanged<int> onSelected;
  final ValueChanged<ScrapedCandidate> onLongPress;
  final double height;

  const ScrapeCandidateDeck({
    super.key,
    required this.cards,
    required this.selectedIndex,
    required this.deckKey,
    required this.sourceName,
    required this.coverLoader,
    required this.onSelected,
    required this.onLongPress,
    this.height = 236,
  });

  @override
  State<ScrapeCandidateDeck> createState() => _ScrapeCandidateDeckState();
}

class _ScrapeCandidateDeckState extends State<ScrapeCandidateDeck> {
  late final PageController _controller = PageController(
    viewportFraction: 0.84,
  );
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _index = _clampIndex(widget.selectedIndex);
  }

  @override
  void didUpdateWidget(covariant ScrapeCandidateDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deckKey != widget.deckKey) {
      _index = _clampIndex(widget.selectedIndex);
      _jumpTo(_index);
      return;
    }
    if (widget.selectedIndex != _index) {
      _index = _clampIndex(widget.selectedIndex);
      _jumpTo(_index);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _clampIndex(int index) {
    if (widget.cards.isEmpty) {
      return 0;
    }
    return index.clamp(0, widget.cards.length - 1);
  }

  void _jumpTo(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.hasClients) {
        _controller.jumpToPage(index);
      }
    });
  }

  void _turn(int delta) {
    if (widget.cards.isEmpty) {
      return;
    }
    final next = rotateCardIndex(_index, delta, widget.cards.length);
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();
    if (widget.cards.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.cards.length,
            onPageChanged: (index) {
              _index = index;
              widget.onSelected(index);
            },
            itemBuilder: (context, index) => ScrapeCandidateCard(
              key: ValueKey(widget.cards[index].key),
              candidate: widget.cards[index],
              sourceName: widget.sourceName(widget.cards[index]),
              coverLoader: widget.coverLoader,
              selected: index == _index,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () => _turn(-1),
              icon: Icon(Icons.chevron_left_rounded, color: textColor),
              tooltip: l10n.previousCard,
            ),
            Text(
              '${_index + 1} / ${widget.cards.length}',
              style: TextStyle(fontSize: 13, color: textColor.withAlpha(170)),
            ),
            IconButton(
              onPressed: () => _turn(1),
              icon: Icon(Icons.chevron_right_rounded, color: textColor),
              tooltip: l10n.nextCard,
            ),
          ],
        ),
      ],
    );
  }
}
