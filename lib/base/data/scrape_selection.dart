import 'package:lain/base/data/scrape_deck.dart';

/// The closest match in [scores], or -1 when there is none.
///
/// Ties keep the first entry, which is the source's own relevance order after
/// the scorer sorted the candidates.
int bestCandidateIndex(Iterable<double> scores) {
  final list = scores.toList();
  if (list.isEmpty) {
    return -1;
  }
  var best = 0;
  for (var i = 1; i < list.length; i++) {
    if (list[i] > list[best]) {
      best = i;
    }
  }
  return best;
}

/// Moves [current] by [delta], wrapping, until it reaches an entry where
/// [hasValue] is true. Returns [current] when nothing has a value.
int nextIndexWithValue(List<bool> hasValue, int current, int delta) {
  if (hasValue.isEmpty) {
    return -1;
  }
  if (!hasValue.contains(true)) {
    return current.clamp(0, hasValue.length - 1);
  }
  final step = delta == 0 ? 1 : delta.sign;
  for (var distance = 1; distance <= hasValue.length; distance++) {
    final index = rotateCardIndex(
      current,
      step * distance,
      hasValue.length,
    );
    if (hasValue[index]) {
      return index;
    }
  }
  return current.clamp(0, hasValue.length - 1);
}
