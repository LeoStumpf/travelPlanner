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
import 'package:travel_planner/ui/common/item_sheet.dart';
import 'package:travel_planner/ui/editor/item_editor_page.dart';
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

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pumpAndSettle();
  }

  PlanItem byTitle(TripData d, String t) => d.items.firstWhere((i) => i.title == t);

  /// Hosts [body] (built from the live data of [trip]) on a big screen.
  Future<void> pumpHost(
    WidgetTester tester,
    TripData trip,
    Widget Function(BuildContext, WidgetRef, TripData) body, {
    double textScale = 1,
  }) async {
    await tester.runAsync(() => repo.putTripData(trip));
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: testApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: Consumer(builder: (context, ref, _) {
                final data = ref.watch(tripDataProvider(trip.trip.id)).value;
                return data == null ? const Text('loading') : body(context, ref, data);
              }),
            ),
          ),
        ),
      ),
    ));
    await settle(tester);
  }

  Future<void> pumpTimeline(WidgetTester tester, TripData trip, {double textScale = 1}) =>
      pumpHost(tester, trip, (_, _, data) => TimelineView(data: data), textScale: textScale);

  TripData emptyTrip({List<PlanItem> Function(String tripId)? items}) {
    final trip = Trip(id: 'empty', title: 'Leer', createdAt: DateTime(2026));
    return TripData(trip: trip, items: items?.call(trip.id) ?? const []);
  }

  group('empty state', () {
    testWidgets('a trip without anything offers to add the first place', (tester) async {
      await pumpTimeline(tester, emptyTrip());
      expect(find.text('Noch keine Orte'), findsOneWidget);
      expect(find.textContaining('Beginne mit dem ersten Ort'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('timeline-add-first-stay')));
      await tester.pumpAndSettle();
      expect(find.byType(ItemEditorPage), findsOneWidget);
      final editor = tester.widget<ItemEditorPage>(find.byType(ItemEditorPage));
      expect(editor.initial.kind, ItemKind.stay);
      expect(dayOf(editor.initial.start!), 0);
    });

    testWidgets('scheduled items without a place keep the timeline and show a banner', (tester) async {
      final trip = emptyTrip(
        items: (id) => [
          PlanItem(
            id: 'museum',
            tripId: id,
            kind: ItemKind.activity,
            title: 'Museum',
            start: at(0, 600),
            end: at(0, 720),
            createdAt: DateTime(2026),
          ),
        ],
      );
      await pumpTimeline(tester, trip);
      expect(find.text('Noch keine Orte'), findsOneWidget);
      expect(find.byKey(const ValueKey('timeline-add-first-stay')), findsOneWidget);
      expect(find.textContaining('Beginne mit dem ersten Ort'), findsNothing);
      expect(find.byKey(const ValueKey('museum')), findsOneWidget);
    });

    testWidgets('a trip with places shows no empty state', (tester) async {
      await pumpTimeline(tester, demoInterrail());
      expect(find.text('Noch keine Orte'), findsNothing);
    });
  });

  group('readable blocks', () {
    testWidgets('the nights label sits on its place\'s line', (tester) async {
      final demo = demoInterrail();
      await pumpTimeline(tester, demo);
      final paris = byTitle(demo, 'Paris');
      final badge = find.byKey(ValueKey('nights-${paris.id}'));
      expect(badge, findsOneWidget);
      expect(find.descendant(of: badge, matching: find.text('3N')), findsOneWidget);
      final block = tester.getRect(find.byKey(ValueKey(paris.id)));
      final r = tester.getRect(badge);
      expect(block.contains(r.topLeft) && block.contains(r.bottomRight), isTrue);
      // Below the name, not floating next to it.
      expect(r.top, greaterThan(tester.getRect(find.text('Paris')).bottom - 1));
    });

    testWidgets('titles are cut with an ellipsis, not clipped', (tester) async {
      await pumpTimeline(tester, demoInterrail());
      final paris = tester.widget<Text>(find.text('Paris'));
      expect(paris.overflow, TextOverflow.ellipsis);
      final hotel = tester.widget<Text>(find.text('Hôtel du Marais'));
      expect(hotel.overflow, TextOverflow.ellipsis);
    });

    testWidgets('a narrow activity shows its title next to the block', (tester) async {
      final demo = demoInterrail();
      await pumpTimeline(tester, demo);
      final louvre = byTitle(demo, 'Louvre');
      final label = find.byKey(ValueKey('label-${louvre.id}'));
      expect(label, findsOneWidget);
      expect(find.descendant(of: label, matching: find.text('Louvre')), findsOneWidget);
      final block = tester.getRect(find.byKey(ValueKey(louvre.id)));
      expect(tester.getRect(label).left, greaterThanOrEqualTo(block.right));
      // Tapping the label opens the item like the block does.
      await tester.tap(find.text('Louvre'));
      await settle(tester);
      expect(container.read(tripUiProvider).selectedId, louvre.id);
    });

    testWidgets('zoomed in, the title moves into the block', (tester) async {
      final demo = demoInterrail();
      await pumpTimeline(tester, demo);
      for (var k = 0; k < 8; k++) {
        await tester.tap(find.byIcon(Icons.zoom_in));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      final louvre = byTitle(demo, 'Louvre');
      expect(find.byKey(ValueKey('label-${louvre.id}')), findsNothing);
      expect(
        find.descendant(of: find.byKey(ValueKey(louvre.id)), matching: find.text('Louvre')),
        findsOneWidget,
      );
    });

    testWidgets('rows grow with the system text size', (tester) async {
      final demo = demoInterrail();
      final paris = byTitle(demo, 'Paris');
      await pumpTimeline(tester, demo);
      final normal = tester.getSize(find.byKey(ValueKey(paris.id))).height;
      await pumpTimeline(tester, demo, textScale: 1.5);
      final large = tester.getSize(find.byKey(ValueKey(paris.id))).height;
      expect(large, greaterThan(normal * 1.4));
      expect(tester.takeException(), isNull);
    });
  });

  group('"Einplanen am …"', () {
    testWidgets('the tray schedules an idea on the suggested day, undoable', (tester) async {
      final demo = demoInterrail();
      final avignon = byTitle(demo, 'Avignon');
      await pumpTimeline(tester, demo);
      await tester.tap(find.byKey(ValueKey('tray-${avignon.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Einplanen am Tag 7'), findsOneWidget);
      expect(find.textContaining('Ankunft 14:00'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('schedule-suggested')));
      await settle(tester);

      final after = (await tester.runAsync(() => repo.loadTrip(demo.trip.id)))!;
      final placed = after.item(avignon.id)!;
      expect(placed.start, at(6, defaultStayArrival));
      expect(placed.end, at(8, defaultStayDeparture));
      expect(byTitle(after, 'Barcelona').start, byTitle(demo, 'Barcelona').start);
      expect(find.text('„Avignon“ eingeplant am Tag 7'), findsOneWidget);
      expect(find.text('Ohne Termin:'), findsNothing);

      await tester.tap(find.text('Rückgängig'));
      await settle(tester);
      final undone = (await tester.runAsync(() => repo.loadTrip(demo.trip.id)))!;
      expect(undone.item(avignon.id)!.isScheduled, isFalse);
      expect(find.text('Ohne Termin:'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('any other trip day can be picked; details are one tap away', (tester) async {
      final demo = demoInterrail();
      final avignon = byTitle(demo, 'Avignon');
      await pumpTimeline(tester, demo);
      await tester.tap(find.byKey(ValueKey('tray-${avignon.id}')));
      await tester.pumpAndSettle();
      // Day range of the trip plus one day after it.
      expect(find.byKey(const ValueKey('schedule-day-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('schedule-day-14')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('schedule-details')));
      await settle(tester);
      expect(find.text('Noch nicht eingeplant'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('quick-schedule')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('schedule-details')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('schedule-day-13')));
      await settle(tester);
      final after = (await tester.runAsync(() => repo.loadTrip(demo.trip.id)))!;
      expect(dayOf(after.item(avignon.id)!.start!), 13);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('the item sheet of a scheduled item has no "Einplanen am …"', (tester) async {
      final demo = demoInterrail();
      await pumpHost(
        tester,
        demo,
        (context, ref, data) => TextButton(
          onPressed: () => showItemSheet(context, ref, demo.trip.id, byTitle(data, 'Louvre').id),
          child: const Text('open'),
        ),
      );
      await tester.tap(find.text('open'));
      await settle(tester);
      expect(find.byKey(const ValueKey('quick-schedule')), findsNothing);
    });
  });
}
