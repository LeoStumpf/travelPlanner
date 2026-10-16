import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/data/attachment_store.dart';
import 'package:travel_planner/data/db.dart';
import 'package:travel_planner/data/repository.dart';
import 'package:travel_planner/domain/demo.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/domain/time.dart';
import 'package:travel_planner/state/providers.dart';
import 'package:travel_planner/ui/timeline/timeline_view.dart';

void main() {
  late Repository repo;

  setUp(() {
    repo = Repository(AppDatabase(NativeDatabase.memory()), AttachmentStore(Directory.systemTemp));
  });

  tearDown(() => repo.close());

  Future<TripData> pump(WidgetTester tester) async {
    final data = demoInterrail();
    await tester.runAsync(() => repo.putTripData(data));
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(home: Scaffold(body: TimelineView(data: data))),
    ));
    return data;
  }

  testWidgets('shows stays, free days, missing nights and unscheduled ideas', (tester) async {
    await pump(tester);
    expect(find.text('Paris'), findsOneWidget);
    expect(find.text('Barcelona'), findsOneWidget);
    expect(find.text('2 Tage frei'), findsOneWidget);
    // Lyon (only options) and Valencia have no confirmed bed: 2 + 2 nights.
    expect(find.byIcon(Icons.bed_outlined), findsNWidgets(4));
    expect(find.text('Ohne Termin:'), findsOneWidget);
    expect(find.text('Avignon'), findsOneWidget);
  });

  testWidgets('long-press drag moves a stay and everything after it', (tester) async {
    final data = await pump(tester);
    final lyon = data.items.firstWhere((i) => i.title == 'Lyon');
    final bcn = data.items.firstWhere((i) => i.title == 'Barcelona');

    final g = await tester.startGesture(tester.getCenter(find.text('Lyon')));
    await tester.pump(const Duration(milliseconds: 700));
    await g.moveBy(const Offset(35, 0));
    await tester.pump();
    await g.moveBy(const Offset(35, 0)); // ~1 day at 64 px per day
    await tester.pump();
    await g.up();
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));

    final after = (await tester.runAsync(() => repo.loadTrip(data.trip.id)))!;
    expect(dayOf(after.item(lyon.id)!.start!), dayOf(lyon.start!) + 1);
    expect(dayOf(after.item(bcn.id)!.start!), dayOf(bcn.start!) + 1);
    // The booked flight home is fixed.
    final flight = data.items.firstWhere((i) => i.fixed && i.kind == ItemKind.transport);
    expect(after.item(flight.id)!.start, flight.start);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('two-finger pinch zooms the time axis', (tester) async {
    await pump(tester);
    double dayWidth() => tester.getTopLeft(find.text('Tag 2')).dx - tester.getTopLeft(find.text('Tag 1')).dx;
    final before = dayWidth();

    final center = tester.getCenter(find.text('Tag 2')) + const Offset(0, 200);
    final a = await tester.startGesture(center - const Offset(40, 0), pointer: 1);
    final b = await tester.startGesture(center + const Offset(40, 0), pointer: 2);
    await tester.pump();
    for (var k = 0; k < 5; k++) {
      await a.moveBy(const Offset(-16, 0));
      await b.moveBy(const Offset(16, 0));
      await tester.pump();
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();

    expect(dayWidth(), greaterThan(before * 1.8));
  });
}
