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
import 'package:travel_planner/ui/editor/item_editor_page.dart';
import 'package:travel_planner/ui/trip/trip_page.dart';
import 'package:travel_planner/ui/trips/trips_page.dart';

import '../l10n_test_utils.dart';

final _t0 = DateTime(2026, 1, 1);

PlanItem _item(String id, ItemKind kind, int start, int end,
        {ItemStatus status = ItemStatus.planned, String? parent, String? from, String? to}) =>
    PlanItem(
      id: id,
      tripId: 'fr',
      kind: kind,
      title: id,
      status: status,
      parentId: parent,
      fromId: from,
      toId: to,
      start: start,
      end: end,
      createdAt: _t0,
    );

/// Paris → TGV → Lyon with a food tour during the train ride (fixable) and
/// two booked hotels in the same night in Paris (no automatic fix).
final _france = TripData(
  trip: Trip(id: 'fr', title: 'Frankreich', createdAt: _t0),
  items: [
    _item('Paris', ItemKind.stay, at(0, defaultStayArrival), at(2, 9 * 60)),
    _item('Lyon', ItemKind.stay, at(2, 10 * 60), at(4, defaultStayDeparture)),
    _item('TGV', ItemKind.transport, at(2, 9 * 60), at(2, 11 * 60), from: 'Paris', to: 'Lyon'),
    _item('Food-Tour', ItemKind.activity, at(2, 10 * 60), at(2, 12 * 60), parent: 'Lyon'),
    _item('Ibis', ItemKind.accommodation, at(0, defaultCheckIn), at(2, defaultCheckOut),
        status: ItemStatus.booked, parent: 'Paris'),
    _item('Hilton', ItemKind.accommodation, at(1, defaultCheckIn), at(2, defaultCheckOut),
        status: ItemStatus.booked, parent: 'Paris'),
  ],
);

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

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    await settle(tester);
  }

  Future<void> pump(WidgetTester tester, TripData data, Widget home) async {
    await tester.runAsync(() => repo.putTripData(data));
    container.read(tripUiProvider.notifier).reset();
    container.read(tripUiProvider.notifier).setView(TripView.notes);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: testApp(home: home)));
    await settle(tester);
  }

  Finder badge() => find.byKey(const ValueKey('conflict-badge'));

  group('trip app bar', () {
    testWidgets('shows the number of conflicts and lists them', (tester) async {
      await pump(tester, _france, const TripPage(tripId: 'fr'));
      expect(find.descendant(of: badge(), matching: find.text('2')), findsOneWidget);

      await tap(tester, badge());
      expect(find.text('„Food-Tour“ liegt in der Fahrzeit von „TGV“'), findsOneWidget);
      expect(find.text('„Hilton“ und „Ibis“ sind beide für 1 Nacht fest eingeplant'), findsOneWidget);
      // With a fix: the button. Without: the reason.
      expect(find.text('Nach „TGV“ legen'), findsOneWidget);
      expect(find.text('Keine automatische Lösung: Beide sind gebucht. Eines stornieren oder verschieben.'),
          findsOneWidget);
      // Both items of each conflict can be reached.
      for (final id in ['Food-Tour', 'TGV', 'Hilton', 'Ibis']) {
        expect(find.byKey(ValueKey('conflict-open-$id')), findsOneWidget, reason: id);
      }
    });

    testWidgets('a chip opens the other item of the conflict', (tester) async {
      await pump(tester, _france, const TripPage(tripId: 'fr'));
      await tap(tester, badge());
      await tap(tester, find.byKey(const ValueKey('conflict-open-Ibis')));
      expect(container.read(tripUiProvider).selectedId, 'Ibis');
      // The item sheet of Ibis lists its conflict, offering the Hilton only.
      expect(find.byKey(const ValueKey('conflict-open-Hilton')), findsOneWidget);
      expect(find.byKey(const ValueKey('conflict-open-Ibis')), findsNothing);
    });

    testWidgets('the fix in the list resolves the conflict and the badge counts down', (tester) async {
      await pump(tester, _france, const TripPage(tripId: 'fr'));
      await tap(tester, badge());
      await tap(tester, find.text('Nach „TGV“ legen'));
      final after = (await tester.runAsync(() => repo.loadTrip('fr')))!;
      expect(after.item('Food-Tour')!.start, at(2, 11 * 60));
      expect(find.descendant(of: badge(), matching: find.text('1')), findsOneWidget);
    });

    testWidgets('no badge without conflicts', (tester) async {
      final demo = demoInterrail();
      await pump(tester, demo, TripPage(tripId: demo.trip.id));
      expect(badge(), findsNothing);
    });
  });

  testWidgets('360 dp: long titles fit the app bar, the conflict list and the trip card', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const long = 'Sehr lange Bezeichnung für ein Hotel mitten in der Altstadt von Paris';
    final data = TripData(
      trip: Trip(id: 'fr', title: 'Frankreich-Rundreise mit dem Zug im Frühling 2026', createdAt: _t0),
      items: [
        for (final i in _france.items)
          i.id == 'Hilton' || i.id == 'Food-Tour' ? i.copyWith(title: '$long (${i.id})') : i,
      ],
    );
    await pump(tester, data, const TripPage(tripId: 'fr'));
    expect(tester.takeException(), isNull);
    await tap(tester, badge());
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('conflict-no-fix')), findsOneWidget);

    await pump(tester, data, const TripsPage());
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('trip-conflicts')), findsOneWidget);
  });

  testWidgets('the trip card in the list warns about conflicts', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.runAsync(() => repo.putTripData(demoInterrail()));
    await pump(tester, _france, const TripsPage());
    final pill = find.byKey(const ValueKey('trip-conflicts'));
    expect(pill, findsOneWidget, reason: 'only the trip with conflicts');
    expect(find.descendant(of: pill, matching: find.text('2')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('2 Konflikte')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('setting an option to planned in the editor demotes the planned sibling', (tester) async {
    final base = demoInterrail();
    final airbnb = base.items.firstWhere((i) => i.title == 'Airbnb Croix-Rousse');
    final auberge = base.items.firstWhere((i) => i.title == 'Auberge Vieux Lyon').copyWith(status: ItemStatus.planned);
    final demo = TripData(trip: base.trip, items: [for (final i in base.items) i.id == auberge.id ? auberge : i]);
    expect((airbnb.status, auberge.status), (ItemStatus.option, ItemStatus.planned));
    await tester.runAsync(() => repo.putTripData(demo));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: testApp(
        home: Scaffold(
          body: Consumer(builder: (context, ref, _) {
            final data = ref.watch(tripDataProvider(demo.trip.id)).value;
            return data == null
                ? const Text('loading')
                : TextButton(
                    onPressed: () => openItemEditor(context, data, item: data.item(airbnb.id)),
                    child: const Text('open'),
                  );
          }),
        ),
      ),
    ));
    await settle(tester);
    await tap(tester, find.text('open'));
    await tap(tester, find.text('Geplant'));
    await tap(tester, find.widgetWithText(TextButton, 'Speichern'));

    final after = (await tester.runAsync(() => repo.loadTrip(demo.trip.id)))!;
    expect(after.item(airbnb.id)!.status, ItemStatus.planned);
    expect(after.item(auberge.id)!.status, ItemStatus.option);
    expect(find.text('1 andere Unterkunft ist jetzt Option'), findsOneWidget);
    // One undo step brings both back.
    await tester.runAsync(() => container.read(planActionsProvider).undo(demo.trip.id));
    final undone = (await tester.runAsync(() => repo.loadTrip(demo.trip.id)))!;
    expect(undone.item(auberge.id)!.status, ItemStatus.planned);
    expect(undone.item(airbnb.id)!.status, ItemStatus.option);
  });
}
