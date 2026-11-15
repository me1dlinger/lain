/// The index the rotating scrape deck moves to.
///
/// The deck wraps in both directions: pressing next on the last card shows the
/// first one again, which is what makes it feel like a deck being turned rather
/// than a list with ends.
int rotateCardIndex(int index, int delta, int length) {
  if (length <= 0) {
    return 0;
  }
  return ((index + delta) % length + length) % length;
}
