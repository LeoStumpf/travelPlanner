import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_planner/data/attachment_store.dart';
import 'package:travel_planner/data/db.dart';
import 'package:travel_planner/data/reminder_scheduler.dart';
import 'package:travel_planner/data/repository.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/domain/reminders.dart';
import 'package:travel_planner/domain/time.dart';
import 'package:travel_planner/l10n/app_localizations.dart';
import 'package:travel_planner/state/hints.dart';
import 'package:travel_planner/state/providers.dart';
import 'package:travel_planner/state/reminders.dart';
import 'package:travel_planner/ui/reminders/reminder_listener.dart';
import 'package:travel_planner/ui/reminders/reminder_sheet.dart';
import 'package:travel_planner/ui/reminders/reminder_texts.dart';
import 'package:travel_planner/ui/share/share_listener.dart';
import 'package:travel_planner/ui/trip/trip_page.dart';
import 'package:travel_planner/ui/trips/trip_settings_dialog.dart';

import '../l10n_test_utils.dart';

/// Records what the app schedules instead of talking to the platform.
class FakeScheduler implements ReminderScheduler {
  final syncs = <List<ReminderNotice>>[];
  final tapController = StreamController<String>.broadcast();
  ReminderPermissions perms = const ReminderPermissions();
  bool grant = true;
  int requests = 0, exactRequests = 0, settingsOpened = 0;
  String? launch;

  @override
  Future<void> sync(List<ReminderNotice> notices) async => syncs.add(notices);

  @override
  Future<ReminderPermissions> permissions() async => perms;

  @override
  Future<bool> requestNotifications() async {
    requests++;
    if (grant) perms = ReminderPermissions(exactAlarms: perms.exactAlarms);
    return grant;
  }

  @override
  Future<void> requestExactAlarms() async => exactRequests++;

  @override
  Future<void> openSettings() async => settingsOpened++;

  @override
  Stream<String> get taps => tapController.stream;

  @override
  Future<String?> launchPayload() async => launch;
}

final _t0 = DateTime(2026, 1, 1);

/// "Now": 17 Oct 2026, 12:00. The trip starts 20 Oct (Berlin, UTC+2).
final now = DateTime(2026, 10, 17, 12);

TripData sample({DateTime? start}) {
  final trip = Trip(
      id: 'trip', title: 'Herbst', startDate: start ?? DateTime(2026, 10, 20), homeZone: 'Europe/Berlin', createdAt: _t0);
  return TripData(trip: trip, items: [
    PlanItem(
        id: 'muc', tripId: 'trip', kind: ItemKind.stay, title: 'München', start: at(0, 840), end: at(2, 600), createdAt: _t0),
    PlanItem(
      id: 'hotel',
      tripId: 'trip',
      kind: ItemKind.accommodation,
      title: 'Hotel Isar',
      placeName: 'Isarweg 1',
      parentId: 'muc',
      start: at(0, 900),
      end: at(2, 660),
      createdAt: _t0,
    ),
    PlanItem(
      id: 'ice',
      tripId: 'trip',
      kind: ItemKind.transport,
      title: 'München → Wien',
      mode: TransportMode.train,
      fromId: 'muc',
      status: ItemStatus.booked,
      departureStation: 'München Hbf',
      transportNumber: 'RJX 61',
      seat: 'Wagen 3, Platz 42',
      start: at(2, 9 * 60 + 30),
      end: at(2, 13 * 60 + 30),
      createdAt: _t0,
    ),
  ]);
}

void main() {
  late Repository repo;
  late ProviderContainer container;
  late FakeScheduler fake;
  late SharedPreferences prefs;

  setUpAll(() async {
    await initializeDateFormatting('de');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = Repository(AppDatabase(NativeDatabase.memory()), AttachmentStore(Directory.systemTemp));
    fake = FakeScheduler();
    container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(repo),
      clockProvider.overrideWithValue(() => now),
      hintPrefsProvider.overrideWithValue(prefs),
      reminderSchedulerProvider.overrideWithValue(fake),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await repo.close();
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: testLocale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        navigatorKey: navigatorKey,
        builder: (context, child) => ReminderListener(child: child!),
        home: home,
      ),
    ));
    await settle(tester);
  }

  group('wording', () {
    test('titles with time, the day for long lead times, bodies with ticket data', () {
      final d = sample();
      final rs = remindersFor(d, const ReminderSettings(enabled: true, leads: [1440, 120]), now);
      final ice2h = rs.firstWhere((r) => r.itemId == 'ice' && r.lead == 120);
      final ice1d = rs.firstWhere((r) => r.itemId == 'ice' && r.lead == 1440);
      expect(de.reminderTitle(d, ice2h), 'Abfahrt 09:30: München → Wien');
      expect(de.reminderTitle(d, ice1d), startsWith('Abfahrt Do., 22. Okt.'));
      expect(de.reminderBody(d, ice2h), 'in 2h · München Hbf · RJX 61 · Wagen 3, Platz 42');
      final checkIn = rs.firstWhere((r) => r.type == ReminderType.checkIn && r.lead == 120);
      expect(en.reminderTitle(d, checkIn), 'Check-in 15:00: Hotel Isar');
      expect(en.reminderBody(d, checkIn), 'in 2h · Isarweg 1');
      expect(de.reminderSummary(ReminderSettings.off), 'Aus');
      expect(de.reminderSummary(const ReminderSettings(enabled: true, leads: [1440, 30])), '1 Tag, 30min vorher');
    });
  });

  group('settings', () {
    test('persist per trip in the shared preferences', () {
      container.read(reminderSettingsProvider.notifier).set('trip', const ReminderSettings(enabled: true, leads: [60]));
      final c2 = ProviderContainer(overrides: [hintPrefsProvider.overrideWithValue(prefs)]);
      addTearDown(c2.dispose);
      expect(c2.read(tripReminderSettingsProvider('trip')), const ReminderSettings(enabled: true, leads: [60]));
      expect(c2.read(tripReminderSettingsProvider('other')), ReminderSettings.off);
    });
  });

  group('scheduling', () {
    testWidgets('schedules on enabling, reschedules on plan changes, cancels on disabling', (tester) async {
      await tester.runAsync(() => repo.putTripData(sample()));
      await pumpApp(tester, const Scaffold(body: Text('home')));
      // Nothing enabled: everything is cancelled once.
      expect(fake.syncs.single, isEmpty);

      container.read(reminderSettingsProvider.notifier).set('trip', const ReminderSettings(enabled: true));
      await settle(tester);
      final first = fake.syncs.last;
      expect([for (final n in first) n.title], [
        'Check-in 15:00: Hotel Isar',
        'Abfahrt 09:30: München → Wien',
        'Check-out 11:00: Hotel Isar',
      ]);
      // 22 Oct 09:30 in Berlin (UTC+2) = 07:30 UTC, 2 h before = 05:30 UTC.
      expect(first[1].reminder.fireAt, DateTime.utc(2026, 10, 22, 5, 30));
      expect(first[1].body, contains('RJX 61'));

      // Moving the train an hour later reschedules it.
      final ice = sample().item('ice')!;
      await tester.runAsync(() => repo.saveItems([ice.shiftedBy(60)]));
      await settle(tester);
      expect(fake.syncs.last[1].title, 'Abfahrt 10:30: München → Wien');
      expect(fake.syncs.last[1].reminder.fireAt, DateTime.utc(2026, 10, 22, 6, 30));

      // An unrelated rebuild with the same reminders does not reschedule.
      final count = fake.syncs.length;
      container.invalidate(reminderInputsProvider);
      await settle(tester);
      expect(fake.syncs.length, count);

      container.read(reminderSettingsProvider.notifier).set('trip', const ReminderSettings(enabled: false));
      await settle(tester);
      expect(fake.syncs.last, isEmpty);
    });

    testWidgets('coming back to the app schedules the same reminders again', (tester) async {
      await tester.runAsync(() => repo.putTripData(sample()));
      container.read(reminderSettingsProvider.notifier).set('trip', const ReminderSettings(enabled: true));
      await pumpApp(tester, const Scaffold(body: Text('home')));
      final count = fake.syncs.length;
      expect(fake.syncs.last, hasLength(3));

      // E.g. back from granting exact alarms: same reminders, new mode.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
      expect(fake.syncs.length, count + 1);
      expect(fake.syncs.last, hasLength(3));
    });

    testWidgets('trashed trips and trips without a start date schedule nothing', (tester) async {
      final d = sample();
      await tester.runAsync(() => repo.putTripData(TripData(trip: d.trip.copyWith(startDate: null), items: d.items)));
      container.read(reminderSettingsProvider.notifier).set('trip', const ReminderSettings(enabled: true));
      await pumpApp(tester, const Scaffold(body: Text('home')));
      expect(fake.syncs.last, isEmpty);

      await tester.runAsync(() => repo.saveTrip(d.trip));
      await settle(tester);
      expect(fake.syncs.last, hasLength(3));

      await tester.runAsync(() => repo.trashTrip('trip'));
      await settle(tester);
      expect(fake.syncs.last, isEmpty);
    });

    testWidgets('a tapped reminder opens its trip with the item selected', (tester) async {
      await tester.runAsync(() => repo.putTripData(sample()));
      await pumpApp(tester, const Scaffold(body: Text('home')));
      fake.tapController.add('trip/ice');
      await settle(tester);
      expect(find.byType(TripPage), findsOneWidget);
      expect(container.read(tripUiProvider).selectedId, 'ice');
    });
  });

  group('sheet', () {
    Future<void> openSheet(WidgetTester tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) =>
                TextButton(onPressed: () => showReminderSheet(context, 'trip'), child: const Text('open')),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await settle(tester);
    }

    testWidgets('switching on asks for the permission and lists the next reminders', (tester) async {
      await tester.runAsync(() => repo.putTripData(sample()));
      fake.perms = const ReminderPermissions(notifications: false);
      await openSheet(tester);
      expect(find.text('Wann'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('reminders-switch')));
      await settle(tester);
      expect(fake.requests, 1);
      expect(container.read(tripReminderSettingsProvider('trip')).enabled, isTrue);
      expect(find.byKey(const ValueKey('reminders-denied')), findsNothing);
      expect(find.text('Nächste Erinnerungen'), findsOneWidget);
      expect(find.text('Abfahrt 09:30: München → Wien'), findsOneWidget);

      // Another lead time doubles the reminders; the last one stays.
      await tester.tap(find.byKey(const ValueKey('reminder-lead-1440')));
      await settle(tester);
      expect(container.read(tripReminderSettingsProvider('trip')).leads, [1440, 120]);
      expect(find.text('+1 weitere'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reminder-lead-1440')));
      await tester.tap(find.byKey(const ValueKey('reminder-lead-120')));
      await settle(tester);
      expect(container.read(tripReminderSettingsProvider('trip')).leads, [120]);

      // Without departures the train drops out.
      await tester.tap(find.byKey(const ValueKey('reminder-type-departure')));
      await settle(tester);
      expect(container.read(tripReminderSettingsProvider('trip')).departures, isFalse);
      expect(find.text('Abfahrt 09:30: München → Wien'), findsNothing);
    });

    testWidgets('a denied permission links to the settings, inexact alarms to the alarm permission', (tester) async {
      await tester.runAsync(() => repo.putTripData(sample()));
      fake
        ..perms = const ReminderPermissions(notifications: false)
        ..grant = false;
      container.read(reminderSettingsProvider.notifier).set('trip', const ReminderSettings(enabled: true));
      await openSheet(tester);
      expect(find.byKey(const ValueKey('reminders-denied')), findsOneWidget);
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('reminders-denied')), matching: find.text('Erlauben')));
      await settle(tester);
      expect(fake.requests, 1);
      expect(fake.settingsOpened, 1);

      fake.perms = const ReminderPermissions(exactAlarms: false);
      container.invalidate(reminderPermissionsProvider);
      await settle(tester);
      expect(find.byKey(const ValueKey('reminders-denied')), findsNothing);
      await tester.tap(find.text('Genaue Zeiten erlauben'));
      await settle(tester);
      expect(fake.exactRequests, 1);
    });

    testWidgets('without a start date the sheet offers to set one', (tester) async {
      final d = sample();
      await tester.runAsync(() => repo.putTripData(TripData(trip: d.trip.copyWith(startDate: null), items: d.items)));
      container.read(reminderSettingsProvider.notifier).set('trip', const ReminderSettings(enabled: true));
      await openSheet(tester);
      expect(find.byKey(const ValueKey('reminders-no-date')), findsOneWidget);
      expect(find.text('Nächste Erinnerungen'), findsNothing);

      await tester.tap(find.text('Startdatum festlegen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await settle(tester);
      final trip = await tester.runAsync(() => repo.loadTrip('trip'));
      expect(trip!.trip.startDate, DateTime(2026, 10, 17));
      expect(find.byKey(const ValueKey('reminders-no-date')), findsNothing);
      expect(container.read(undoLabelProvider('trip')), de.stepStartDateSet);
    });

    testWidgets('the trip settings show the reminders and open the sheet', (tester) async {
      await tester.runAsync(() => repo.putTripData(sample()));
      container.read(reminderSettingsProvider.notifier).set('trip', const ReminderSettings(enabled: true));
      final trip = sample().trip;
      await pumpApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) =>
                TextButton(onPressed: () => showTripSettingsDialog(context, trip), child: const Text('edit')),
          ),
        ),
      );
      await tester.tap(find.text('edit'));
      await settle(tester);
      final tile = find.byKey(const ValueKey('trip-reminders'));
      await tester.ensureVisible(tile);
      expect(find.descendant(of: tile, matching: find.text('2h vorher')), findsOneWidget);
      await tester.tap(tile);
      await settle(tester);
      expect(find.byType(ReminderSheet), findsOneWidget);
    });

    testWidgets('from the trip settings the sheet does not set the start date itself', (tester) async {
      // The dialog's own start date would overwrite it on saving.
      final d = sample();
      final trip = d.trip.copyWith(startDate: null);
      await tester.runAsync(() => repo.putTripData(TripData(trip: trip, items: d.items)));
      container.read(reminderSettingsProvider.notifier).set('trip', const ReminderSettings(enabled: true));
      await pumpApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) =>
                TextButton(onPressed: () => showTripSettingsDialog(context, trip), child: const Text('edit')),
          ),
        ),
      );
      await tester.tap(find.text('edit'));
      await settle(tester);
      final tile = find.byKey(const ValueKey('trip-reminders'));
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await settle(tester);
      expect(find.byKey(const ValueKey('reminders-no-date')), findsOneWidget);
      expect(find.text('Startdatum festlegen'), findsNothing);
    });
  });
}
