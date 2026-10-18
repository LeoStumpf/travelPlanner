import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/domain/agenda.dart';
import 'package:travel_planner/domain/demo.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/domain/time.dart';

void main() {
  // Interrail demo: Paris day 0–3, Lyon 3–5, free days 5–7, Barcelona 8–11,
  // Valencia 11–13; TGV on day 3 11:00–13:00, Euromed day 11 10:30–13:30,
  // flight home day 13 15:00–18:00. Lyon has only lodging options.
  final demo = demoInterrail();
  PlanItem byTitle(String t) => demo.items.firstWhere((i) => i.title == t);
  List<String> titles(Iterable<PlanItem> items) => [for (final i in items) i.title];

  group('trip day of a date', () {
    final trip = demo.trip.copyWith(startDate: DateTime(2026, 10, 15));

    test('counts calendar days from the start date', () {
      expect(tripDayOn(trip, DateTime(2026, 10, 15, 0, 5)), 0);
      expect(tripDayOn(trip, DateTime(2026, 10, 17, 23, 59)), 2);
      expect(tripDayOn(trip, DateTime(2026, 10, 10)), -5);
    });

    test('ignores daylight-saving switches', () {
      final spring = demo.trip.copyWith(startDate: DateTime(2026, 3, 28));
      expect(tripDayOn(spring, DateTime(2026, 3, 30, 0, 30)), 2);
      final autumn = demo.trip.copyWith(startDate: DateTime(2026, 10, 24));
      expect(tripDayOn(autumn, DateTime(2026, 10, 26, 23, 30)), 2);
    });

    test('is null without a start date', () {
      expect(tripDayOn(demo.trip, DateTime(2026, 10, 17)), isNull);
      expect(tripMinuteAt(demo.trip, DateTime(2026, 10, 17)), isNull);
    });

    test('trip minute adds the clock time', () {
      expect(tripMinuteAt(trip, DateTime(2026, 10, 17, 9, 30)), at(2, 9 * 60 + 30));
    });
  });

  group('trip running', () {
    TripData withStart(DateTime? d) => TripData(trip: demo.trip.copyWith(startDate: d), items: demo.items);
    final now = DateTime(2026, 10, 17, 12);

    test('while today lies within the trip days', () {
      expect(isTripRunning(withStart(DateTime(2026, 10, 17)), now), isTrue);
      expect(isTripRunning(withStart(DateTime(2026, 10, 4)), now), isTrue); // last day (13)
    });

    test('not before, after or without a start date', () {
      expect(isTripRunning(withStart(DateTime(2026, 10, 18)), now), isFalse);
      expect(isTripRunning(withStart(DateTime(2026, 10, 3)), now), isFalse);
      expect(isTripRunning(withStart(null), now), isFalse);
    });
  });

  group('agenda of a day', () {
    test('a sightseeing day: stay, booked hotel, activity, next transport later', () {
      final a = agendaFor(demo.items, 1, now: at(1, 15 * 60));
      expect(titles(a.stays), ['Paris']);
      expect(titles(a.lodging), ['Hôtel du Marais']);
      expect(a.checksIn(a.lodging.single), isFalse);
      expect(a.checksOut(a.lodging.single), isFalse);
      expect(a.needsBed, isFalse);
      expect(titles(a.events), ['Louvre']);
      expect(a.nextTransport?.title, 'TGV Paris → Lyon');
      expect(a.isEmpty, isFalse);
    });

    test('a travel day: both stays, check-out, transport, missing bed with options', () {
      final a = agendaFor(demo.items, 3);
      expect(titles(a.stays), ['Paris', 'Lyon']);
      expect(titles(a.lodging), ['Hôtel du Marais']);
      expect(a.checksOut(a.lodging.single), isTrue);
      expect(a.needsBed, isTrue);
      expect(titles(a.lodgingOptions), containsAll(['Airbnb Croix-Rousse', 'Auberge Vieux Lyon']));
      expect(titles(a.events), ['TGV Paris → Lyon']);
      expect(a.nextTransport?.title, 'TGV Paris → Lyon');
    });

    test('next transport skips the one already arrived', () {
      expect(agendaFor(demo.items, 3, now: at(3, 12 * 60)).nextTransport?.title, 'TGV Paris → Lyon',
          reason: 'still under way');
      expect(agendaFor(demo.items, 3, now: at(3, 14 * 60)).nextTransport?.title, 'Euromed Barcelona → Valencia');
    });

    test('"now" on another day does not affect the day\'s next transport', () {
      expect(agendaFor(demo.items, 3, now: at(1, 9 * 60)).nextTransport?.title, 'TGV Paris → Lyon');
    });

    test('a free day is empty but still knows the next transport', () {
      final a = agendaFor(demo.items, 6);
      expect(a.isEmpty, isTrue);
      expect(a.nextTransport?.title, 'Euromed Barcelona → Valencia');
    });

    test('after the last transport there is none', () {
      expect(agendaFor(demo.items, 13, now: at(13, 19 * 60)).nextTransport, isNull);
    });

    test('options and unscheduled ideas are left out', () {
      final a = agendaFor(demo.items, 4);
      expect(titles(a.stays), ['Lyon']);
      expect(a.lodging, isEmpty);
      expect(titles(a.stays), isNot(contains('Avignon')));
    });

    test('check-in on the arrival day', () {
      final a = agendaFor(demo.items, 8);
      expect(titles(a.lodging), ['Hostel Gràcia']);
      expect(a.checksIn(a.lodging.single), isTrue);
    });
  });

  test('tickets: own attachments plus those of linked notes', () {
    final tgv = byTitle('TGV Paris → Lyon');
    final note = NoteCard(id: 'n1', tripId: demo.trip.id, type: CardType.image, itemId: tgv.id, createdAt: DateTime(2026));
    Attachment att(String id, String owner) => Attachment(
        id: id, tripId: demo.trip.id, ownerIds: [owner], fileName: '$id.pdf', relPath: id, mime: 'application/pdf',
        createdAt: DateTime(2026));
    final data = TripData(
      trip: demo.trip,
      items: demo.items,
      cards: [...demo.cards, note],
      attachments: [att('ticket', tgv.id), att('screenshot', 'n1'), att('other', byTitle('Louvre').id)],
    );
    expect([for (final a in ticketsFor(data, tgv.id)) a.id], ['ticket', 'screenshot']);
  });
}
