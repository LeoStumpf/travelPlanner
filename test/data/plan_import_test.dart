import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/data/attachment_store.dart';
import 'package:travel_planner/data/db.dart';
import 'package:travel_planner/data/repository.dart';
import 'package:travel_planner/domain/demo.dart';
import 'package:travel_planner/domain/plan_exchange.dart';
import 'package:travel_planner/state/providers.dart';
import 'package:travel_planner/ui/exchange/plan_exchange_ui.dart';

void main() {
  late Directory tmp;
  late Repository repo;
  late ProviderContainer c;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('tp_plan');
    repo = Repository(AppDatabase(NativeDatabase.memory()), AttachmentStore(tmp));
    c = ProviderContainer(overrides: [repositoryProvider.overrideWithValue(repo)]);
  });

  tearDown(() async {
    c.dispose();
    await repo.close();
    await tmp.delete(recursive: true);
  });

  test('importing into a trip is one undoable step; removals unlink cleanly', () async {
    final demo = demoInterrail();
    await repo.putTripData(demo);
    final before = PlanExchange.exportText((await repo.loadTrip(demo.trip.id))!);
    final paris = demo.items.firstWhere((i) => i.title == 'Paris');
    final lyon = demo.items.firstWhere((i) => i.title == 'Lyon');
    final tgv = demo.items.firstWhere((i) => i.title.startsWith('TGV'));

    final doc = PlanExchange.parse(jsonEncode({
      'format': planFormat,
      'trip': {'title': 'Frankreich & Spanien'},
      'items': [
        {'ref': 'nice', 'kind': 'stay', 'title': 'Nizza', 'lat': 43.7, 'lng': 7.27},
        {'ref': tgv.id, 'notes': 'Sitzplatz 42'},
      ],
      // Both ends of the TGV: the second delete must not resurrect the first link.
      'remove': [paris.id, lyon.id],
    }));
    final data = (await repo.loadTrip(demo.trip.id))!;
    final imp = PlanExchange.apply(doc, into: data, now: DateTime.now(), newId: newId);
    await writePlanImport(c.read(planActionsProvider), imp);

    final after = (await repo.loadTrip(demo.trip.id))!;
    expect(after.trip.title, 'Frankreich & Spanien');
    expect(after.item(paris.id), isNull);
    expect(after.item(lyon.id), isNull);
    final t = after.item(tgv.id)!;
    expect([t.fromId, t.toId, t.notes], [null, null, 'Sitzplatz 42']);
    expect(after.items.where((i) => i.title == 'Nizza'), hasLength(1));
    expect(after.items.where((i) => i.parentId == paris.id || i.parentId == lyon.id), isEmpty);

    expect(await c.read(planActionsProvider).undo(demo.trip.id), 'Plan importiert');
    expect(PlanExchange.exportText((await repo.loadTrip(demo.trip.id))!), before);
  });

  test('importing as a new trip creates it', () async {
    final demo = demoSriLanka();
    final imp = PlanExchange.apply(PlanExchange.parse(PlanExchange.exportText(demo)),
        now: DateTime.now(), newId: newId);
    await writePlanImport(c.read(planActionsProvider), imp);
    final loaded = (await repo.loadTrip(imp.trip.id))!;
    expect(loaded.items, hasLength(demo.items.length));
    expect(loaded.cards, hasLength(demo.cards.length));
    expect(await repo.watchTrips().first, hasLength(1));
  });
}
