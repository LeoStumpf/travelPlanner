import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:travel_planner/data/attachment_store.dart';
import 'package:travel_planner/data/db.dart';
import 'package:travel_planner/data/repository.dart';
import 'package:travel_planner/data/sharing.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/domain/time.dart';
import 'package:travel_planner/state/providers.dart';
import 'package:travel_planner/ui/common/l10n.dart';
import 'package:travel_planner/ui/share/itinerary_doc.dart';
import 'package:travel_planner/ui/share/itinerary_pdf.dart';
import 'package:travel_planner/ui/share/share_trip.dart';

import '../l10n_test_utils.dart';
import '../share_fixture.dart';

/// Records what would go to the share sheet.
class FakeSharer extends Sharer {
  final texts = <String>[];
  final files = <(String name, String mime, Uint8List bytes)>[];

  @override
  Future<void> shareText(String text, {String? subject}) async => texts.add(text);

  @override
  Future<void> shareFile(Uint8List bytes, {required String name, required String mime, String? subject}) async =>
      files.add((name, mime, bytes));
}

void main() {
  final now = DateTime(2027, 3, 1, 9);
  setUpAll(() async {
    await initializeDateFormatting('de');
    await initializeDateFormatting('en');
  });

  String text(AppLocalizations l, TripData data) => itineraryText(ItineraryWriter(l, data).document(now: now), l);

  group('itinerary text', () {
    test('day by day with places, times, tickets, beds and notes', () {
      final t = text(en, sharedTrip());
      expect(t, startsWith('Sri Lanka\n5 days\n${en.shareNoStartDate}\n'));
      expect(t, contains('ROUTE\n• Colombo – 2 nights (Day 1 – Day 3)\n• Kandy – 2 nights (Day 3 – Day 5)\n'));
      expect(t, contains('Day 1 – Colombo\n  15:00  Check-in: Hotel Galle Face (booked)\n      Galle Road 2\n      2 nights, until Day 3\n'));
      expect(t, contains('Day 2 – Colombo\n  Night: Hotel Galle Face\n'));
      expect(
          t,
          contains('Day 3 – Colombo → Kandy\n'
              '  11:00  Check-out: Hotel Galle Face\n'
              '  11:30–14:30  Train: Colombo → Kandy (booked)\n'
              '      Colombo Fort → Kandy\n'
              '      Train / flight no.: IC 1009\n'
              '      Seat / platform: Car 3, seat 42\n'
              '      Booking reference: PNR42\n'
              '  No accommodation yet\n'));
      expect(
          t,
          contains('  09:00–11:00  Temple of the Tooth\n'
              '      Sri Dalada Maligawa\n'
              '      Bring a scarf\n'
              '      Tickets: Buy at the gate\n'));
      expect(t, contains('NOTES\n• Packing\n  [x] Sun cream\n  [ ] Adapter\n'));
      expect(t.trimRight(), endsWith(en.shareGeneratedBy(en.date(now))));
    });

    test('options, ideas and unscheduled items stay private', () {
      final t = text(en, sharedTrip());
      for (final title in ['Kandy Hills', 'Spice garden', 'Elephant orphanage']) {
        expect(t, isNot(contains(title)));
      }
    });

    test('with a start date: calendar dates in the active language', () {
      final start = DateTime(2027, 3, 10);
      final t = text(de, sharedTrip(startDate: start));
      expect(t, startsWith('Sri Lanka\n${de.date(start)} – ${de.date(DateTime(2027, 3, 14))} · ${de.days(5)}\n\n'));
      expect(t, contains('${de.day(start, 0, withDayNumber: true)} – Colombo\n'));
      expect(t, contains(de.shareCheckIn('Hotel Galle Face')));
      expect(t, contains('${de.modeTrain}: Colombo → Kandy (${de.shareBooked})'));
      expect(t, contains(de.shareNoBed));
      expect(t, isNot(contains(de.shareNoStartDate)));
    });

    test('a transport across zones shows the offsets and the real duration', () {
      final data = sharedTrip(startDate: DateTime(2027, 3, 10));
      final flight = data.item('train')!.copyWith(
          mode: TransportMode.plane, tz: 'Europe/Berlin', endTz: 'Asia/Colombo', start: at(1, 21 * 60 + 30), end: at(2, 10 * 60 + 30));
      final items = <PlanItem>[for (final i in data.items) i.id == 'train' ? flight : i];
      final t = text(en, TripData(trip: data.trip, items: items));
      expect(t, contains('21:30–10:30 (${en.day(data.trip.startDate, 2)})  Flight: Colombo → Kandy'));
      expect(t, contains('UTC+1 → UTC+5:30 · Duration 8h 30m'));
    });

    test('a free day says so', () {
      final data = sharedTrip();
      final t = text(en, TripData(trip: data.trip.copyWith(plannedDays: 6), items: data.items));
      expect(t, contains('Day 6\n  Nothing planned\n'));
    });

    test('file names are safe', () {
      expect(shareFileName(sharedTrip().trip, 'pdf'), 'Sri Lanka.pdf');
      final odd = sharedTrip().trip.copyWith(title: 'Rom/Neapel: 2027?');
      expect(shareFileName(odd, 'ics'), 'Rom_Neapel_ 2027_.ics');
      expect(shareFileName(odd.copyWith(title: '  '), 'ics'), 'trip.ics');
    });

    test('calendar events: mode in the title, ticket details in the description', () {
      final data = sharedTrip();
      final w = ItineraryWriter(de, data);
      expect(w.eventSummary(data.item('train')!), '${de.modeTrain}: Colombo → Kandy');
      expect(w.eventSummary(data.item('hotel')!), 'Hotel Galle Face');
      final d = w.eventDescription(data.item('train')!);
      expect(d, contains('${de.bookingRefLabel}: PNR42'));
      expect(d, contains(de.statusBooked));
      expect(w.eventDescription(data.item('temple')!), 'Sri Dalada Maligawa\nBring a scarf\nTickets: Buy at the gate');
    });
  });

  group('PDF', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('renders the itinerary with the bundled fonts', () async {
      final fonts = await PdfFonts.load();
      final bytes = await itineraryPdf(ItineraryWriter(en, sharedTrip()).document(now: now), en, fonts);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(2000));
    });

    test('a long trip breaks across pages', () async {
      final data = sharedTrip(startDate: DateTime(2027, 3, 10));
      final many = <PlanItem>[
        ...data.items,
        for (var n = 0; n < 120; n++)
          PlanItem(
            id: 'a$n',
            tripId: 't',
            kind: ItemKind.activity,
            title: 'Activity $n',
            notes: 'Line one\nLine two',
            start: at(3, 8 * 60 + n),
            end: at(3, 8 * 60 + n + 30),
            createdAt: now,
          ),
      ];
      final fonts = await PdfFonts.load();
      final bytes =
          await itineraryPdf(ItineraryWriter(de, TripData(trip: data.trip, items: many)).document(now: now), de, fonts);
      final raw = String.fromCharCodes(bytes);
      expect(RegExp(r'/Type\s*/Page\b').allMatches(raw).length, greaterThan(2));
    });
  });

  group('share sheet', () {
    late Repository repo;
    late ProviderContainer container;
    late FakeSharer sharer;

    setUp(() {
      repo = Repository(AppDatabase(NativeDatabase.memory()), AttachmentStore(Directory.systemTemp));
      sharer = FakeSharer();
      container = ProviderContainer(overrides: [
        repositoryProvider.overrideWithValue(repo),
        sharerProvider.overrideWithValue(sharer),
        clockProvider.overrideWithValue(() => now),
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

    Future<void> openSheet(WidgetTester tester, TripData data) async {
      await tester.runAsync(() => repo.putTripData(data));
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: testApp(
          home: Scaffold(
            body: Consumer(builder: (context, ref, _) {
              final d = ref.watch(tripDataProvider(data.trip.id)).value;
              return d == null
                  ? const Text('loading')
                  : TextButton(onPressed: () => showShareSheet(context, ref, d), child: const Text('open'));
            }),
          ),
        ),
      ));
      await settle(tester);
      await tester.tap(find.text('open'));
      await settle(tester);
    }

    testWidgets('offers text, PDF and calendar; explains a missing start date', (tester) async {
      await openSheet(tester, sharedTrip());
      expect(find.text(de.shareSheetTitle), findsOneWidget);
      expect(find.text(de.shareAsText), findsOneWidget);
      expect(find.text(de.shareAsPdf), findsOneWidget);
      expect(find.text(de.shareCalendar), findsOneWidget);
      expect(find.textContaining(de.shareNoStartDate), findsOneWidget);
      expect(find.textContaining(de.shareCalendarNeedsDate), findsOneWidget);
    });

    testWidgets('text goes to the share sheet', (tester) async {
      await openSheet(tester, sharedTrip());
      await tester.tap(find.byKey(const ValueKey('share-text')));
      await settle(tester);
      expect(sharer.texts, hasLength(1));
      expect(sharer.texts.single, contains(de.shareCheckIn('Hotel Galle Face')));
    });

    testWidgets('copy puts the text on the clipboard', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await openSheet(tester, sharedTrip());
      await tester.tap(find.byKey(const ValueKey('share-copy')));
      await settle(tester);
      expect(copied, startsWith('Sri Lanka\n'));
      expect(find.text(de.shareTextCopied), findsOneWidget);
      expect(sharer.texts, isEmpty);
    });

    testWidgets('PDF is shared as a file', (tester) async {
      await openSheet(tester, sharedTrip());
      await tester.tap(find.byKey(const ValueKey('share-pdf')));
      await tester.pump();
      await tester.runAsync(() async {
        for (var n = 0; n < 50 && sharer.files.isEmpty; n++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      });
      await tester.pumpAndSettle();
      expect(sharer.files.single.$1, 'Sri Lanka.pdf');
      expect(sharer.files.single.$2, 'application/pdf');
      expect(String.fromCharCodes(sharer.files.single.$3.take(5)), '%PDF-');
    });

    testWidgets('calendar with a start date is shared right away', (tester) async {
      await openSheet(tester, sharedTrip(startDate: DateTime(2027, 3, 10)));
      await tester.tap(find.byKey(const ValueKey('share-ics')));
      await settle(tester);
      expect(sharer.files.single.$1, 'Sri Lanka.ics');
      expect(sharer.files.single.$2, 'text/calendar');
      final ics = utf8.decode(sharer.files.single.$3);
      expect(ics, contains('DTSTART:20270312T113000'));
      expect(ics, contains('SUMMARY:${de.modeTrain}: Colombo → Kandy'));
    });

    testWidgets('calendar without a start date asks for it and saves it with undo', (tester) async {
      await openSheet(tester, sharedTrip());
      await tester.tap(find.byKey(const ValueKey('share-ics')));
      await settle(tester);
      expect(find.text(de.shareStartDateTitle), findsOneWidget);
      await tester.tap(find.text(de.sharePickDate));
      await settle(tester);
      await tester.tap(find.text('OK'));
      await settle(tester);

      final stored = (await tester.runAsync(() => repo.loadTrip('t')))!;
      expect(stored.trip.startDate, DateTime(2027, 3, 1));
      expect(container.read(undoLabelProvider('t')), de.stepStartDateSet);
      final ics = utf8.decode(sharer.files.single.$3);
      expect(ics, contains('DTSTART;VALUE=DATE:20270301'));
    });

    testWidgets('calendar: cancelling the date question shares nothing', (tester) async {
      await openSheet(tester, sharedTrip());
      await tester.tap(find.byKey(const ValueKey('share-ics')));
      await settle(tester);
      await tester.tap(find.text(de.cancel));
      await settle(tester);
      expect(sharer.files, isEmpty);
      expect((await tester.runAsync(() => repo.loadTrip('t')))!.trip.startDate, isNull);
    });

    testWidgets('calendar with nothing planned says so', (tester) async {
      await openSheet(tester, TripData(trip: sharedTrip(startDate: DateTime(2027, 3, 10)).trip));
      await tester.tap(find.byKey(const ValueKey('share-ics')));
      await settle(tester);
      expect(find.text(de.shareNothingToExport), findsOneWidget);
      expect(sharer.files, isEmpty);
    });
  });
}
