import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/data/attachment_store.dart';
import 'package:travel_planner/data/db.dart';
import 'package:travel_planner/data/repository.dart';
import 'package:travel_planner/domain/demo.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/state/providers.dart';

void main() {
  late Directory tmp;
  late Repository repo;
  late ProviderContainer c;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('tp_undo');
    repo = Repository(AppDatabase(NativeDatabase.memory()), AttachmentStore(tmp));
    c = ProviderContainer(overrides: [repositoryProvider.overrideWithValue(repo)]);
  });

  tearDown(() async {
    c.dispose();
    await repo.close();
    await tmp.delete(recursive: true);
  });

  test('deleting a card with an attachment can be undone, file included', () async {
    final demo = demoInterrail();
    await repo.putTripData(demo);
    final card = demo.cards.first;
    final att = await repo.files.addBytes(
      tripId: demo.trip.id,
      ownerId: card.id,
      bytes: Uint8List.fromList([7, 7, 7]),
      fileName: 'screenshot.png',
    );
    await repo.saveAttachment(att);
    final actions = c.read(planActionsProvider);

    final data = (await repo.loadTrip(demo.trip.id))!;
    await actions.record(demo.trip.id, 'Notiz gelöscht', (r) => r.deleteCard(data, card.id));
    expect((await repo.loadTrip(demo.trip.id))!.card(card.id), isNull);
    expect(await repo.files.fileFor(att).exists(), isFalse);

    expect(await actions.undo(demo.trip.id), 'Notiz gelöscht');
    final restored = (await repo.loadTrip(demo.trip.id))!;
    expect(restored.card(card.id), isNotNull);
    expect(restored.attachmentsOf(card.id), hasLength(1));
    expect(await repo.files.fileFor(att).readAsBytes(), [7, 7, 7]);
  });

  test('edges, trip settings and history per trip', () async {
    final a = demoInterrail(), b = demoSriLanka();
    await repo.putTripData(a);
    await repo.putTripData(b);
    final actions = c.read(planActionsProvider);

    await actions.record(a.trip.id, 'Verbindung erstellt', (r) => r.saveEdge(Edge(
          id: 'e1',
          tripId: a.trip.id,
          fromId: a.items.first.id,
          toId: a.items.last.id,
        )));
    await actions.record(a.trip.id, 'Reise bearbeitet', (r) => r.saveTrip(a.trip.copyWith(title: 'Neu')));
    await actions.record(b.trip.id, 'Reise bearbeitet', (r) => r.saveTrip(b.trip.copyWith(title: 'Andere')));

    expect(c.read(undoLabelProvider(a.trip.id)), 'Reise bearbeitet');
    await actions.undo(a.trip.id);
    expect((await repo.loadTrip(a.trip.id))!.trip.title, a.trip.title);
    expect((await repo.loadTrip(b.trip.id))!.trip.title, 'Andere', reason: 'other trip untouched');

    expect(c.read(undoLabelProvider(a.trip.id)), 'Verbindung erstellt');
    await actions.undo(a.trip.id);
    expect((await repo.loadTrip(a.trip.id))!.edges.where((e) => e.id == 'e1'), isEmpty);
    expect(c.read(undoLabelProvider(a.trip.id)), isNull);
  });

  test('undoing an added attachment moves its file away', () async {
    final demo = demoSriLanka();
    await repo.putTripData(demo);
    final actions = c.read(planActionsProvider);
    late Attachment att;
    await actions.record(demo.trip.id, 'angehängt', (r) async {
      att = await r.files.addBytes(
          tripId: demo.trip.id, ownerId: demo.items.first.id, bytes: Uint8List(3), fileName: 'ticket.pdf');
      await r.saveAttachment(att);
    });
    await actions.undo(demo.trip.id);
    expect((await repo.loadTrip(demo.trip.id))!.attachments, isEmpty);
    expect(await repo.files.fileFor(att).exists(), isFalse);
  });

  test('a snackbar undo only reverts its own step', () async {
    final demo = demoInterrail();
    await repo.putTripData(demo);
    final actions = c.read(planActionsProvider);
    final id = demo.trip.id;
    final a = demo.items.first, b = demo.items.last;

    await actions.deleteItem((await repo.loadTrip(id))!, a.id);
    final step = actions.lastStep(id);
    await actions.deleteItem((await repo.loadTrip(id))!, b.id);

    // Another change came after the delete: the snackbar must not revert it.
    expect(await actions.undoStep(id, step), isFalse);
    expect((await repo.loadTrip(id))!.item(b.id), isNull);

    // Once the later change is undone, the step is the last again.
    await actions.undo(id);
    expect(await actions.undoStep(id, step), isTrue);
    expect((await repo.loadTrip(id))!.item(a.id), isNotNull);

    // Tapping twice (or after the app bar's undo) does nothing more.
    expect(await actions.undoStep(id, step), isFalse);
    expect(actions.lastStep(id), isNull);
  });
}
