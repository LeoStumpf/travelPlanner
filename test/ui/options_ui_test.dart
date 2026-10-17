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

  Future<TripData> load() async => (await repo.loadTrip(demo.trip.id))!;
  PlanItem byTitle(TripData d, String t) => d.items.firstWhere((i) => i.title == t);
  List<String> undoLabels() => [for (final e in container.read(undoProvider)[demo.trip.id] ?? const []) e.label];

  /// Hosts [body] (built from the live trip data) on a big screen.
  Future<void> pumpHost(WidgetTester tester, Widget Function(BuildContext, WidgetRef, TripData) body) async {
    await tester.runAsync(() => repo.putTripData(demo));
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
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

  group('item sheet of an accommodation option', () {
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

    testWidgets('"Diese Option wählen" makes it planned', (tester) async {
      await openSheet(tester, 'Airbnb Croix-Rousse');
      expect(find.text('Als gebucht markieren'), findsOneWidget);
      await tester.tap(find.text('Diese Option wählen'));
      await settle(tester);

      final after = await load();
      expect(byTitle(after, 'Airbnb Croix-Rousse').status, ItemStatus.planned);
      expect(byTitle(after, 'Auberge Vieux Lyon').status, ItemStatus.option);
      expect(undoLabels(), ['„Airbnb Croix-Rousse“ gewählt']);
      // Now planned: only booking is left to offer.
      expect(find.text('Diese Option wählen'), findsNothing);
      expect(find.text('Als gebucht markieren'), findsOneWidget);
    });

    testWidgets('"Als gebucht markieren" books it and demotes the planned rival', (tester) async {
      await tester.runAsync(() async {
        demo = TripData(trip: demo.trip, items: [
          for (final i in demo.items)
            i.title == 'Auberge Vieux Lyon' ? i.copyWith(status: ItemStatus.planned) : i,
        ]);
      });
      await openSheet(tester, 'Airbnb Croix-Rousse');
      await tester.tap(find.text('Als gebucht markieren'));
      await settle(tester);

      final after = await load();
      expect(byTitle(after, 'Airbnb Croix-Rousse').status, ItemStatus.booked);
      expect(byTitle(after, 'Auberge Vieux Lyon').status, ItemStatus.option);
      expect(find.text('Als gebucht markieren'), findsNothing);

      // One undo step reverts both.
      expect(undoLabels(), ['„Airbnb Croix-Rousse“ als gebucht markiert']);
      await tester.runAsync(() => container.read(planActionsProvider).undo(demo.trip.id));
      final undone = await load();
      expect(byTitle(undone, 'Airbnb Croix-Rousse').status, ItemStatus.option);
      expect(byTitle(undone, 'Auberge Vieux Lyon').status, ItemStatus.planned);
    });

    testWidgets('stays and booked accommodations get no choose actions', (tester) async {
      await openSheet(tester, 'Hôtel du Marais');
      expect(find.text('Diese Option wählen'), findsNothing);
      expect(find.text('Als gebucht markieren'), findsNothing);
    });
  });

  group('missing-night marker', () {
    Future<void> pumpTimeline(WidgetTester tester) =>
        pumpHost(tester, (context, ref, data) => TimelineView(data: data));

    testWidgets('shows the option count and offers the options first', (tester) async {
      await pumpTimeline(tester);
      // Lyon's two nights each have two options; Valencia has none.
      expect(find.text(' 2?'), findsNWidgets(2));
      expect(find.text('!'), findsNWidgets(2));

      await tester.tap(find.text(' 2?').first);
      await settle(tester);
      expect(find.text('Option wählen'), findsOneWidget);
      expect(find.text('Neue Unterkunft'), findsOneWidget);
      expect(find.text('Wählen'), findsNWidgets(2));

      await tester.tap(find.text('Wählen').first);
      await settle(tester);
      final after = await load();
      final chosen = [
        for (final t in ['Airbnb Croix-Rousse', 'Auberge Vieux Lyon']) byTitle(after, t).status,
      ];
      expect(chosen.where((s) => s == ItemStatus.planned), hasLength(1));
      expect(chosen.where((s) => s == ItemStatus.option), hasLength(1));
      expect(find.text('Rückgängig'), findsOneWidget);
      // Lyon is covered now; only Valencia's markers are left.
      expect(find.text(' 2?'), findsNothing);
      expect(find.text('!'), findsNWidgets(2));
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('"Neue Unterkunft" opens the editor', (tester) async {
      await pumpTimeline(tester);
      await tester.tap(find.text(' 2?').first);
      await settle(tester);
      await tester.tap(find.text('Neue Unterkunft'));
      await settle(tester);
      expect(find.byType(ItemEditorPage), findsOneWidget);
    });

    testWidgets('without options it opens the editor directly', (tester) async {
      await pumpTimeline(tester);
      await tester.tap(find.text('!').first);
      await settle(tester);
      expect(find.text('Option wählen'), findsNothing);
      expect(find.byType(ItemEditorPage), findsOneWidget);
    });
  });
}
