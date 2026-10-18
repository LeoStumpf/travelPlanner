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
import 'package:travel_planner/ui/agenda/agenda_view.dart';
import 'package:travel_planner/ui/common/l10n.dart';
import 'package:travel_planner/ui/trip/trip_page.dart';

import '../l10n_test_utils.dart';

void main() {
  // "Now" is 17 Oct 2026, 12:00. With the start date 14 Oct, today is trip
  // day 3 of the Interrail demo: TGV Paris → Lyon (11:00–13:00) is under
  // way, Paris checks out, Lyon has only lodging options.
  final now = DateTime(2026, 10, 17, 12);
  late Repository repo;
  late ProviderContainer container;
  late TripData demo;
  late List<(String, String)> opened;
  var openWorks = true;

  setUp(() {
    repo = Repository(AppDatabase(NativeDatabase.memory()), AttachmentStore(Directory.systemTemp));
    opened = [];
    openWorks = true;
    container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(repo),
      clockProvider.overrideWithValue(() => now),
      fileOpenerProvider.overrideWithValue((path, mime) async {
        opened.add((path, mime));
        return openWorks;
      }),
    ]);
    final d = demoInterrail();
    demo = TripData(trip: d.trip.copyWith(startDate: DateTime(2026, 10, 14)), items: d.items, cards: d.cards, edges: d.edges);
  });

  tearDown(() async {
    container.dispose();
    await repo.close();
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pumpAndSettle();
  }

  PlanItem byTitle(String t) => demo.items.firstWhere((i) => i.title == t);
  Finder item(String title) => find.byKey(ValueKey('agenda-item-${byTitle(title).id}'));

  Future<void> pumpAgenda(WidgetTester tester, {Size size = const Size(800, 1400)}) async {
    await tester.runAsync(() => repo.putTripData(demo));
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: testApp(
        home: Scaffold(
          body: Consumer(builder: (context, ref, _) {
            final data = ref.watch(tripDataProvider(demo.trip.id)).value;
            return data == null ? const Text('loading') : AgendaView(data: data);
          }),
        ),
      ),
    ));
    await settle(tester);
  }

  group('agenda of today', () {
    testWidgets('opens on today with stays, lodging, next transport and programme', (tester) async {
      await pumpAgenda(tester);
      expect(find.text(de.agendaToday), findsWidgets); // chip and header
      expect(find.byKey(const ValueKey('agenda-jump-today')), findsNothing);
      expect(item('Paris'), findsOneWidget);
      expect(item('Lyon'), findsOneWidget);
      expect(item('Hôtel du Marais'), findsOneWidget);
      expect(find.text(de.agendaCheckOut('11:00')), findsOneWidget);
      expect(find.byKey(const ValueKey('agenda-no-bed')), findsOneWidget);
      expect(find.text(de.agendaOptionsCount(2)), findsOneWidget);
      final next = find.byKey(const ValueKey('agenda-next-transport'));
      expect(next, findsOneWidget);
      expect(find.descendant(of: next, matching: find.text('TGV Paris → Lyon')), findsOneWidget);
      expect(find.descendant(of: next, matching: find.text(de.agendaDeparts('11:00'))), findsOneWidget);
      expect(find.text(de.agendaProgramme), findsOneWidget);
    });

    testWidgets('another day is selectable and "Springe zu heute" comes back', (tester) async {
      await pumpAgenda(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, de.agendaTomorrow));
      await settle(tester);
      // Day 4: Lyon without a bed; the next transport is days away.
      expect(find.text(de.agendaTomorrow), findsNWidgets(2));
      expect(item('Paris'), findsNothing);
      expect(item('Lyon'), findsOneWidget);
      final next = find.byKey(const ValueKey('agenda-next-transport'));
      expect(find.descendant(of: next, matching: find.text('Euromed Barcelona → Valencia')), findsOneWidget);

      final jump = find.byKey(const ValueKey('agenda-jump-today'));
      expect(jump, findsOneWidget);
      expect(find.text(de.agendaJumpToToday), findsOneWidget);
      await tester.tap(jump);
      await settle(tester);
      expect(jump, findsNothing);
      expect(item('Paris'), findsOneWidget);
    });

    testWidgets('a free day says nothing is planned', (tester) async {
      await pumpAgenda(tester);
      final chip = find.widgetWithText(ChoiceChip, de.day(demo.trip.startDate, 6));
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await settle(tester);
      expect(find.text(de.agendaNothingPlanned), findsOneWidget);
    });

    testWidgets('a ticket opens with one tap', (tester) async {
      final tgv = byTitle('TGV Paris → Lyon');
      final ticket = Attachment(
        id: 'tgv-ticket',
        tripId: demo.trip.id,
        ownerIds: [tgv.id],
        fileName: 'tgv.pdf',
        relPath: '${demo.trip.id}/tgv.pdf',
        mime: 'application/pdf',
        createdAt: DateTime(2026, 10, 1),
      );
      demo = TripData(trip: demo.trip, items: demo.items, cards: demo.cards, attachments: [ticket]);
      await pumpAgenda(tester);
      final chip = find.descendant(
          of: find.byKey(const ValueKey('agenda-next-transport')), matching: find.byKey(const ValueKey('ticket-tgv-ticket')));
      expect(chip, findsOneWidget);
      await tester.tap(chip);
      await tester.pump();
      expect(opened, hasLength(1));
      expect(opened.single.$1, endsWith('tgv.pdf'));
      expect(opened.single.$2, 'application/pdf');
      expect(find.text(de.agendaOpenFailed('tgv.pdf')), findsNothing);

      // No app for the file (or the file is gone): say so instead of nothing.
      openWorks = false;
      await tester.tap(chip);
      await tester.pump();
      await tester.pump();
      expect(opened, hasLength(2));
      expect(find.text(de.agendaOpenFailed('tgv.pdf')), findsOneWidget);
    });

    testWidgets('tapping an item opens its sheet', (tester) async {
      await pumpAgenda(tester);
      await tester.tap(item('Hôtel du Marais'));
      await settle(tester);
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      expect(container.read(tripUiProvider).selectedId, byTitle('Hôtel du Marais').id);
    });

    testWidgets('without a start date it shows trip days and a hint', (tester) async {
      demo = demoInterrail();
      await pumpAgenda(tester);
      expect(find.text(de.agendaNoStartDate), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, de.dayNumber(1)), findsOneWidget);
      expect(find.byKey(const ValueKey('agenda-jump-today')), findsNothing);
      expect(item('Paris'), findsOneWidget);
    });

    testWidgets('before the trip it says when it starts', (tester) async {
      demo = TripData(trip: demo.trip.copyWith(startDate: DateTime(2026, 10, 20)), items: demo.items);
      await pumpAgenda(tester);
      expect(find.text(de.agendaStartsIn(3)), findsOneWidget);
      expect(find.byKey(const ValueKey('agenda-jump-today')), findsNothing);
    });
  });

  group('default view', () {
    Future<void> pumpTrip(WidgetTester tester) async {
      await tester.runAsync(() => repo.putTripData(demo));
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      container.read(tripUiProvider.notifier).reset(); // as openTrip does
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: testApp(home: TripPage(tripId: demo.trip.id)),
      ));
      await settle(tester);
    }

    testWidgets('a running trip opens on the agenda', (tester) async {
      await pumpTrip(tester);
      expect(container.read(tripUiProvider).view, TripView.agenda);
      expect(container.read(tripUiProvider).pickView, isFalse);
      expect(find.byType(AgendaView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a trip not running keeps the last view, but not the agenda', (tester) async {
      demo = TripData(trip: demo.trip.copyWith(startDate: DateTime(2027, 5, 1)), items: demo.items);
      container.read(tripUiProvider.notifier).setView(TripView.agenda);
      await pumpTrip(tester);
      expect(container.read(tripUiProvider).view, TripView.timeline);
    });

    testWidgets('an explicit view after opening wins (shared content → notes)', (tester) async {
      container.read(tripUiProvider.notifier).reset();
      container.read(tripUiProvider.notifier).setView(TripView.notes);
      await tester.runAsync(() => repo.putTripData(demo));
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: testApp(home: TripPage(tripId: demo.trip.id)),
      ));
      await settle(tester);
      expect(container.read(tripUiProvider).view, TripView.notes);
    });

    testWidgets('the agenda is the fifth tab', (tester) async {
      demo = TripData(trip: demo.trip.copyWith(startDate: null), items: demo.items);
      await pumpTrip(tester);
      expect(container.read(tripUiProvider).view, TripView.timeline);
      await tester.tap(find.text(de.viewAgenda));
      await settle(tester);
      expect(container.read(tripUiProvider).view, TripView.agenda);
      expect(find.byType(AgendaView), findsOneWidget);
    });
  });

  testWidgets('today fits a 360 dp phone', (tester) async {
    await pumpAgenda(tester, size: const Size(360, 740));
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(ChoiceChip, de.agendaTomorrow));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}
