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
import 'package:travel_planner/ui/canvas/canvas_view.dart';
import 'package:travel_planner/ui/timeline/timeline_view.dart';

import '../l10n_test_utils.dart';

void main() {
  late Repository repo;
  late ProviderContainer container;

  setUp(() {
    repo = Repository(AppDatabase(NativeDatabase.memory()), AttachmentStore(Directory.systemTemp));
    container = ProviderContainer(overrides: [repositoryProvider.overrideWithValue(repo)]);
  });

  tearDown(() async {
    container.dispose();
    await repo.close();
  });

  Future<TripData> pump(
    WidgetTester tester,
    Widget Function(TripData) view, {
    Size size = const Size(1600, 900),
  }) async {
    final data = demoInterrail();
    await tester.runAsync(() => repo.putTripData(data));
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: testApp(home: Scaffold(body: view(data))),
      ),
    );
    await tester.pump();
    await tester.pump();
    return data;
  }

  Future<TripData> reload(WidgetTester tester, TripData data) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    return (await tester.runAsync(() => repo.loadTrip(data.trip.id)))!;
  }

  int undoSteps(TripData data) => container.read(undoProvider)[data.trip.id]?.length ?? 0;

  group('canvas', () {
    Finder node(String title) => find.descendant(of: find.byType(CanvasView), matching: find.text(title)).first;

    testWidgets('a one-finger swipe on a node pans the canvas, not the node', (tester) async {
      final data = await pump(tester, (d) => CanvasView(data: d));
      final paris = data.items.firstWhere((i) => i.title == 'Paris');
      final before = tester.getCenter(node('Paris'));

      await tester.drag(node('Paris'), const Offset(150, 60));
      await tester.pumpAndSettle();

      // The whole canvas moved with the finger.
      final after = tester.getCenter(node('Paris'));
      expect(after.dx - before.dx, greaterThan(100));
      final saved = await reload(tester, data);
      expect(saved.item(paris.id)!.canvasX, isNull);
      expect(undoSteps(data), 0);
    });

    testWidgets('long press then drag moves the node and records one undo step', (tester) async {
      final data = await pump(tester, (d) => CanvasView(data: d));
      final paris = data.items.firstWhere((i) => i.title == 'Paris');
      final lyonBefore = tester.getCenter(node('Lyon'));

      final g = await tester.startGesture(tester.getCenter(node('Paris')));
      await tester.pump(const Duration(milliseconds: 700));
      await g.moveBy(const Offset(40, 0));
      await tester.pump();
      await g.moveBy(const Offset(40, 30));
      await tester.pump();
      await g.up();
      final saved = await reload(tester, data);

      expect(saved.item(paris.id)!.canvasX, isNotNull);
      expect(undoSteps(data), 1);
      // Other nodes stayed where they were (no panning).
      expect(tester.getCenter(node('Lyon')), lyonBefore);
    });

    testWidgets('a long press without movement saves nothing', (tester) async {
      final data = await pump(tester, (d) => CanvasView(data: d));
      final paris = data.items.firstWhere((i) => i.title == 'Paris');

      final g = await tester.startGesture(tester.getCenter(node('Paris')));
      await tester.pump(const Duration(milliseconds: 700));
      await g.moveBy(const Offset(1, 1));
      await tester.pump();
      await g.up();
      final saved = await reload(tester, data);

      expect(saved.item(paris.id)!.canvasX, isNull);
      expect(undoSteps(data), 0);
    });
  });

  group('timeline resize handles', () {
    testWidgets('only the selected block shows handles of at least 24 dp', (tester) async {
      final data = await pump(tester, (d) => TimelineView(data: d));
      final lyon = data.items.firstWhere((i) => i.title == 'Lyon');
      expect(find.byKey(ValueKey('resizeStart-${lyon.id}')), findsNothing);
      expect(find.byKey(ValueKey('resizeEnd-${lyon.id}')), findsNothing);

      container.read(tripUiProvider.notifier).select(lyon.id);
      await tester.pump();

      final start = find.byKey(ValueKey('resizeStart-${lyon.id}'));
      final end = find.byKey(ValueKey('resizeEnd-${lyon.id}'));
      expect(start, findsOneWidget);
      expect(end, findsOneWidget);
      expect(tester.getSize(start).width, greaterThanOrEqualTo(24));
      expect(tester.getSize(start).height, greaterThanOrEqualTo(24));
      expect(tester.getSize(end).width, greaterThanOrEqualTo(24));
      // Centred on the block's right edge.
      final block = tester.getRect(find.byKey(ValueKey(lyon.id)));
      expect(tester.getCenter(end).dx, closeTo(block.right, 0.5));
    });

    testWidgets('fixed blocks get no handles even when selected', (tester) async {
      final data = await pump(tester, (d) => TimelineView(data: d));
      final flight = data.items.firstWhere((i) => i.fixed && i.kind == ItemKind.transport);
      container.read(tripUiProvider.notifier).select(flight.id);
      await tester.pump();
      expect(find.byKey(ValueKey('resizeEnd-${flight.id}')), findsNothing);
    });

    testWidgets('a horizontal swipe over an unselected block edge scrolls instead of resizing', (tester) async {
      // Narrow screen, so the timeline can scroll.
      final data = await pump(tester, (d) => TimelineView(data: d), size: const Size(500, 900));
      final lyon = data.items.firstWhere((i) => i.title == 'Lyon');
      final block = tester.getRect(find.byKey(ValueKey(lyon.id)));
      final before = tester.getTopLeft(find.byKey(ValueKey(lyon.id))).dx;

      await tester.dragFrom(Offset(block.right - 4, block.center.dy), const Offset(-200, 0));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.byKey(ValueKey(lyon.id))).dx, lessThan(before - 100));
      final saved = await reload(tester, data);
      expect(saved.item(lyon.id)!.end, lyon.end);
      expect(undoSteps(data), 0);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('dragging the end handle of the selected block resizes it', (tester) async {
      final data = await pump(tester, (d) => TimelineView(data: d));
      final lyon = data.items.firstWhere((i) => i.title == 'Lyon');
      container.read(tripUiProvider.notifier).select(lyon.id);
      await tester.pump();

      final g = await tester.startGesture(tester.getCenter(find.byKey(ValueKey('resizeEnd-${lyon.id}'))));
      await g.moveBy(const Offset(35, 0));
      await tester.pump();
      await g.moveBy(const Offset(35, 0)); // ~1 day at 64 px per day
      await tester.pump();
      await g.up();
      final saved = await reload(tester, data);

      expect(dayOf(saved.item(lyon.id)!.end!), dayOf(lyon.end!) + 1);
      expect(saved.item(lyon.id)!.start, lyon.start);
      expect(undoSteps(data), 1);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
