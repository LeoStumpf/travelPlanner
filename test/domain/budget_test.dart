import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/domain/budget.dart';
import 'package:travel_planner/domain/models.dart';

final _now = DateTime(2026, 10, 17);

PlanItem _item(String id, ItemKind kind, Cost? cost, {ItemStatus status = ItemStatus.planned, int? start}) => PlanItem(
      id: id,
      tripId: 't',
      kind: kind,
      title: id,
      status: status,
      start: start,
      end: start == null ? null : start + 60,
      cost: cost,
      createdAt: _now,
    );

TripData _data(List<PlanItem> items, {String? currency = 'EUR', int travellers = 2, Map<String, double> rates = const {}}) =>
    TripData(
      trip: Trip(id: 't', title: 'T', currency: currency, travellers: travellers, rates: rates, createdAt: _now),
      items: items,
    );

void main() {
  group('input parsing', () {
    test('currency codes and symbols', () {
      expect(normalizeCurrency(' eur '), 'EUR');
      expect(normalizeCurrency('€'), 'EUR');
      expect(normalizeCurrency(r'$'), 'USD');
      expect(normalizeCurrency('LKR'), 'LKR');
      expect(normalizeCurrency(''), isNull);
      expect(normalizeCurrency(null), isNull);
      expect(normalizeCurrency('EURO'), isNull);
      expect(normalizeCurrency('E1R'), isNull);
    });

    test('amounts the way people type them', () {
      expect(parseAmount('12'), 12);
      expect(parseAmount('12.50'), 12.5);
      expect(parseAmount('12,50'), 12.5);
      expect(parseAmount('1.234,50'), 1234.5);
      expect(parseAmount('1,234.50'), 1234.5);
      expect(parseAmount('1 234'), 1234);
      expect(parseAmount('1.234.567'), 1234567);
      expect(parseAmount('1,234,567'), 1234567);
      expect(parseAmount(' 28000 '), 28000);
      expect(parseAmount(''), isNull);
      expect(parseAmount('abc'), isNull);
      expect(parseAmount('-5'), isNull);
      expect(parseAmount('12,'), isNull);
    });
  });

  group('model', () {
    test('cost, currency, travellers and rates survive JSON', () {
      final trip = Trip(
          id: 't', title: 'T', currency: 'EUR', travellers: 3, rates: const {'LKR': 330, 'USD': 1.08}, createdAt: _now);
      final back = Trip.fromJson(jsonDecode(jsonEncode(trip.toJson())) as Map<String, Object?>);
      expect([back.currency, back.travellers, back.rates], ['EUR', 3, {'LKR': 330.0, 'USD': 1.08}]);

      const cost = Cost(amount: 12.5, currency: 'LKR', perPerson: true, paid: true);
      final item = _item('a', ItemKind.activity, cost);
      final again = PlanItem.fromJson(jsonDecode(jsonEncode(item.toJson())) as Map<String, Object?>);
      expect(again.cost, cost);
    });

    test('old JSON without the new fields reads with defaults', () {
      final trip = Trip.fromJson({'id': 't', 'title': 'T', 'createdAt': _now.toIso8601String()});
      expect([trip.currency, trip.travellers, trip.rates], [null, 1, isEmpty]);
      final json = _item('a', ItemKind.stay, null).toJson();
      expect(json.containsKey('cost'), isFalse);
      expect(Trip(id: 't', title: 'T', createdAt: _now).toJson().keys, isNot(contains('rates')));
      expect(PlanItem.fromJson(json).cost, isNull);
      // A broken cost is dropped instead of failing the whole row.
      expect(PlanItem.fromJson({...json, 'cost': {'currency': 'EUR'}}).cost, isNull);
    });

    test('copyWith keeps and clears the cost', () {
      final i = _item('a', ItemKind.activity, const Cost(amount: 5));
      expect(i.copyWith(title: 'x').cost, const Cost(amount: 5));
      expect(i.copyWith(cost: null).cost, isNull);
      expect(setPaid(i, true).cost!.paid, isTrue);
      expect(setPaid(_item('b', ItemKind.activity, null), true).cost, isNull);
    });
  });

  group('budget', () {
    test('per-person costs count once per traveller', () {
      expect(costTotal(const Cost(amount: 10, perPerson: true), 3), 30);
      expect(costTotal(const Cost(amount: 10), 3), 10);
      expect(costTotal(const Cost(amount: 10, perPerson: true), 0), 10);
    });

    test('sums per layer, paid vs open, in the home currency', () {
      final b = budgetOf(_data([
        _item('flight', ItemKind.transport, const Cost(amount: 600, perPerson: true, paid: true), start: 0),
        _item('hotel', ItemKind.accommodation, const Cost(amount: 33000, currency: 'LKR'), start: 100),
        _item('temple', ItemKind.activity, const Cost(amount: 10, currency: 'EUR', perPerson: true), start: 200),
        _item('safari', ItemKind.activity, const Cost(amount: 50, paid: true)),
        _item('free', ItemKind.activity, null),
      ], rates: {'LKR': 330}));
      expect(b.currency, 'EUR');
      expect(b.layers[ItemKind.transport]!.paid, 1200);
      expect(b.layers[ItemKind.accommodation]!.open, closeTo(100, 1e-9));
      expect(b.layers[ItemKind.activity]!.total, 70);
      expect(b.layers[ItemKind.activity]!.paid, 50);
      expect(b.layers[ItemKind.stay]!.isEmpty, isTrue);
      expect(b.total.paid, 1250);
      expect(b.total.open, closeTo(120, 1e-9));
      expect(b.total.paidShare, closeTo(1250 / 1370, 1e-9));
      expect(b.perPerson, closeTo(685, 1e-9));
      expect(b.missingRates, isEmpty);
      expect(b.foreignCurrencies, ['LKR']);
      // Chronological, unscheduled last.
      expect(b.entries.map((e) => e.item.id), ['flight', 'hotel', 'temple', 'safari']);
      expect(b.entries[1].total, 33000);
      expect(b.entries[1].converted, closeTo(100, 1e-9));
    });

    test('options and ideas are summed apart', () {
      final b = budgetOf(_data([
        _item('a', ItemKind.accommodation, const Cost(amount: 80), status: ItemStatus.option),
        _item('b', ItemKind.accommodation, const Cost(amount: 120), status: ItemStatus.booked),
        _item('c', ItemKind.activity, const Cost(amount: 30), status: ItemStatus.idea),
      ]));
      expect(b.total.total, 120);
      expect(b.notCounted.total, 110);
      expect(b.notCounted.count, 2);
      expect(b.entries.where((e) => !e.counted).map((e) => e.item.id), ['a', 'c']);
    });

    test('amounts without a rate are reported, not guessed', () {
      final b = budgetOf(_data([
        _item('a', ItemKind.activity, const Cost(amount: 3000, currency: 'LKR')),
        _item('b', ItemKind.activity, const Cost(amount: 20, currency: 'USD', perPerson: true)),
        _item('c', ItemKind.activity, const Cost(amount: 5)),
      ], rates: {'USD': 1.25}));
      expect(b.missingRates, ['LKR']);
      expect(b.total.total, closeTo(37, 1e-9));
      expect(b.total.unconverted, {'LKR': 3000});
      expect(b.entries.first.converted, isNull);
    });

    test('without a home currency the most used one is shown', () {
      final items = [
        _item('a', ItemKind.activity, const Cost(amount: 1, currency: 'LKR')),
        _item('b', ItemKind.activity, const Cost(amount: 1, currency: 'LKR')),
        _item('c', ItemKind.activity, const Cost(amount: 1, currency: 'EUR')),
        _item('d', ItemKind.activity, const Cost(amount: 1)),
      ];
      final d = _data(items, currency: null);
      expect(budgetCurrency(d.trip, d.items), 'LKR');
      final b = budgetOf(d);
      expect(b.currency, 'LKR');
      expect(b.missingRates, ['EUR']);
      expect(b.total.total, 3);
      expect(budgetCurrency(_data(const [], currency: null).trip, const []), isNull);
      // Nothing known at all: plain numbers.
      expect(budgetOf(_data([_item('x', ItemKind.activity, const Cost(amount: 9))], currency: null)).total.total, 9);
    });

    test('rates are set and removed', () {
      final t = _data(const []).trip;
      final withRate = setRate(t, 'LKR', 330);
      expect(withRate.rates, {'LKR': 330});
      expect(setRate(withRate, 'LKR', null).rates, isEmpty);
      expect(setRate(withRate, 'LKR', 0).rates, isEmpty);
      expect(convertAmount(660, 'LKR', 'EUR', withRate.rates), 2);
      expect(convertAmount(5, null, 'EUR', const {}), 5);
      expect(convertAmount(5, 'EUR', 'EUR', const {}), 5);
      expect(convertAmount(5, 'USD', 'EUR', const {}), isNull);
    });
  });
}
