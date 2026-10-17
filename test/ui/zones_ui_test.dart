import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/data/attachment_store.dart';
import 'package:travel_planner/data/db.dart';
import 'package:travel_planner/data/repository.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/domain/time.dart';
import 'package:travel_planner/state/providers.dart';
import 'package:travel_planner/ui/agenda/agenda_view.dart';
import 'package:travel_planner/ui/common/item_sheet.dart';
import 'package:travel_planner/ui/common/l10n.dart';
import 'package:travel_planner/ui/common/zone_picker.dart';
import 'package:travel_planner/ui/editor/item_editor_page.dart';
import 'package:travel_planner/ui/trips/trip_settings_dialog.dart';

import '../l10n_test_utils.dart';

const berlin = 'Europe/Berlin';
const colombo = 'Asia/Colombo';

final _t0 = DateTime(2026, 1, 1);

PlanItem _stay(String id, String title, int start, int end, {String? tz}) => PlanItem(
    id: id, tripId: 'zt', kind: ItemKind.stay, title: title, start: start, end: end, tz: tz, createdAt: _t0);

/// Frankfurt → LH 754 (21:30 Berlin → 10:30 Colombo, 8 h 30 min) → Colombo.
TripData fraToCmb({String? homeZone = berlin, bool zoned = true}) => TripData(
      trip: Trip(id: 'zt', title: 'Sri Lanka', startDate: DateTime(2027, 3, 1), homeZone: homeZone, createdAt: _t0),
      items: [
        _stay('fra', 'Frankfurt', at(0, 14 * 60), at(1, 19 * 60), tz: zoned ? berlin : null),
        PlanItem(
          id: 'lh',
          tripId: 'zt',
          kind: ItemKind.transport,
          mode: TransportMode.plane,
          title: 'LH 754',
          fromId: 'fra',
          toId: 'cmb',
          start: at(1, 21 * 60 + 30),
          end: at(2, 10 * 60 + 30),
          createdAt: _t0,
        ),
        _stay('cmb', 'Colombo', at(2, 10 * 60 + 30), at(5, 10 * 60), tz: zoned ? colombo : null),
      ],
    );

void main() {
  late Repository repo;
  late ProviderContainer container;

  setUp(() {
    repo = Repository(AppDatabase(NativeDatabase.memory()), AttachmentStore(Directory.systemTemp));
    container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(repo),
      // Trip day 1, 12:00: the flight tonight is the next transport.
      clockProvider.overrideWithValue(() => DateTime(2027, 3, 2, 12)),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await repo.close();
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pumpAndSettle();
  }

  Future<void> pumpHost(WidgetTester tester, TripData data, Widget Function(BuildContext, WidgetRef, TripData) body) async {
    await tester.runAsync(() => repo.putTripData(data));
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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

  group('zone picker', () {
    testWidgets('search by city or offset; "none" returns null', (tester) async {
      ZoneChoice? result;
      await pumpHost(
        tester,
        fraToCmb(),
        (c, ref, d) => TextButton(
          onPressed: () async =>
              result = await pickTimeZone(c, current: colombo, noneLabel: de.zoneNone, suggestions: [berlin]),
          child: const Text('open'),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(de.zonesInTrip), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('zone-search')), '+5:30');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('zone-Asia/Colombo')), findsOneWidget);
      expect(find.byKey(const ValueKey('zone-Europe/Berlin')), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('zone-search')), 'xyzzy');
      await tester.pumpAndSettle();
      expect(find.text(de.noZoneMatches), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('zone-search')), '');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('zone-none')));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(result!.zone, isNull);
    });
  });

  group('editor', () {
    testWidgets('a stay picks its zone by searching for the city', (tester) async {
      final data = fraToCmb(zoned: false, homeZone: null);
      await openWith(tester, data, (c, ref, d) => openItemEditor(c, d, item: d.item('cmb')));
      final tile = find.byKey(const ValueKey('field-tz'));
      expect(find.descendant(of: tile, matching: find.textContaining(de.zoneNone)), findsOneWidget);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('zone-search')), 'colombo');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('zone-Asia/Colombo')));
      await tester.pumpAndSettle();
      expect(find.descendant(of: tile, matching: find.textContaining(colombo)), findsOneWidget);
      // The time fields now name the local time.
      expect(find.textContaining(de.localTimeIn('$colombo (UTC+5:30)')), findsNWidgets(1));
      await tester.tap(find.text(de.save));
      await settle(tester);
      final saved = (await tester.runAsync(() => repo.loadTrip('zt')))!;
      expect(saved.item('cmb')!.tz, colombo);
    });

    testWidgets('a stay without own zone names the trip zone', (tester) async {
      final data = fraToCmb(zoned: false);
      await openWith(tester, data, (c, ref, d) => openItemEditor(c, d, item: d.item('cmb')));
      expect(find.textContaining(de.zoneNoneHome(berlin)), findsOneWidget);
    });

    testWidgets('a transport across zones shows both zones and the real duration', (tester) async {
      await openWith(tester, fraToCmb(), (c, ref, d) => openItemEditor(c, d, item: d.item('lh')));
      expect(find.text(de.departureZoneLabel), findsOneWidget);
      expect(find.text(de.arrivalZoneLabel), findsOneWidget);
      expect(find.textContaining(de.zoneAutomatic(berlin)), findsOneWidget);
      expect(find.textContaining(de.zoneAutomatic(colombo)), findsOneWidget);
      expect(find.byKey(const ValueKey('real-duration')), findsOneWidget);
      expect(find.text(de.realDuration(de.duration(8 * 60 + 30, withMinutes: true))), findsOneWidget);
      expect(find.text(de.localTimeIn('$berlin (UTC+1)')), findsOneWidget);
      expect(find.text(de.localTimeIn('$colombo (UTC+5:30)')), findsOneWidget);
    });

    testWidgets('without zones the editor looks as before', (tester) async {
      await openWith(
          tester, fraToCmb(zoned: false, homeZone: null), (c, ref, d) => openItemEditor(c, d, item: d.item('lh')));
      expect(find.text(de.departureZoneLabel), findsNothing);
      expect(find.byKey(const ValueKey('real-duration')), findsNothing);
      expect(find.byKey(const ValueKey('start-zone')), findsNothing);
    });

    testWidgets('overriding the arrival zone is saved; tz is dropped from activities', (tester) async {
      await openWith(tester, fraToCmb(), (c, ref, d) => openItemEditor(c, d, item: d.item('lh')));
      await tester.tap(find.byKey(const ValueKey('field-end-tz')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('zone-search')), 'kolkata');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('zone-Asia/Kolkata')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(de.save));
      await settle(tester);
      final saved = (await tester.runAsync(() => repo.loadTrip('zt')))!;
      expect(saved.item('lh')!.endTz, 'Asia/Kolkata');
      expect(saved.item('lh')!.tz, isNull);
    });
  });

  group('item sheet and agenda', () {
    testWidgets('the flight shows both UTC offsets and its real duration', (tester) async {
      await openWith(tester, fraToCmb(), (c, ref, d) => showItemSheet(c, ref, d.trip.id, 'lh'));
      final summary = find.textContaining('UTC+1');
      expect(summary, findsOneWidget);
      final text = (tester.widget<Text>(summary)).data!;
      expect(text, contains('UTC+5:30'));
      expect(text, contains(de.duration(8 * 60 + 30, withMinutes: true)));
      expect(find.byKey(const ValueKey('item-zone')), findsNothing);
    });

    testWidgets('a stay shows its local time zone', (tester) async {
      await openWith(tester, fraToCmb(), (c, ref, d) => showItemSheet(c, ref, d.trip.id, 'cmb'));
      expect(find.byKey(const ValueKey('item-zone')), findsOneWidget);
      expect(find.text(de.localTimeIn('$colombo (UTC+5:30)')), findsOneWidget);
    });

    testWidgets('no zone line without zones', (tester) async {
      await openWith(
          tester, fraToCmb(zoned: false, homeZone: null), (c, ref, d) => showItemSheet(c, ref, d.trip.id, 'cmb'));
      expect(find.byKey(const ValueKey('item-zone')), findsNothing);
      expect(find.textContaining('UTC'), findsNothing);
    });

    testWidgets('the agenda shows departure and arrival with their offsets', (tester) async {
      await pumpHost(tester, fraToCmb(), (c, ref, d) => AgendaView(data: d));
      final next = find.byKey(const ValueKey('agenda-next-transport'));
      expect(find.descendant(of: next, matching: find.text(de.agendaDeparts('21:30 UTC+1'))), findsOneWidget);
      expect(find.descendant(of: next, matching: find.textContaining('UTC+5:30')), findsWidgets);
      expect(
          find.descendant(
              of: next, matching: find.text(de.realDuration(de.duration(8 * 60 + 30, withMinutes: true)))),
          findsOneWidget);
    });
  });

  group('trip settings', () {
    testWidgets('picks and clears the home zone', (tester) async {
      Trip? result;
      final data = fraToCmb(homeZone: null);
      await pumpHost(
        tester,
        data,
        (c, ref, d) => TextButton(
          onPressed: () async => result = await showTripSettingsDialog(c, d.trip, usedZones: [colombo]),
          child: const Text('open'),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(de.homeZoneLabel), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home-zone')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('zone-search')), 'berlin');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('zone-Europe/Berlin')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(de.save));
      await tester.pumpAndSettle();
      expect(result!.homeZone, berlin);
    });

    testWidgets('clears the home zone with the tile\'s clear button', (tester) async {
      Trip? result;
      await pumpHost(
        tester,
        fraToCmb(),
        (c, ref, d) => TextButton(
          onPressed: () async => result = await showTripSettingsDialog(c, d.trip),
          child: const Text('open'),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final tile = find.byKey(const ValueKey('home-zone'));
      expect(find.descendant(of: tile, matching: find.textContaining(berlin)), findsOneWidget);
      await tester.tap(find.descendant(of: tile, matching: find.byIcon(Icons.clear)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(de.save));
      await tester.pumpAndSettle();
      expect(result!.homeZone, isNull);
    });
  });
}
