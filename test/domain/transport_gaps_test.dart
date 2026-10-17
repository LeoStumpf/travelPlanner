import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/domain/analysis.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/domain/time.dart';

final _t0 = DateTime(2026, 1, 1);

PlanItem stay(String id, int firstDay, int nights, {ItemStatus status = ItemStatus.planned}) => PlanItem(
      id: id,
      tripId: 't',
      kind: ItemKind.stay,
      title: id,
      status: status,
      start: at(firstDay, defaultStayArrival),
      end: at(firstDay + nights, defaultStayDeparture),
      createdAt: _t0,
    );

PlanItem ride(String id, String? from, String? to, {ItemStatus status = ItemStatus.planned, bool dated = true}) =>
    PlanItem(
      id: id,
      tripId: 't',
      kind: ItemKind.transport,
      title: id,
      status: status,
      fromId: from,
      toId: to,
      start: dated ? at(2, 11 * 60) : null,
      end: dated ? at(2, 13 * 60) : null,
      createdAt: _t0,
    );

List<(String, String)> pairs(List<TransportGap> gaps) => [for (final g in gaps) (g.from.id, g.to.id)];

void main() {
  group('missingTransports', () {
    test('finds consecutive stays without a transport between them', () {
      final items = [stay('c', 6, 2), stay('a', 0, 2), stay('b', 2, 3), ride('ab', 'a', 'b')];
      expect(pairs(missingTransports(items)), [('b', 'c')]);
    });

    test('nothing to connect with fewer than two stays', () {
      expect(missingTransports([]), isEmpty);
      expect(missingTransports([stay('a', 0, 2)]), isEmpty);
    });

    test('a transport the other way round or to another stay does not count', () {
      final items = [stay('a', 0, 2), stay('b', 2, 2), stay('c', 4, 2), ride('ba', 'b', 'a'), ride('ac', 'a', 'c')];
      expect(pairs(missingTransports(items)), [('a', 'b'), ('b', 'c')]);
    });

    test('a half-linked transport does not close the gap', () {
      final items = [stay('a', 0, 2), stay('b', 2, 2), ride('out', 'a', null), ride('in', null, 'b')];
      expect(pairs(missingTransports(items)), [('a', 'b')]);
    });

    test('options and undated transports count as planned legs', () {
      final items = [
        stay('a', 0, 2),
        stay('b', 2, 2),
        stay('c', 4, 2),
        ride('ab', 'a', 'b', status: ItemStatus.option),
        ride('bc', 'b', 'c', dated: false),
      ];
      expect(missingTransports(items), isEmpty);
    });

    test('stay options and unscheduled stays are skipped in the chain', () {
      final items = [
        stay('a', 0, 2),
        stay('maybe', 2, 1, status: ItemStatus.option),
        stay('later', 0, 1).copyWith(start: null, end: null),
        stay('b', 3, 2),
      ];
      expect(pairs(missingTransports(items)), [('a', 'b')]);
    });
  });

  group('suggestTransportTimes', () {
    test('leaves when the previous stay ends and takes three hours', () {
      final a = stay('a', 0, 2), b = stay('b', 4, 2);
      expect(suggestTransportTimes(a, b), (a.end!, a.end! + defaultTransportMinutes));
      expect(missingTransports([a, b]).single.suggestedTimes, (a.end!, a.end! + defaultTransportMinutes));
    });

    test('arrives no later than the next stay begins', () {
      final a = stay('a', 0, 2); // ends day 2 10:00
      final b = stay('b', 2, 2).copyWith(start: at(2, 11 * 60));
      expect(suggestTransportTimes(a, b), (a.end!, at(2, 11 * 60)));
    });

    test('ignores a next stay that begins before departure', () {
      final a = stay('a', 0, 2);
      final b = stay('b', 1, 2);
      expect(suggestTransportTimes(a, b), (a.end!, a.end! + defaultTransportMinutes));
    });

    test('with only the destination it arrives as that stay begins', () {
      final b = stay('b', 3, 2);
      expect(suggestTransportTimes(null, b), (b.start! - defaultTransportMinutes, b.start!));
    });

    test('null without dates on either end', () {
      final undated = stay('u', 0, 1).copyWith(start: null, end: null);
      expect(suggestTransportTimes(null, null), isNull);
      expect(suggestTransportTimes(undated, undated), isNull);
    });
  });

  group('neighbourStays', () {
    final items = [stay('b', 2, 2), stay('a', 0, 2), stay('c', 4, 2), stay('opt', 6, 1, status: ItemStatus.option)];

    test('returns the stays before and after in the chain', () {
      final (prev, next) = neighbourStays(items, 'b');
      expect((prev?.id, next?.id), ('a', 'c'));
    });

    test('null at the ends and for stays outside the chain', () {
      expect(neighbourStays(items, 'a').$1, isNull);
      expect(neighbourStays(items, 'c').$2, isNull);
      expect(neighbourStays(items, 'opt'), (null, null));
    });
  });
}
