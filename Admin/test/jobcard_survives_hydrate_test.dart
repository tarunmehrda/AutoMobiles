import 'package:flutter_test/flutter_test.dart';

import 'package:garagepro_admin/data/models/entities.dart';
import 'package:garagepro_admin/data/repo/garage_gateway.dart';

/// A job card must outlive a snapshot that has never heard of it.
///
/// The console pushes a card through `save_job_card()`. When that call
/// fails the step is kept local on purpose, so the card exists only on the
/// phone. The next hydrate then used to copy the server's list straight
/// over the local one, and the card — with its bill and its payments —
/// ceased to exist. It happened to a closed, settled card on a real
/// handset: the money was taken, the invoice was handed over, and the
/// workshop had no record of either.
///
/// These are the two halves of the rule the merge now enforces.
void main() {
  JobCard card(String id, String number) => JobCard(
    id: id,
    number: number,
    customerId: 'c1',
    vehicleId: 'v1',
    createdAt: DateTime(2026, 9, 21),
  );

  test('a card the server has never seen is kept', () {
    final merged = GarageGateway.debugMergeCards(
      [card('local-1', 'A0921-001')],
      const [],
    );

    expect(merged.map((c) => c.id), ['local-1']);
  });

  test('the server decides what a card it does have contains', () {
    final stale = card('shared-1', 'A0921-001');
    final upstream = card('shared-1', 'A0921-009');

    final merged = GarageGateway.debugMergeCards([stale], [upstream]);

    expect(merged, hasLength(1));
    expect(merged.single.number, 'A0921-009');
  });

  test('cards on both sides are not duplicated, and orphans come last', () {
    final merged = GarageGateway.debugMergeCards(
      [card('shared-1', 'A0921-001'), card('local-2', 'A0921-002')],
      [card('shared-1', 'A0921-001')],
    );

    expect(merged.map((c) => c.id), ['shared-1', 'local-2']);
  });
}
