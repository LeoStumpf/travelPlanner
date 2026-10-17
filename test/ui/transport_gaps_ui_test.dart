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
import 'package:travel_planner/state/providers.dart';
import 'package:travel_planner/ui/common/item_sheet.dart';
import 'package:travel_planner/ui/editor/item_editor_page.dart';
import 'package:travel_planner/ui/timeline/timeline_view.dart';

import '../l10n_test_utils.dart';

void main() {
  late Repository repo;
  late ProviderContainer container;
  late TripData demo;

  setUp(() {
    repo = Repository(AppDatabase(NativeDatabase.memory()), AttachmentStore(Directory.systemTemp));
    container = ProviderContainer(overrides: [repositoryProvider.overrideWithValue(repo)]);
    demo = demoInterrail();
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

  Future<void> pumpHost(WidgetTester tester, Widget Function(BuildContext, WidgetRef, TripData) body) async {
    await tester.runAsync(() => repo.putTripData(demo));
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: testApp(
        home: Scaffold(
          body: Consumer(builder: (context, ref, _) {
            final data = ref.watch(tripDataProvider(demo.trip.id)).value;
            return data == null ? const Text('loading') : body(context, ref, data);
          }),
        ),
      ),
    ));
    await settle(tester);
  }

  /// The editor page's initial item (the prefilled new transport).
  PlanItem editorItem(WidgetTester tester) =>
      tester.widget<ItemEditorPage>(find.byType(ItemEditorPage)).initial;

  group('"+ Transport" marker on the timeline', () {
    testWidgets('marks only the leg without a transport', (tester) async {
      await pumpHost(tester, (context, ref, data) => TimelineView(data: data));
      // Paris → Lyon and Barcelona → Valencia have trains; Lyon → Barcelona not.
      final lyon = byTitle(demo, 'Lyon'), bcn = byTitle(demo, 'Barcelona');
      expect(find.byKey(ValueKey('transport-gap-${lyon.id}-${bcn.id}')), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('transport-gap-')), findsOneWidget);
    });

    testWidgets('opens the editor prefilled with both stays', (tester) async {
      await pumpHost(tester, (context, ref, data) => TimelineView(data: data));
      final lyon = byTitle(demo, 'Lyon'), bcn = byTitle(demo, 'Barcelona');
      final marker = find.byKey(ValueKey('transport-gap-${lyon.id}-${bcn.id}'));
      await tester.ensureVisible(marker);
      await tester.pumpAndSettle();
      await tester.tap(marker);
      await settle(tester);

      expect(find.text('Neu: Transport'), findsOneWidget);
      final t = editorItem(tester);
      expect(t.kind, ItemKind.transport);
      expect((t.fromId, t.toId), (lyon.id, bcn.id));
      expect(t.title, 'Lyon → Barcelona');
      expect(t.start, lyon.end);
      expect(t.end, lyon.end! + 3 * 60);
    });

    testWidgets('disappears once a transport connects the stays', (tester) async {
      final lyon = byTitle(demo, 'Lyon'), bcn = byTitle(demo, 'Barcelona');
      demo = TripData(
        trip: demo.trip,
        items: [
          ...demo.items,
          PlanItem(
            id: 'new-train',
            tripId: demo.trip.id,
            kind: ItemKind.transport,
            title: 'Zug',
            fromId: lyon.id,
            toId: bcn.id,
            createdAt: DateTime(2026),
          ),
        ],
        cards: demo.cards,
        edges: demo.edges,
      );
      await pumpHost(tester, (context, ref, data) => TimelineView(data: data));
      expect(find.byKey(ValueKey('transport-gap-${lyon.id}-${bcn.id}')), findsNothing);
    });
  });

  group('stay sheet transport actions', () {
    Future<void> openSheet(WidgetTester tester, String title) async {
      await pumpHost(
        tester,
        (context, ref, data) => TextButton(
          onPressed: () => showItemSheet(context, ref, demo.trip.id, byTitle(data, title).id),
          child: const Text('open'),
        ),
      );
      await tester.tap(find.text('open'));
      await settle(tester);
    }

    Future<void> tapAction(WidgetTester tester, String key) async {
      final f = find.byKey(ValueKey(key));
      await tester.scrollUntilVisible(f, 150,
          scrollable: find.descendant(of: find.byType(DraggableScrollableSheet), matching: find.byType(Scrollable)).first);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await settle(tester);
    }

    testWidgets('"Transport hierher" comes from the previous stay', (tester) async {
      await openSheet(tester, 'Barcelona');
      await tapAction(tester, 'transport-here');

      final lyon = byTitle(demo, 'Lyon'), bcn = byTitle(demo, 'Barcelona');
      final t = editorItem(tester);
      expect((t.fromId, t.toId), (lyon.id, bcn.id));
      expect(t.start, lyon.end);
    });

    testWidgets('"Transport weiter" goes to the next stay', (tester) async {
      await openSheet(tester, 'Paris');
      await tapAction(tester, 'transport-onward');

      final paris = byTitle(demo, 'Paris'), lyon = byTitle(demo, 'Lyon');
      final t = editorItem(tester);
      expect((t.fromId, t.toId), (paris.id, lyon.id));
      expect(t.title, 'Paris → Lyon');
    });

    testWidgets('the first stay arrives from nowhere, timed by its start', (tester) async {
      await openSheet(tester, 'Paris');
      await tapAction(tester, 'transport-here');

      final paris = byTitle(demo, 'Paris');
      final t = editorItem(tester);
      expect((t.fromId, t.toId), (null, paris.id));
      expect(t.title, 'Nach Paris');
      expect(t.end, paris.start);
    });

    testWidgets('saving the prefilled transport closes the gap', (tester) async {
      await openSheet(tester, 'Lyon');
      await tapAction(tester, 'transport-onward');
      await tester.tap(find.text('Speichern'));
      await settle(tester);

      final after = (await tester.runAsync(() => repo.loadTrip(demo.trip.id)))!;
      final lyon = byTitle(after, 'Lyon'), bcn = byTitle(after, 'Barcelona');
      expect(after.items.where((i) => i.fromId == lyon.id && i.toId == bcn.id), hasLength(1));
    });
  });
}
