import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/domain/analysis.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/domain/time.dart';

final _t0 = DateTime(2026, 1, 1);

PlanItem stay(String id, int firstDay, int nights) => PlanItem(
      id: id,
      tripId: 't',
      kind: ItemKind.stay,
      title: id,
      start: at(firstDay, defaultStayArrival),
      end: at(firstDay + nights, defaultStayDeparture),
      createdAt: _t0,
    );

PlanItem bed(String id, String parent, int day, int endDay, ItemStatus status) => PlanItem(
      id: id,
      tripId: 't',
      kind: ItemKind.accommodation,
      title: id,
      parentId: parent,
      status: status,
      start: at(day, defaultCheckIn),
      end: at(endDay, defaultCheckOut),
      createdAt: _t0,
    );

Map<String, ItemStatus> statuses(List<PlanItem> changed) => {for (final i in changed) i.id: i.status};

void main() {
  group('optionsForNight', () {
    test('lists scheduled options covering the night, earliest first', () {
      final items = [
        stay('lyon', 0, 4),
        bed('b', 'lyon', 1, 3, ItemStatus.option),
        bed('a', 'lyon', 0, 2, ItemStatus.option),
        bed('planned', 'lyon', 3, 4, ItemStatus.planned),
        bed('undated', 'lyon', 0, 1, ItemStatus.option).copyWith(start: null, end: null),
      ];
      expect([for (final o in optionsForNight(items, 1)) o.id], ['a', 'b']);
      expect([for (final o in optionsForNight(items, 2)) o.id], ['b']);
      expect(optionsForNight(items, 3), isEmpty);
    });
  });

  group('chooseOption', () {
    test('chosen option becomes planned and covers its nights', () {
      final items = [stay('lyon', 0, 2), bed('a', 'lyon', 0, 2, ItemStatus.option), bed('b', 'lyon', 0, 2, ItemStatus.option)];
      final changed = chooseOption(items, 'a');
      expect(statuses(changed), {'a': ItemStatus.planned});
      final after = [for (final i in items) changed.where((c) => c.id == i.id).firstOrNull ?? i];
      expect(uncoveredNights(after), isEmpty);
    });

    test('a planned accommodation sharing a night falls back to option', () {
      final items = [
        stay('lyon', 0, 4),
        bed('a', 'lyon', 0, 2, ItemStatus.option),
        bed('old', 'lyon', 1, 3, ItemStatus.planned),
        bed('later', 'lyon', 2, 4, ItemStatus.planned), // consecutive, no shared night
        bed('booked', 'lyon', 0, 1, ItemStatus.booked),
        bed('idea', 'lyon', 0, 2, ItemStatus.idea),
      ];
      expect(statuses(chooseOption(items, 'a')), {'a': ItemStatus.planned, 'old': ItemStatus.option});
    });

    test('undated accommodations compete within the same stay only', () {
      final items = [
        stay('lyon', 0, 2),
        stay('bcn', 3, 2),
        bed('a', 'lyon', 0, 2, ItemStatus.option).copyWith(start: null, end: null),
        bed('x', 'lyon', 0, 2, ItemStatus.planned),
        bed('y', 'bcn', 3, 5, ItemStatus.planned),
      ];
      expect(statuses(chooseOption(items, 'a')), {'a': ItemStatus.planned, 'x': ItemStatus.option});
    });

    test('booking marks it booked and also replaces planned competitors', () {
      final items = [stay('lyon', 0, 2), bed('a', 'lyon', 0, 2, ItemStatus.option), bed('x', 'lyon', 0, 2, ItemStatus.planned)];
      expect(statuses(chooseOption(items, 'a', book: true)), {'a': ItemStatus.booked, 'x': ItemStatus.option});
      // Booking an already planned one only changes its status.
      expect(statuses(chooseOption(items, 'x', book: true)), {'x': ItemStatus.booked});
    });

    test('choosing a booked one keeps it booked; unknown id changes nothing', () {
      final items = [stay('lyon', 0, 2), bed('a', 'lyon', 0, 2, ItemStatus.booked)];
      expect(chooseOption(items, 'a'), isEmpty);
      expect(chooseOption(items, 'nope'), isEmpty);
    });
  });
}
