import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/data/attachment_store.dart';
import 'package:travel_planner/data/db.dart';
import 'package:travel_planner/data/repository.dart';
import 'package:travel_planner/domain/demo.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/ui/trips/trash_page.dart';

import '../l10n_test_utils.dart';

void main() {
  late Directory tmp;
  late Repository repo;
  late TripData demo;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('tp_trash');
    repo = Repository(AppDatabase(NativeDatabase.memory()), AttachmentStore(tmp));
    demo = demoInterrail();
    await repo.putTripData(demo);
  });

  tearDown(() async {
    await repo.close();
    await tmp.delete(recursive: true);
  });

  Future<Attachment> attach() async {
    final att = await repo.files.addBytes(
      tripId: demo.trip.id,
      ownerIds: [demo.items.first.id],
      bytes: Uint8List.fromList([1, 2, 3]),
      fileName: 'ticket.pdf',
    );
    await repo.saveAttachment(att);
    return att;
  }

  test('a trashed trip leaves the list but keeps its data and files', () async {
    final att = await attach();
    await repo.trashTrip(demo.trip.id, now: DateTime(2026, 10, 1));
    expect(await repo.watchTrips().first, isEmpty);
    final trash = await repo.watchTrash().first;
    expect(trash.single.trip.id, demo.trip.id);
    expect(trash.single.deletedAt, DateTime(2026, 10, 1));
    expect(trash.single.purgeAt, DateTime(2026, 10, 1).add(const Duration(days: 30)));
    final data = (await repo.loadTrip(demo.trip.id))!;
    expect(data.items, hasLength(demo.items.length));
    expect(await repo.files.fileFor(att).exists(), isTrue);
  });

  test('restoring brings the trip back unchanged', () async {
    await repo.trashTrip(demo.trip.id);
    await repo.restoreFromTrash(demo.trip.id);
    expect((await repo.watchTrips().first).single.id, demo.trip.id);
    expect(await repo.loadTrash(), isEmpty);
    expect((await repo.loadTrip(demo.trip.id))!.cards, hasLength(demo.cards.length));
  });

  test('purge removes only trips older than 30 days, with their files', () async {
    final att = await attach();
    final other = demoSriLanka();
    await repo.putTripData(other);
    await repo.trashTrip(demo.trip.id, now: DateTime(2026, 9, 1));
    await repo.trashTrip(other.trip.id, now: DateTime(2026, 10, 10));

    expect(await repo.purgeTrash(now: DateTime(2026, 10, 17)), 1);
    expect(await repo.loadTrip(demo.trip.id), isNull);
    expect(await repo.files.fileFor(att).exists(), isFalse);
    expect((await repo.loadTrash()).single.trip.id, other.trip.id);

    expect(await repo.purgeTrash(now: DateTime(2026, 11, 10)), 1);
    expect(await repo.loadTrash(), isEmpty);
    expect(await repo.watchTrips().first, isEmpty);
  });

  test('deleting for good also removes the trash marker', () async {
    await repo.trashTrip(demo.trip.id);
    await repo.deleteTrip(demo.trip.id);
    expect(await repo.loadTrash(), isEmpty);
    expect(await repo.snapshotTrip(demo.trip.id), isEmpty);
  });

  test('purge hint counts the remaining days', () {
    final now = DateTime(2026, 10, 17, 12);
    expect(purgeHint(de, DateTime(2026, 10, 27, 12), now), 'Wird in 10 Tagen endgültig gelöscht');
    expect(purgeHint(de, DateTime(2026, 10, 18, 13), now), 'Wird morgen endgültig gelöscht');
    expect(purgeHint(de, DateTime(2026, 10, 17, 22), now), 'Wird beim nächsten Start endgültig gelöscht');
  });
}
