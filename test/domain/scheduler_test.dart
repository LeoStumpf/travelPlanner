import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/domain/analysis.dart';
import 'package:travel_planner/domain/demo.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/domain/scheduler.dart';
import 'package:travel_planner/domain/time.dart';

final _t0 = DateTime(2026, 1, 1);

PlanItem stay(String id, int firstDay, int nights, {bool fixed = false, ItemStatus status = ItemStatus.planned}) =>
    PlanItem(
      id: id,
      tripId: 't',
      kind: ItemKind.stay,
      title: id,
      start: at(firstDay, defaultStayArrival),
      end: at(firstDay + nights, defaultStayDeparture),
      fixed: fixed,
      status: status,
      createdAt: _t0,
    );

PlanItem child(String id, ItemKind kind, String parent, int day, int endDay, {bool fixed = false}) => PlanItem(
      id: id,
      tripId: 't',
      kind: kind,
      title: id,
      parentId: parent,
      start: at(day, defaultCheckIn),
      end: at(endDay, defaultCheckOut),
      fixed: fixed,
      createdAt: _t0,
    );

PlanItem flight(String id, String fromId, int day, {bool fixed = true}) => PlanItem(
      id: id,
      tripId: 't',
      kind: ItemKind.transport,
      title: id,
      fromId: fromId,
      start: at(day, 16 * 60),
      end: at(day, 20 * 60),
      fixed: fixed,
      createdAt: _t0,
    );

Map<String, PlanItem> byId(ScheduleResult r) => {for (final i in r.items) i.id: i};

void main() {
  // Paris d0-3, Lyon d3-5, (free d6-d7), Barcelona d8-11
  List<PlanItem> trip() => [stay('paris', 0, 3), stay('lyon', 3, 2), stay('bcn', 8, 3)];

  group('move', () {
    test('following: everything after moves by the same amount', () {
      final r = Scheduler.move(trip(), 'lyon', minutesPerDay, ShiftMode.following);
      final m = byId(r);
      expect(dayOf(m['paris']!.start!), 0);
      expect(dayOf(m['lyon']!.start!), 4);
      expect(dayOf(m['bcn']!.start!), 9);
      expect(r.changedIds, {'lyon', 'bcn'});
    });

    test('following: moving earlier pulls later items too', () {
      final r = Scheduler.move(trip(), 'lyon', -minutesPerDay, ShiftMode.following);
      expect(dayOf(byId(r)['bcn']!.start!), 7);
    });

    test('push: free days absorb the shift', () {
      final r = Scheduler.move(trip(), 'lyon', 2 * minutesPerDay, ShiftMode.push);
      final m = byId(r);
      expect(dayOf(m['lyon']!.start!), 5);
      expect(dayOf(m['bcn']!.start!), 8, reason: 'Lyon now ends day 7, Barcelona starts day 8');
      expect(r.changedIds, {'lyon'});
    });

    test('push: once the buffer is used up, later items are pushed by whole days', () {
      final r = Scheduler.move(trip(), 'lyon', 4 * minutesPerDay, ShiftMode.push);
      final m = byId(r);
      expect(dayOf(m['lyon']!.end!), 9);
      expect(dayOf(m['bcn']!.start!), 9);
      expect(minuteOfDay(m['bcn']!.start!), defaultStayArrival, reason: 'time of day is kept');
      expect(findConflicts(r.items), isEmpty);
    });

    test('single: only the item moves, conflicts are reported', () {
      final r = Scheduler.move(trip(), 'paris', minutesPerDay, ShiftMode.single);
      expect(r.changedIds, {'paris'});
      final c = findConflicts(r.items);
      expect(c, hasLength(1));
      expect(c.single.involves('lyon'), isTrue);
    });

    test('fixed items do not move and produce a conflict', () {
      final items = [stay('a', 0, 3), stay('tour', 3, 1, fixed: true), stay('b', 4, 2)];
      final r = Scheduler.move(items, 'a', minutesPerDay, ShiftMode.following);
      final m = byId(r);
      expect(m['tour']!.start, items[1].start);
      expect(dayOf(m['b']!.start!), 5);
      expect(findConflicts(r.items).any((c) => c.involves('tour')), isTrue);
    });

    test('push stops at a fixed wall but still pushes items behind it when overlapping', () {
      final items = [stay('a', 0, 2), stay('fixed', 3, 1, fixed: true), stay('b', 4, 2)];
      final r = Scheduler.move(items, 'a', 3 * minutesPerDay, ShiftMode.push);
      final m = byId(r);
      expect(m['fixed']!.start, items[1].start);
      expect(dayOf(m['b']!.start!), 5, reason: 'a now ends day 5 10:00, overlapping b');
    });

    test('children move with their stay, fixed children stay', () {
      final items = [
        stay('kandy', 2, 3),
        child('hotel', ItemKind.accommodation, 'kandy', 2, 5),
        PlanItem(
          id: 'tour',
          tripId: 't',
          kind: ItemKind.activity,
          title: 'tour',
          parentId: 'kandy',
          start: at(3, 9 * 60),
          end: at(3, 17 * 60),
          fixed: true,
          createdAt: _t0,
        ),
      ];
      final r = Scheduler.move(items, 'kandy', minutesPerDay, ShiftMode.single);
      final m = byId(r);
      expect(dayOf(m['hotel']!.start!), 3);
      expect(m['tour']!.start, items[2].start);
      expect(findConflicts(r.items).any((c) => c.itemId == 'tour'), isTrue);
    });

    test('transport travels with its destination stay', () {
      final train = PlanItem(
        id: 'train',
        tripId: 't',
        kind: ItemKind.transport,
        title: 'TGV',
        fromId: 'paris',
        toId: 'lyon',
        start: at(3, 11 * 60),
        end: at(3, 13 * 60),
        createdAt: _t0,
      );
      final r = Scheduler.move([...trip(), train], 'lyon', minutesPerDay, ShiftMode.following);
      expect(dayOf(byId(r)['train']!.start!), 4);
    });

    test('options and unscheduled items are not rippled', () {
      final items = [...trip(), stay('maybe', 6, 1, status: ItemStatus.option)];
      final r = Scheduler.move(items, 'paris', minutesPerDay, ShiftMode.following);
      expect(byId(r)['maybe']!.start, items.last.start);
    });

    test('moving a child does not ripple', () {
      final items = [...trip(), child('museum', ItemKind.activity, 'paris', 1, 2)];
      final r = Scheduler.move(items, 'museum', minutesPerDay, ShiftMode.following);
      expect(r.changedIds, {'museum'});
    });
  });

  group('resizeEnd', () {
    test('extending a stay by a day moves everything after it', () {
      final r = Scheduler.resizeEnd(trip(), 'paris', minutesPerDay, ShiftMode.following);
      final m = byId(r);
      expect(dayOf(m['paris']!.end!), 4);
      expect(dayOf(m['lyon']!.start!), 4);
      expect(dayOf(m['bcn']!.start!), 9);
    });

    test('extending with push only moves overlapping items', () {
      final r = Scheduler.resizeEnd(trip(), 'paris', minutesPerDay, ShiftMode.push);
      final m = byId(r);
      expect(dayOf(m['lyon']!.start!), 4);
      expect(dayOf(m['bcn']!.start!), 8);
    });

    test('a stay can not become shorter than an hour', () {
      final r = Scheduler.resizeEnd(trip(), 'lyon', -100 * minutesPerDay, ShiftMode.single);
      final l = byId(r)['lyon']!;
      expect(l.end! - l.start!, 60);
    });

    test('flight home stays fixed, conflict when the last stay overruns it', () {
      final items = [...trip(), flight('home', 'bcn', 11)];
      final r = Scheduler.resizeEnd(items, 'bcn', minutesPerDay, ShiftMode.following);
      expect(byId(r)['home']!.start, items.last.start);
      expect(findConflicts(r.items).single.itemId, 'home');
    });
  });

  group('resizeStart', () {
    test('arriving a day earlier only changes the item', () {
      final r = Scheduler.resizeStart(trip(), 'lyon', -minutesPerDay);
      expect(r.changedIds, {'lyon'});
      expect(dayOf(byId(r)['lyon']!.start!), 2);
      expect(findConflicts(r.items), hasLength(1), reason: 'now overlaps Paris');
    });

    test('start can not pass the end', () {
      final r = Scheduler.resizeStart(trip(), 'lyon', 10 * minutesPerDay);
      final l = byId(r)['lyon']!;
      expect(l.end! - l.start!, 60);
    });
  });

  group('insert / reschedule', () {
    test('insert with push makes room', () {
      final r = Scheduler.insert(trip(), stay('dijon', 3, 2), ShiftMode.push);
      final m = byId(r);
      expect(dayOf(m['lyon']!.start!), 5);
      expect(dayOf(m['bcn']!.start!), 8);
      expect(r.changedIds, containsAll(['dijon', 'lyon']));
    });

    test('insert with following moves all later items', () {
      final r = Scheduler.insert(trip(), stay('dijon', 3, 2), ShiftMode.following);
      final m = byId(r);
      expect(dayOf(m['lyon']!.start!), 5);
      expect(dayOf(m['bcn']!.start!), 10);
    });

    test('reschedule combines start and end change', () {
      final p = trip().first;
      final r = Scheduler.reschedule(trip(), 'paris', p.start! + minutesPerDay, p.end! + 2 * minutesPerDay, ShiftMode.following);
      final m = byId(r);
      expect(dayOf(m['paris']!.end!), 5);
      expect(dayOf(m['lyon']!.start!), 5);
    });
  });

  group('analysis', () {
    test('gaps between stays', () {
      expect(findGaps(trip()), [const DayGap(6, 7, 'lyon')]);
      expect(findGaps(trip(), plannedDays: 14), [const DayGap(6, 7, 'lyon'), const DayGap(12, 13, 'bcn')]);
    });

    test('nights and days of a stay', () {
      final p = trip().first;
      expect(nightsIn(p.start!, p.end!), 3);
      expect(daysTouched(p.start!, p.end!), 4);
    });

    test('uncovered nights', () {
      final items = [stay('kandy', 0, 3), child('hotel', ItemKind.accommodation, 'kandy', 0, 2)];
      expect(uncoveredNights(items), [2]);
    });

    test('accommodation option does not cover nights', () {
      final items = [
        stay('kandy', 0, 1),
        child('h', ItemKind.accommodation, 'kandy', 0, 1).copyWith(status: ItemStatus.option),
      ];
      expect(uncoveredNights(items), [0]);
    });

    test('lane packing', () {
      final items = [stay('a', 0, 2), stay('b', 1, 2), stay('c', 3, 1)];
      final (rows, count) = packLanes(items);
      expect(count, 2);
      expect(rows['a'], 0);
      expect(rows['b'], 1);
      expect(rows['c'], 0);
    });
  });

  group('conflict fixes', () {
    PlanItem tgv({int day = 3}) => PlanItem(
          id: 'tgv',
          tripId: 't',
          kind: ItemKind.transport,
          title: 'TGV',
          fromId: 'paris',
          toId: 'lyon',
          start: at(day, 11 * 60),
          end: at(day, 13 * 60),
          createdAt: _t0,
        );

    List<PlanItem> applyFix(List<PlanItem> items, Conflict c) {
      final changed = {for (final i in c.fix!.apply(items)) i.id: i};
      return [for (final i in items) changed[i.id] ?? i];
    }

    test('moving the destination later leaves a day without a place, fix extends the origin', () {
      final items = [...trip(), tgv()];
      final r = Scheduler.move(items, 'lyon', minutesPerDay, ShiftMode.following);
      final c = findConflicts(r.items).single;
      expect(c.itemId, 'tgv');
      expect(c.otherId, 'paris');
      expect(c.type, ConflictType.daysBeforeDeparture);
      expect(c.amount, 1);
      expect((c.itemTitle, c.otherTitle), ('TGV', 'paris'));
      expect(c.fix!.type, ConflictFixType.extendToDeparture);

      final fixed = applyFix(r.items, c);
      expect(findConflicts(fixed), isEmpty);
      final paris = fixed.firstWhere((i) => i.id == 'paris');
      expect(paris.end, at(4, 11 * 60), reason: 'Paris now lasts until the train leaves');
    });

    test('origin ending after departure is fixed by shortening it', () {
      final items = [...trip(), tgv()];
      final r = Scheduler.resizeEnd(items, 'paris', minutesPerDay, ShiftMode.single);
      final c = findConflicts(r.items).firstWhere((c) => c.otherId == 'paris' && c.itemId == 'tgv');
      expect(c.type, ConflictType.stayEndsAfterDeparture);
      expect(c.fix!.type, ConflictFixType.shortenToDeparture);
      expect(findConflicts(applyFix(r.items, c)).where((c) => c.itemId == 'tgv'), isEmpty);
    });

    test('destination starting days after arrival is fixed by starting it on arrival', () {
      final items = [...trip(), tgv(day: 2)];
      final c = findConflicts(items).firstWhere((c) => c.otherId == 'lyon');
      expect(c.type, ConflictType.daysAfterArrival);
      expect(c.fix!.type, ConflictFixType.startEarlierAtArrival);
      final fixed = applyFix(items, c);
      expect(fixed.firstWhere((i) => i.id == 'lyon').start, at(2, 13 * 60));
    });

    test('overlapping stays are fixed by pushing the later one', () {
      final r = Scheduler.move(trip(), 'paris', minutesPerDay, ShiftMode.single);
      final c = findConflicts(r.items).single;
      expect(findConflicts(applyFix(r.items, c)), isEmpty);
    });

    test('activity outside its stay is moved back inside', () {
      final items = [
        stay('kandy', 2, 3),
        PlanItem(
          id: 'temple',
          tripId: 't',
          kind: ItemKind.activity,
          title: 'Tempel',
          parentId: 'kandy',
          start: at(7, 9 * 60),
          end: at(7, 11 * 60),
          createdAt: _t0,
        ),
      ];
      final c = findConflicts(items).single;
      final t = applyFix(items, c).firstWhere((i) => i.id == 'temple');
      expect(dayOf(t.start!), 5);
      expect(t.end! - t.start!, 120);
      expect(findConflicts(applyFix(items, c)), isEmpty);
    });

    test('demo trips have no conflicts', () {
      expect(findConflicts(demoInterrail().items), isEmpty);
      expect(findConflicts(demoSriLanka().items), isEmpty);
    });
  });
}
