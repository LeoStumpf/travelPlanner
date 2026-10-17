import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/data/attachment_store.dart';
import 'package:travel_planner/data/db.dart';
import 'package:travel_planner/data/repository.dart';
import 'package:travel_planner/domain/demo.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/state/providers.dart';
import 'package:travel_planner/ui/agenda/agenda_view.dart';
import 'package:travel_planner/ui/common/item_sheet.dart';
import 'package:travel_planner/ui/editor/item_editor_page.dart';

import '../l10n_test_utils.dart';

void main() {
  // Same "now" as the agenda tests: trip day 3 of the Interrail demo, the
  // TGV Paris → Lyon (11:00–13:00) is the next transport.
  final now = DateTime(2026, 10, 17, 12);
  late Repository repo;
  late ProviderContainer container;
  late TripData demo;
  late List<String> clipboard;

  PlanItem tgvOf(TripData d) => d.items.firstWhere((i) => i.title.startsWith('TGV'));

  setUp(() {
    repo = Repository(AppDatabase(NativeDatabase.memory()), AttachmentStore(Directory.systemTemp));
    container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(repo),
      clockProvider.overrideWithValue(() => now),
    ]);
    final d = demoInterrail();
    demo = TripData(trip: d.trip.copyWith(startDate: DateTime(2026, 10, 14)), items: d.items, cards: d.cards);
    clipboard = [];
  });

  tearDown(() async {
    container.dispose();
    await repo.close();
  });

  TripData withDetails() {
    final tgv = tgvOf(demo).copyWith(
      departureStation: 'Paris Gare de Lyon',
      arrivalStation: 'Lyon Part-Dieu',
      transportNumber: 'TGV 6603',
      seat: 'Wagen 12, Platz 81',
      bookingRef: 'QX7K2P',
    );
    return TripData(trip: demo.trip, items: [for (final i in demo.items) i.id == tgv.id ? tgv : i], cards: demo.cards);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pumpAndSettle();
  }

  /// Puts [data] into the database and shows [body] for it.
  Future<void> pumpHost(WidgetTester tester, TripData data, Widget Function(BuildContext, WidgetRef, TripData) body) async {
    await tester.runAsync(() => repo.putTripData(data));
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard.add((call.arguments as Map)['text'] as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: testApp(
        home: Scaffold(
          body: Consumer(builder: (context, ref, _) {
            final d = ref.watch(tripDataProvider(data.trip.id)).value;
            return d == null ? const Text('loading') : body(context, ref, d);
          }),
        ),
      ),
    ));
    await settle(tester);
  }

  Future<void> openWith(WidgetTester tester, TripData data, void Function(BuildContext, WidgetRef, TripData) open) async {
    await pumpHost(
      tester,
      data,
      (context, ref, d) => TextButton(onPressed: () => open(context, ref, d), child: const Text('open')),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  group('editor', () {
    testWidgets('a transport edits all ticket details and saves them trimmed', (tester) async {
      await openWith(tester, demo, (c, ref, d) => openItemEditor(c, d, item: tgvOf(d)));
      expect(find.text(de.transportDetails), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('field-departure')), ' Paris Gare de Lyon ');
      await tester.enterText(find.byKey(const ValueKey('field-arrival')), 'Lyon Part-Dieu');
      await tester.enterText(find.byKey(const ValueKey('field-number')), 'TGV 6603');
      await tester.enterText(find.byKey(const ValueKey('field-seat')), 'Wagen 12, Platz 81');
      await tester.enterText(find.byKey(const ValueKey('field-booking-ref')), 'QX7K2P');
      await tester.tap(find.text(de.save));
      await settle(tester);

      final saved = (await tester.runAsync(() => repo.loadTrip(demo.trip.id)))!.item(tgvOf(demo).id)!;
      expect(saved.departureStation, 'Paris Gare de Lyon');
      expect(saved.arrivalStation, 'Lyon Part-Dieu');
      expect(saved.transportNumber, 'TGV 6603');
      expect(saved.seat, 'Wagen 12, Platz 81');
      expect(saved.bookingRef, 'QX7K2P');
    });

    testWidgets('clearing a field removes the detail; editing counts as unsaved change', (tester) async {
      await openWith(tester, withDetails(), (c, ref, d) => openItemEditor(c, d, item: tgvOf(d)));
      expect(find.text('QX7K2P'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('field-booking-ref')), '  ');
      // Leaving now asks first.
      await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pumpAndSettle();
      expect(find.text(de.unsavedChangesTitle), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, de.save));
      await settle(tester);

      final saved = (await tester.runAsync(() => repo.loadTrip(demo.trip.id)))!.item(tgvOf(demo).id)!;
      expect(saved.bookingRef, isNull);
      expect(saved.seat, 'Wagen 12, Platz 81');
    });

    testWidgets('other kinds have no ticket fields', (tester) async {
      await openWith(tester, demo, (c, ref, d) => openItemEditor(c, d, item: d.items.firstWhere((i) => i.title == 'Paris')));
      expect(find.text(de.transportDetails), findsNothing);
      expect(find.byKey(const ValueKey('field-booking-ref')), findsNothing);
    });
  });

  group('item sheet', () {
    testWidgets('shows the details prominently and copies the booking reference', (tester) async {
      final data = withDetails();
      await openWith(tester, data, (c, ref, d) => showItemSheet(c, ref, d.trip.id, tgvOf(d).id));
      final panel = find.byKey(ValueKey('transport-details-${tgvOf(data).id}'));
      expect(panel, findsOneWidget);
      for (final t in ['Paris Gare de Lyon', 'Lyon Part-Dieu', 'TGV 6603', 'Wagen 12, Platz 81', 'QX7K2P']) {
        expect(find.descendant(of: panel, matching: find.text(t)), findsOneWidget);
      }
      expect(find.descendant(of: panel, matching: find.text(de.bookingRefLabel)), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('copy-booking-ref')));
      await tester.pump();
      expect(clipboard, ['QX7K2P']);
      expect(find.byIcon(Icons.check), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('no panel without details', (tester) async {
      await openWith(tester, demo, (c, ref, d) => showItemSheet(c, ref, d.trip.id, tgvOf(d).id));
      expect(find.byKey(ValueKey('transport-details-${tgvOf(demo).id}')), findsNothing);
      expect(find.byKey(const ValueKey('copy-booking-ref')), findsNothing);
    });

    testWidgets('an open-ended transport names its station instead of "?"', (tester) async {
      final flight = demo.items.firstWhere((i) => i.kind == ItemKind.transport && i.toId == null);
      final data = TripData(
        trip: demo.trip,
        items: [for (final i in demo.items) i.id == flight.id ? i.copyWith(arrivalStation: 'Frankfurt FRA') : i],
      );
      await openWith(tester, data, (c, ref, d) => showItemSheet(c, ref, d.trip.id, flight.id));
      expect(find.textContaining('→ Frankfurt FRA'), findsOneWidget);
    });
  });

  group('agenda', () {
    testWidgets('the next transport shows its details; copying confirms with a snackbar', (tester) async {
      final data = withDetails();
      await pumpHost(tester, data, (c, ref, d) => AgendaView(data: d));
      final next = find.byKey(const ValueKey('agenda-next-transport'));
      expect(find.descendant(of: next, matching: find.text('TGV 6603')), findsOneWidget);
      expect(find.descendant(of: next, matching: find.text('Wagen 12, Platz 81')), findsOneWidget);
      expect(find.descendant(of: next, matching: find.text('QX7K2P')), findsOneWidget);

      await tester.tap(find.descendant(of: next, matching: find.byKey(const ValueKey('copy-booking-ref'))));
      await tester.pump();
      expect(clipboard, ['QX7K2P']);
      expect(find.text(de.bookingRefCopied), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('fits a 360 dp phone with long details', (tester) async {
      final tgv = tgvOf(demo).copyWith(
        departureStation: 'Paris Gare de Lyon Hall 1 & 2 (Grandes Lignes)',
        arrivalStation: 'Lyon Part-Dieu (Gare SNCF), Voie A–L',
        transportNumber: 'TGV INOUI 6603',
        seat: 'Wagen 12, Platz 81, Oberdeck, Fenster',
        bookingRef: 'QX7K2P-1234567890',
      );
      final data = TripData(trip: demo.trip, items: [for (final i in demo.items) i.id == tgv.id ? tgv : i]);
      await pumpHost(tester, data, (c, ref, d) => AgendaView(data: d));
      tester.view.physicalSize = const Size(360, 740);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
