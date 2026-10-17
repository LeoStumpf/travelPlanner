import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/domain/reminders.dart';
import 'package:travel_planner/domain/time.dart';

final _t0 = DateTime(2026, 1, 1);

/// Trip day 0 = 1 March 2027 (Colombo is UTC+5:30 all year).
final _start = DateTime(2027, 3, 1);
const colombo = 'Asia/Colombo';
const berlin = 'Europe/Berlin';

/// Well before the trip.
final _before = DateTime.utc(2027, 2, 1);

PlanItem stay(String id, int start, int end, {String? tz}) =>
    PlanItem(id: id, tripId: 't', kind: ItemKind.stay, title: id, start: start, end: end, tz: tz, createdAt: _t0);

PlanItem ride(String id, int start, int end,
        {String? from, String? to, ItemStatus status = ItemStatus.booked, String? station}) =>
    PlanItem(
      id: id,
      tripId: 't',
      kind: ItemKind.transport,
      title: id,
      mode: TransportMode.train,
      fromId: from,
      toId: to,
      status: status,
      start: start,
      end: end,
      departureStation: station,
      createdAt: _t0,
    );

PlanItem hotel(String id, String parent, int start, int end, {ItemStatus status = ItemStatus.planned}) => PlanItem(
      id: id,
      tripId: 't',
      kind: ItemKind.accommodation,
      title: id,
      parentId: parent,
      status: status,
      start: start,
      end: end,
      createdAt: _t0,
    );

TripData trip(List<PlanItem> items, {DateTime? start, String? homeZone, String id = 't'}) => TripData(
      trip: Trip(id: id, title: 'T', startDate: start, homeZone: homeZone, createdAt: _t0),
      items: items,
    );

const on = ReminderSettings(enabled: true);

void main() {
  group('remindersFor', () {
    // Colombo (day 0–3) → train day 3 07:30–10:00 → Kandy (day 3–5).
    final items = [
      stay('cmb', at(0, 14 * 60), at(3, 10 * 60), tz: colombo),
      hotel('h1', 'cmb', at(0, 15 * 60), at(3, 11 * 60)),
      ride('train', at(3, 7 * 60 + 30), at(3, 10 * 60), from: 'cmb', to: 'kdy'),
      stay('kdy', at(3, 14 * 60), at(5, 10 * 60), tz: colombo),
    ];

    test('nothing while off or without a start date', () {
      expect(remindersFor(trip(items, start: _start), ReminderSettings.off, _before), isEmpty);
      expect(remindersFor(trip(items), on, _before), isEmpty);
    });

    test('departure, check-in and check-out at real instants', () {
      final rs = remindersFor(trip(items, start: _start), on, _before);
      expect([for (final r in rs) (r.itemId, r.type)], [
        ('h1', ReminderType.checkIn),
        ('train', ReminderType.departure),
        ('h1', ReminderType.checkOut),
      ]);
      // Day 3 07:30 in Colombo = 4 March 02:00 UTC; 2 h before = 00:00 UTC.
      final train = rs[1];
      expect(train.eventAt, DateTime.utc(2027, 3, 4, 2));
      expect(train.fireAt, DateTime.utc(2027, 3, 4));
      expect(train.eventMinute, at(3, 7 * 60 + 30));
      expect(train.payload, 't/train');
      // Check-in day 0 15:00 Colombo = 09:30 UTC.
      expect(rs[0].eventAt, DateTime.utc(2027, 3, 1, 9, 30));
      // Check-out day 3 11:00 Colombo = 05:30 UTC.
      expect(rs[2].eventAt, DateTime.utc(2027, 3, 4, 5, 30));
    });

    test('one reminder per lead time, in firing order', () {
      final s = on.copyWith(leads: [120, 1440], checkIns: false, checkOuts: false);
      final rs = remindersFor(trip(items, start: _start), s, _before);
      expect([for (final r in rs) r.lead], [1440, 120]);
      expect(rs.first.fireAt, DateTime.utc(2027, 3, 3, 2));
      expect(rs.first.id, isNot(rs.last.id));
    });

    test('the type switches filter', () {
      final s = on.copyWith(departures: false, checkOuts: false);
      final rs = remindersFor(trip(items, start: _start), s, _before);
      expect([for (final r in rs) r.type], [ReminderType.checkIn]);
    });

    test('options, ideas and unscheduled items get none', () {
      final rs = remindersFor(
        trip([
          ride('opt', at(1, 600), at(1, 700), status: ItemStatus.option),
          ride('idea', at(1, 600), at(1, 700), status: ItemStatus.idea),
          PlanItem(id: 'u', tripId: 't', kind: ItemKind.transport, title: 'u', createdAt: _t0),
          PlanItem(
              id: 'act', tripId: 't', kind: ItemKind.activity, title: 'a', start: 600, end: 700, createdAt: _t0),
          ride('ok', at(1, 600), at(1, 700), status: ItemStatus.planned),
        ], start: _start),
        on,
        _before,
      );
      expect([for (final r in rs) r.itemId], ['ok']);
    });

    test('past events and lead times already passed are skipped', () {
      // Now: 4 March 01:00 UTC – the train leaves at 02:00 UTC, so its 2 h
      // reminder (00:00) is over, the 30 min one (01:30) still ahead.
      final now = DateTime.utc(2027, 3, 4, 1);
      final s = on.copyWith(leads: [120, 30]);
      final rs = remindersFor(trip(items, start: _start), s, now);
      expect([for (final r in rs) (r.itemId, r.type, r.lead)], [
        ('train', ReminderType.departure, 30),
        ('h1', ReminderType.checkOut, 120),
        ('h1', ReminderType.checkOut, 30),
      ]);
    });

    test('floating times are wall-clock times of the phone', () {
      final rs = remindersFor(trip([ride('r', at(2, 9 * 60), at(2, 11 * 60))], start: _start), on, _before);
      expect(rs.single.eventAt, DateTime(2027, 3, 3, 9).toUtc());
      expect(rs.single.fireAt, DateTime(2027, 3, 3, 7).toUtc());
    });

    test('the home zone applies to items without their own', () {
      // Berlin is UTC+1 in March: day 1 08:00 = 07:00 UTC.
      final rs = remindersFor(
          trip([ride('r', at(1, 8 * 60), at(1, 9 * 60))], start: _start, homeZone: berlin), on, _before);
      expect(rs.single.eventAt, DateTime.utc(2027, 3, 2, 7));
    });
  });

  group('upcomingReminders', () {
    test('merges trips nearest first and caps the number', () {
      final a = trip([ride('a1', at(5, 600), at(5, 700)), ride('a2', at(1, 600), at(1, 700))],
          start: _start, homeZone: berlin, id: 'A');
      final b = trip([ride('b1', at(3, 600), at(3, 700))], start: _start, homeZone: berlin, id: 'B');
      final all = upcomingReminders([(a, on), (b, on)], _before);
      expect([for (final r in all) r.itemId], ['a2', 'b1', 'a1']);
      expect(all[1].tripId, 'B');
      final capped = upcomingReminders([(a, on), (b, on)], _before, limit: 2);
      expect([for (final r in capped) r.itemId], ['a2', 'b1']);
      expect(upcomingReminders([(a, ReminderSettings.off)], _before), isEmpty);
    });
  });

  group('ids and payloads', () {
    test('ids are stable, positive 31-bit and differ per type and lead', () {
      final id = reminderId('x', ReminderType.departure, 120);
      expect(reminderId('x', ReminderType.departure, 120), id);
      expect(id, inInclusiveRange(0, 0x7fffffff));
      expect(reminderId('x', ReminderType.checkIn, 120), isNot(id));
      expect(reminderId('x', ReminderType.departure, 60), isNot(id));
      expect(reminderId('y', ReminderType.departure, 120), isNot(id));
    });

    test('payloads parse back', () {
      expect(parseReminderPayload('trip/item'), ('trip', 'item'));
      expect(parseReminderPayload(null), isNull);
      expect(parseReminderPayload('nothing'), isNull);
      expect(parseReminderPayload('/x'), isNull);
      expect(parseReminderPayload('x/'), isNull);
    });
  });

  group('ReminderSettings', () {
    test('JSON round trip and lenient parsing', () {
      final s = on.copyWith(leads: [30, 1440], checkOuts: false);
      expect(s.leads, [1440, 30]);
      expect(ReminderSettings.fromJson(s.toJson()), s);
      expect(ReminderSettings.fromJson('junk'), ReminderSettings.off);
      final odd = ReminderSettings.fromJson({'enabled': true, 'leads': ['x', -5]});
      expect(odd.enabled, isTrue);
      expect(odd.leads, [defaultReminderLead]);
    });

    test('toggleLead adds and removes but keeps the last one', () {
      var s = on.toggleLead(1440);
      expect(s.leads, [1440, 120]);
      s = s.toggleLead(120);
      expect(s.leads, [1440]);
      expect(s.toggleLead(1440).leads, [1440]);
    });
  });
}
