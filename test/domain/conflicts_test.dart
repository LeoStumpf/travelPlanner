import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/domain/analysis.dart';
import 'package:travel_planner/domain/demo.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/domain/time.dart';
import 'package:travel_planner/domain/zones.dart';

final _t0 = DateTime(2026, 1, 1);

PlanItem stay(String id, int firstDay, int nights, {String? tz}) => PlanItem(
      id: id,
      tripId: 't',
      kind: ItemKind.stay,
      title: id,
      tz: tz,
      start: at(firstDay, defaultStayArrival),
      end: at(firstDay + nights, defaultStayDeparture),
      createdAt: _t0,
    );

PlanItem bed(String id, int day, int endDay, ItemStatus status, {String parent = 'paris', bool fixed = false}) =>
    PlanItem(
      id: id,
      tripId: 't',
      kind: ItemKind.accommodation,
      title: id,
      parentId: parent,
      status: status,
      fixed: fixed,
      start: at(day, defaultCheckIn),
      end: at(endDay, defaultCheckOut),
      createdAt: _t0,
    );

PlanItem ride(String id, int start, int end,
        {ItemStatus status = ItemStatus.planned, String? from, String? to, String? tz, String? endTz}) =>
    PlanItem(
      id: id,
      tripId: 't',
      kind: ItemKind.transport,
      title: id,
      status: status,
      fromId: from,
      toId: to,
      tz: tz,
      endTz: endTz,
      start: start,
      end: end,
      createdAt: _t0,
    );

PlanItem visit(String id, int start, int end,
        {String parent = 'paris', ItemStatus status = ItemStatus.planned, bool fixed = false}) =>
    PlanItem(
      id: id,
      tripId: 't',
      kind: ItemKind.activity,
      title: id,
      parentId: parent,
      status: status,
      fixed: fixed,
      start: start,
      end: end,
      createdAt: _t0,
    );

List<PlanItem> applyFix(List<PlanItem> items, Conflict c) {
  final changed = {for (final i in c.fix!.apply(items)) i.id: i};
  return [for (final i in items) changed[i.id] ?? i];
}

List<Conflict> ofType(List<PlanItem> items, ConflictType type, {TripZones? zones}) =>
    findConflicts(items, zones: zones).where((c) => c.type == type).toList();

void main() {
  group('two confirmed accommodations in one night', () {
    test('planned vs planned: the later one becomes an option', () {
      final items = [
        stay('paris', 0, 4),
        bed('ibis', 0, 3, ItemStatus.planned),
        bed('hilton', 2, 4, ItemStatus.planned),
      ];
      final c = ofType(items, ConflictType.lodgingsOverlap).single;
      expect(c.itemId, 'hilton');
      expect(c.otherId, 'ibis');
      expect(c.amount, 1, reason: 'night 2 → 3');
      expect(c.fix!.type, ConflictFixType.makeOption);
      expect(c.fix!.subject, 'hilton');
      final fixed = applyFix(items, c);
      expect(fixed.firstWhere((i) => i.id == 'hilton').status, ItemStatus.option);
      expect(findConflicts(fixed), isEmpty);
    });

    test('booked wins: the planned one is demoted even when it starts earlier', () {
      final items = [
        stay('paris', 0, 4),
        bed('ibis', 0, 3, ItemStatus.planned),
        bed('hilton', 1, 4, ItemStatus.booked),
      ];
      final c = ofType(items, ConflictType.lodgingsOverlap).single;
      expect(c.amount, 2);
      expect(c.fix!.statuses, {'ibis': ItemStatus.option});
    });

    test('both booked: no fix, and the reason says so', () {
      final items = [
        stay('paris', 0, 4),
        bed('ibis', 0, 3, ItemStatus.booked),
        bed('hilton', 1, 4, ItemStatus.booked),
      ];
      final c = ofType(items, ConflictType.lodgingsOverlap).single;
      expect(c.fix, isNull);
      expect(c.noFix, NoFixReason.bothBooked);
    });

    test('options, ideas, back-to-back nights and undated ones never clash', () {
      final items = [
        stay('paris', 0, 4),
        bed('ibis', 0, 2, ItemStatus.planned),
        bed('next', 2, 4, ItemStatus.planned),
        bed('opt', 0, 4, ItemStatus.option),
        bed('idea', 0, 4, ItemStatus.idea),
        bed('undated', 0, 4, ItemStatus.planned).copyWith(start: null, end: null),
      ];
      expect(ofType(items, ConflictType.lodgingsOverlap), isEmpty);
    });
  });

  group('activity during a transport', () {
    final base = [stay('paris', 0, 2), stay('lyon', 2, 2)];

    test('at the destination: moved after the arrival, same length', () {
      final items = [
        ...base,
        ride('tgv', at(2, 9 * 60), at(2, 11 * 60), from: 'paris', to: 'lyon'),
        visit('food', at(2, 10 * 60), at(2, 12 * 60), parent: 'lyon'),
      ];
      final c = ofType(items, ConflictType.activityDuringTransport).single;
      expect((c.itemId, c.otherId), ('food', 'tgv'));
      expect(c.amount, 60);
      expect(c.fix!.type, ConflictFixType.moveAfterTransport);
      expect(c.fix!.subject, 'tgv');
      expect(c.fix!.times['food'], (at(2, 11 * 60), at(2, 13 * 60)));
      expect(ofType(applyFix(items, c), ConflictType.activityDuringTransport), isEmpty);
    });

    test('at the origin: moved to end at the departure', () {
      final items = [
        ...base,
        ride('tgv', at(2, 9 * 60), at(2, 11 * 60), from: 'paris', to: 'lyon'),
        visit('louvre', at(2, 8 * 60), at(2, 10 * 60)),
      ];
      final c = ofType(items, ConflictType.activityDuringTransport).single;
      expect(c.fix!.type, ConflictFixType.moveBeforeTransport);
      expect(c.fix!.times['louvre'], (at(2, 7 * 60), at(2, 9 * 60)));
    });

    test('unrelated stay: the nearer side wins', () {
      final items = [
        ...base,
        ride('bus', at(1, 9 * 60), at(1, 12 * 60)),
        visit('early', at(1, 8 * 60), at(1, 10 * 60)),
        visit('late', at(1, 11 * 60), at(1, 13 * 60)),
      ];
      final cs = ofType(items, ConflictType.activityDuringTransport);
      expect({for (final c in cs) c.itemId: c.fix!.type}, {
        'early': ConflictFixType.moveBeforeTransport,
        'late': ConflictFixType.moveAfterTransport,
      });
    });

    test('fixed activity: no fix, named in the reason', () {
      final items = [
        ...base,
        ride('tgv', at(2, 9 * 60), at(2, 11 * 60)),
        visit('tour', at(2, 10 * 60), at(2, 12 * 60), fixed: true),
      ];
      final c = ofType(items, ConflictType.activityDuringTransport).single;
      expect(c.fix, isNull);
      expect(c.noFix, NoFixReason.fixed);
      expect(c.noFixSubject, 'tour');
    });

    test('touching, option transports and idea activities are fine', () {
      final items = [
        ...base,
        ride('tgv', at(2, 9 * 60), at(2, 11 * 60)),
        ride('alt', at(2, 12 * 60), at(2, 14 * 60), status: ItemStatus.option),
        visit('after', at(2, 11 * 60), at(2, 12 * 60)),
        visit('maybe', at(2, 10 * 60), at(2, 11 * 60), status: ItemStatus.idea),
        visit('during-alt', at(2, 13 * 60), at(2, 14 * 60)),
      ];
      expect(ofType(items, ConflictType.activityDuringTransport), isEmpty);
    });

    test('compared on absolute time across zones', () {
      // Flight leaves Berlin 10:00 (09:00 UTC), lands in Colombo 22:00
      // (16:30 UTC). A dinner in Colombo at 21:00 local (15:30 UTC) clashes,
      // although 21:00 < 22:00 only by the local clock of the flight's end.
      const berlin = 'Europe/Berlin', colombo = 'Asia/Colombo';
      final items = [
        stay('fra', 0, 1, tz: berlin),
        stay('cmb', 1, 3, tz: colombo),
        ride('lh', at(1, 10 * 60), at(1, 22 * 60), from: 'fra', to: 'cmb'),
        visit('dinner', at(1, 21 * 60), at(1, 23 * 60), parent: 'cmb'),
      ];
      final zones = TripZones.of(Trip(id: 't', title: 'T', startDate: DateTime(2027, 3, 1), createdAt: _t0), items);
      final c = ofType(items, ConflictType.activityDuringTransport, zones: zones).single;
      expect(c.amount, 60);
      expect(c.fix!.times['dinner'], (at(1, 22 * 60), at(1, 24 * 60)), reason: 'in Colombo local time');
    });
  });

  group('two confirmed transports at once', () {
    test('the later one departs before the earlier arrives', () {
      final items = [
        ride('ice', at(1, 8 * 60), at(1, 12 * 60)),
        ride('bus', at(1, 11 * 60), at(1, 15 * 60)),
      ];
      final c = ofType(items, ConflictType.transportsOverlap).single;
      expect((c.itemId, c.otherId, c.amount), ('bus', 'ice', 60));
      expect(c.fix!.type, ConflictFixType.makeOption);
      expect(c.fix!.statuses, {'bus': ItemStatus.option});
      expect(ofType(applyFix(items, c), ConflictType.transportsOverlap), isEmpty);
    });

    test('a booked one is kept; both booked has no fix', () {
      final one = [
        ride('ice', at(1, 8 * 60), at(1, 12 * 60)),
        ride('bus', at(1, 9 * 60), at(1, 10 * 60), status: ItemStatus.booked),
      ];
      final c = ofType(one, ConflictType.transportsOverlap).single;
      expect(c.amount, 60, reason: 'the shorter ride lies inside the longer one');
      expect(c.fix!.statuses, {'ice': ItemStatus.option});

      final both = [
        ride('ice', at(1, 8 * 60), at(1, 12 * 60), status: ItemStatus.booked),
        ride('bus', at(1, 9 * 60), at(1, 10 * 60), status: ItemStatus.booked),
      ];
      final d = ofType(both, ConflictType.transportsOverlap).single;
      expect(d.fix, isNull);
      expect(d.noFix, NoFixReason.bothBooked);
    });

    test('connections and options are fine', () {
      final items = [
        ride('ice', at(1, 8 * 60), at(1, 12 * 60)),
        ride('bus', at(1, 12 * 60), at(1, 15 * 60)),
        ride('alt', at(1, 9 * 60), at(1, 13 * 60), status: ItemStatus.option),
      ];
      expect(ofType(items, ConflictType.transportsOverlap), isEmpty);
    });
  });

  group('reasons for missing fixes on the older rules', () {
    test('a fixed stay that overlaps names itself', () {
      final items = [stay('paris', 0, 3), stay('lyon', 2, 2).copyWith(fixed: true)];
      final c = findConflicts(items).single;
      expect(c.fix, isNull);
      expect(c.noFix, NoFixReason.fixed);
      expect(c.noFixSubject, 'lyon');
    });
  });

  group('demotedBy (manual status change)', () {
    test('a planned accommodation demotes planned competitors only', () {
      final items = [
        stay('paris', 0, 4),
        bed('chosen', 0, 3, ItemStatus.planned),
        bed('planned', 1, 2, ItemStatus.planned),
        bed('booked', 2, 3, ItemStatus.booked),
        bed('idea', 0, 1, ItemStatus.idea),
        bed('later', 3, 4, ItemStatus.planned),
      ];
      final chosen = items[1];
      expect({for (final o in demotedBy(items, chosen)) o.id: o.status}, {'planned': ItemStatus.option});
    });

    test('options, ideas and other kinds demote nothing', () {
      final items = [stay('paris', 0, 4), bed('a', 0, 2, ItemStatus.planned)];
      expect(demotedBy(items, bed('b', 0, 2, ItemStatus.option)), isEmpty);
      expect(demotedBy(items, bed('b', 0, 2, ItemStatus.idea)), isEmpty);
      expect(demotedBy(items, ride('r', at(0, 600), at(0, 700))), isEmpty);
    });

    test('chooseOption still demotes when the chosen one was an option', () {
      final items = [stay('paris', 0, 2), bed('a', 0, 2, ItemStatus.option), bed('b', 0, 2, ItemStatus.planned)];
      expect({for (final i in chooseOption(items, 'a')) i.id: i.status},
          {'a': ItemStatus.planned, 'b': ItemStatus.option});
    });
  });

  test('the demo trips stay free of conflicts', () {
    for (final d in [demoInterrail(), demoSriLanka()]) {
      expect(findConflicts(d.items, zones: TripZones.of(d.trip, d.items)), isEmpty, reason: d.trip.title);
    }
  });
}
