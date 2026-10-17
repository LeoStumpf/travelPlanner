import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/domain/analysis.dart';
import 'package:travel_planner/domain/demo.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/domain/scheduler.dart';
import 'package:travel_planner/domain/time.dart';
import 'package:travel_planner/domain/timeline.dart';

PlanItem item(String id, ItemKind kind, {int? start, int? end, String? parentId, String? fromId, String? toId}) =>
    PlanItem(
      id: id,
      tripId: 't',
      kind: kind,
      title: id,
      start: start,
      end: end,
      parentId: parentId,
      fromId: fromId,
      toId: toId,
      createdAt: DateTime(2026),
    );

void main() {
  group('labelRoom', () {
    test('measures up to the next block in the same row only', () {
      final a = item('a', ItemKind.activity, start: at(0, 600), end: at(0, 700));
      final b = item('b', ItemKind.activity, start: at(0, 900), end: at(0, 1000));
      final c = item('c', ItemKind.activity, start: at(0, 650), end: at(0, 800)); // overlaps a → row 1
      final (rows, count) = packLanes([a, b, c]);
      expect(count, 2);
      final room = labelRoom([a, b, c], rows);
      expect(room['a'], 300);
      expect(room['b'], isNull);
      expect(room['c'], isNull);
    });

    test('ignores unscheduled items', () {
      final a = item('a', ItemKind.activity, start: 0, end: 60);
      final u = item('u', ItemKind.activity);
      expect(labelRoom([a, u], {'a': 0}), {'a': null});
    });
  });

  group('suggestedDay', () {
    test('a place goes into the first free days between places', () {
      final d = demoInterrail();
      final avignon = d.items.firstWhere((i) => i.title == 'Avignon');
      expect(suggestedDay(avignon, d.items, plannedDays: d.trip.plannedDays), 6);
    });

    test('a place without gaps goes after the last one; on an empty trip day 0', () {
      final s1 = item('s1', ItemKind.stay, start: at(0, defaultStayArrival), end: at(2, defaultStayDeparture));
      final s2 = item('s2', ItemKind.stay);
      expect(suggestedDay(s2, [s1, s2]), 2);
      expect(suggestedDay(s2, [s2]), 0);
    });

    test('lodging on the arrival day, activities on the first full day', () {
      final s = item('s', ItemKind.stay, start: at(3, defaultStayArrival), end: at(6, defaultStayDeparture));
      final short = item('short', ItemKind.stay, start: at(8, 600), end: at(8, 1200));
      expect(suggestedDay(item('h', ItemKind.accommodation, parentId: 's'), [s]), 3);
      expect(suggestedDay(item('x', ItemKind.activity, parentId: 's'), [s]), 4);
      expect(suggestedDay(item('y', ItemKind.activity, parentId: 'short'), [short]), 8);
      expect(suggestedDay(item('z', ItemKind.activity), [s]), 0);
    });

    test('a transport leaves on its origin\'s last day, else arrives on its destination\'s first', () {
      final a = item('a', ItemKind.stay, start: at(0, defaultStayArrival), end: at(2, defaultStayDeparture));
      final b = item('b', ItemKind.stay, start: at(5, defaultStayArrival), end: at(7, defaultStayDeparture));
      expect(suggestedDay(item('t', ItemKind.transport, fromId: 'a', toId: 'b'), [a, b]), 2);
      expect(suggestedDay(item('t', ItemKind.transport, toId: 'b'), [a, b]), 5);
    });
  });

  group('defaultSlotOn', () {
    final s = item('s', ItemKind.stay, start: at(3, defaultStayArrival), end: at(6, defaultStayDeparture));

    test('places get two nights, fewer when the next place starts sooner', () {
      final p = item('p', ItemKind.stay);
      expect(defaultSlotOn(p, 0, [s, p]), (at(0, defaultStayArrival), at(2, defaultStayDeparture)));
      expect(defaultSlotOn(p, 2, [s, p]), (at(2, defaultStayArrival), at(3, defaultStayDeparture)));
      expect(defaultSlotOn(p, 10, [s, p]), (at(10, defaultStayArrival), at(12, defaultStayDeparture)));
    });

    test('lodging runs until its place ends, at least one night', () {
      final h = item('h', ItemKind.accommodation, parentId: 's');
      expect(defaultSlotOn(h, 3, [s, h]), (at(3, defaultCheckIn), at(6, defaultCheckOut)));
      expect(defaultSlotOn(h, 6, [s, h]), (at(6, defaultCheckIn), at(7, defaultCheckOut)));
      expect(defaultSlotOn(item('o', ItemKind.accommodation), 1, [s]), (at(1, defaultCheckIn), at(2, defaultCheckOut)));
    });

    test('activities 10:00–12:00', () {
      expect(defaultSlotOn(item('x', ItemKind.activity), 4, [s]), (at(4, 600), at(4, 720)));
    });

    test('transports leave their origin when it ends that day, else 10:00–13:00', () {
      final b = item('b', ItemKind.stay, start: at(6, defaultStayArrival), end: at(8, defaultStayDeparture));
      final t = item('t', ItemKind.transport, fromId: 's', toId: 'b');
      expect(defaultSlotOn(t, 6, [s, b, t]), (at(6, defaultStayDeparture), at(6, defaultStayDeparture + 180)));
      expect(defaultSlotOn(t, 4, [s, b, t]), (at(4, 600), at(4, 780)));
    });
  });

  group('scheduleOn', () {
    test('places an unscheduled place into a gap without moving others', () {
      final d = demoInterrail();
      final avignon = d.items.firstWhere((i) => i.title == 'Avignon');
      final r = scheduleOn(d.items, avignon.id, 6, ShiftMode.following);
      expect(r.changedIds, {avignon.id});
      final placed = r.items.firstWhere((i) => i.id == avignon.id);
      expect(placed.start, at(6, defaultStayArrival));
      expect(placed.end, at(8, defaultStayDeparture));
      expect(findConflicts(r.items).where((c) => c.involves(avignon.id)), isEmpty);
    });

    test('makes room according to the shift mode', () {
      final a = item('a', ItemKind.stay, start: at(0, defaultStayArrival), end: at(2, defaultStayDeparture));
      final b = item('b', ItemKind.stay, start: at(2, defaultStayArrival), end: at(4, defaultStayDeparture));
      final p = item('p', ItemKind.stay);
      // On day 1: the slot is capped at the next start (b on day 2).
      final r = scheduleOn([a, b, p], 'p', 1, ShiftMode.push);
      final placed = r.items.firstWhere((i) => i.id == 'p');
      expect(placed.start, at(1, defaultStayArrival));
      expect(placed.end, at(2, defaultStayDeparture));
      final single = scheduleOn([a, b, p], 'p', 1, ShiftMode.single);
      expect(single.changedIds, {'p'});
    });

    test('unknown ids change nothing', () {
      final a = item('a', ItemKind.activity);
      expect(scheduleOn([a], 'nope', 0, ShiftMode.single).changedIds, isEmpty);
    });
  });
}
