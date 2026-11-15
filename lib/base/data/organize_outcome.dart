/// Per-album summary of an organize run.
///
/// The organizer works per song, but the result that matters to the user is per
/// folder: which album gained its files, which were left alone because they were
/// already right, and which could not be moved. This file is the pure grouping
/// behind that summary, kept apart so its ordering and counting are testable.
library;

enum OrganizeOutcomeKind { organized, skipped, conflict, blocked, failed, pending }

class OrganizeOutcome {
  /// The folder the song belongs to: its new folder for a moved item, its
  /// current folder otherwise. Null for an item with no usable path.
  final String? directory;
  final OrganizeOutcomeKind kind;

  const OrganizeOutcome({required this.directory, required this.kind});
}

class AlbumOrganizeSummary {
  final String directory;
  int organized = 0;
  int skipped = 0;
  int conflict = 0;
  int blocked = 0;
  int failed = 0;
  int pending = 0;

  AlbumOrganizeSummary(this.directory);

  int get total =>
      organized + skipped + conflict + blocked + failed + pending;

  void add(OrganizeOutcomeKind kind) {
    switch (kind) {
      case OrganizeOutcomeKind.organized:
        organized++;
      case OrganizeOutcomeKind.skipped:
        skipped++;
      case OrganizeOutcomeKind.conflict:
        conflict++;
      case OrganizeOutcomeKind.blocked:
        blocked++;
      case OrganizeOutcomeKind.failed:
        failed++;
      case OrganizeOutcomeKind.pending:
        pending++;
    }
  }
}

/// Groups [outcomes] by folder, name order, with the counters filled in.
List<AlbumOrganizeSummary> summarizeOrganizeOutcomes(
  Iterable<OrganizeOutcome> outcomes,
) {
  final byDirectory = <String, AlbumOrganizeSummary>{};
  for (final outcome in outcomes) {
    final directory = outcome.directory ?? '';
    final summary = byDirectory.putIfAbsent(
      directory,
      () => AlbumOrganizeSummary(directory),
    );
    summary.add(outcome.kind);
  }
  final summaries = byDirectory.values.toList()
    ..sort((a, b) => a.directory.toLowerCase().compareTo(
      b.directory.toLowerCase(),
    ));
  return summaries;
}
