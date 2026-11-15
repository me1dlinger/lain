import 'package:flutter_test/flutter_test.dart';
import 'package:lain/base/data/organize_outcome.dart';

void main() {
  test('groups outcomes by folder and counts each status', () {
    final summaries = summarizeOrganizeOutcomes(const [
      OrganizeOutcome(
        directory: r'Music\A\Album',
        kind: OrganizeOutcomeKind.organized,
      ),
      OrganizeOutcome(
        directory: r'Music\A\Album',
        kind: OrganizeOutcomeKind.organized,
      ),
      OrganizeOutcome(
        directory: r'Music\A\Album',
        kind: OrganizeOutcomeKind.conflict,
      ),
      OrganizeOutcome(
        directory: r'Music\B\Other',
        kind: OrganizeOutcomeKind.skipped,
      ),
    ]);

    expect(summaries.length, 2);
    expect(summaries.first.directory, r'Music\A\Album');
    expect(summaries.first.organized, 2);
    expect(summaries.first.conflict, 1);
    expect(summaries.first.total, 3);
    expect(summaries.last.skipped, 1);
  });

  test('sorts the folders by name, case-insensitively', () {
    final summaries = summarizeOrganizeOutcomes(const [
      OrganizeOutcome(directory: 'beta', kind: OrganizeOutcomeKind.organized),
      OrganizeOutcome(directory: 'Alpha', kind: OrganizeOutcomeKind.organized),
      OrganizeOutcome(directory: 'gamma', kind: OrganizeOutcomeKind.organized),
    ]);
    expect(
      [for (final summary in summaries) summary.directory],
      ['Alpha', 'beta', 'gamma'],
    );
  });

  test('an item with no usable path is kept in its own group', () {
    final summaries = summarizeOrganizeOutcomes(const [
      OrganizeOutcome(directory: null, kind: OrganizeOutcomeKind.blocked),
    ]);
    expect(summaries.single.directory, '');
    expect(summaries.single.blocked, 1);
  });

  test('pending is what a run did not reach', () {
    final summaries = summarizeOrganizeOutcomes(const [
      OrganizeOutcome(
        directory: r'Music\A\Album',
        kind: OrganizeOutcomeKind.organized,
      ),
      OrganizeOutcome(
        directory: r'Music\A\Album',
        kind: OrganizeOutcomeKind.pending,
      ),
      OrganizeOutcome(
        directory: r'Music\A\Album',
        kind: OrganizeOutcomeKind.failed,
      ),
    ]);
    expect(summaries.single.organized, 1);
    expect(summaries.single.pending, 1);
    expect(summaries.single.failed, 1);
    expect(summaries.single.total, 3);
  });
}
