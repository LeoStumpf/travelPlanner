import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/domain/analysis.dart';
import 'package:travel_planner/domain/demo.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/domain/places.dart';
import 'package:travel_planner/domain/plan_exchange.dart';

var _n = 0;
String _id() => 'new${_n++}';

PlanImport _apply(Map<String, Object?> plan, TripData? into) =>
    PlanExchange.apply(PlanExchange.parse(jsonEncode({'format': planFormat, ...plan})),
        into: into, now: DateTime(2026), newId: _id);

PlanItem _item(String id, ItemKind kind, {String? place, double? lat, double? lng, String? parent}) => PlanItem(
      id: id,
      tripId: 't',
      kind: kind,
      title: id,
      placeName: place,
      lat: lat,
      lng: lng,
      parentId: parent,
      createdAt: DateTime(2026),
    );

void main() {
  final demo = demoInterrail();
  PlanItem byTitle(String t) => demo.items.firstWhere((i) => i.title == t);
  final paris = byTitle('Paris'), lyon = byTitle('Lyon'), louvre = byTitle('Louvre');
  final tgv = demo.items.firstWhere((i) => i.title.startsWith('TGV'));
  final note = demo.cards.firstWhere((c) => c.type == CardType.note);

  group('changes', () {
    test('lists new, changed (with fields) and deleted entries by title', () {
      final imp = _apply({
        'items': [
          {'ref': 'nice', 'kind': 'stay', 'title': 'Nizza', 'lat': 43.7, 'lng': 7.27},
          {'ref': louvre.id, 'start': {'day': 2, 'time': '09:00'}, 'end': {'day': 2, 'time': '12:00'}, 'notes': 'Tickets!'},
          {'ref': tgv.id, 'number': 'TGV 6603', 'seat': '42'},
        ],
        'notes': [
          {'ref': 'n1', 'text': 'Neue Notiz\nmit zweiter Zeile'},
          {'ref': note.id, 'pinned': !note.pinned},
        ],
        'remove': [lyon.id],
      }, demo);
      final changes = PlanExchange.changes(imp, demo);
      String line(PlanChange c) =>
          '${c.type.name}:${c.isNote ? 'note' : c.kind!.name}:${c.title}:${c.fields.map((f) => f.name).join('+')}';
      expect(changes.map(line), [
        'created:stay:Nizza:',
        'created:note:Neue Notiz:',
        'updated:activity:Louvre:time+notes',
        'updated:transport:${tgv.title}:relation+ticket',
        'updated:note:${note.title}:pinned',
        'removed:stay:Lyon:',
      ]);
    });

    test('a new trip only has new entries', () {
      final imp = _apply({
        'trip': {'title': 'Neu'},
        'items': [
          {'ref': 'a', 'kind': 'stay', 'title': 'A'},
        ],
      }, null);
      expect(PlanExchange.changes(imp, null).map((c) => (c.type, c.title)), [(PlanChangeType.created, 'A')]);
    });

    test('trip fields', () {
      final t = demo.trip;
      expect(PlanExchange.tripChanges(t, t), isEmpty);
      final changed = t.copyWith(title: 'X', plannedDays: 3, currency: 'EUR', travellers: 2, rates: {'USD': 0.9});
      expect(PlanExchange.tripChanges(t, changed),
          {PlanField.title, PlanField.dates, PlanField.currency, PlanField.travellers, PlanField.rates});
    });
  });

  group('itemsAfter', () {
    test('merges changes, drops and unlinks removed items', () {
      final imp = _apply({
        'items': [
          {'ref': 'nice', 'kind': 'stay', 'title': 'Nizza'},
          {'ref': louvre.id, 'title': 'Musée du Louvre'},
        ],
        'remove': [paris.id],
      }, demo);
      final after = PlanExchange.itemsAfter(imp, demo);
      expect(after, hasLength(demo.items.length));
      expect(after.where((i) => i.id == paris.id), isEmpty);
      expect(after.where((i) => i.title == 'Nizza'), hasLength(1));
      final l = after.firstWhere((i) => i.id == louvre.id);
      expect([l.title, l.parentId], ['Musée du Louvre', null]);
      expect(after.firstWhere((i) => i.id == tgv.id).fromId, isNull);
    });

    test('lets the preview count conflicts the plan would cause', () {
      // Lyon starting a day earlier overlaps Paris.
      final imp = _apply({
        'items': [
          {'ref': lyon.id, 'start': {'day': 3, 'time': '14:00'}, 'end': {'day': 6, 'time': '10:00'}},
        ],
      }, demo);
      final before = findConflicts(demo.items).length;
      final after = PlanExchange.itemsAfter(imp, demo);
      expect(findConflicts(after).length, greaterThan(before));
    });
  });

  group('geocoding helpers', () {
    test('geoQuery: place, else a stay\'s title; never transports or located items', () {
      expect(geoQuery(_item('Kandy', ItemKind.stay)), 'Kandy');
      expect(geoQuery(_item('x', ItemKind.activity, place: ' Zahntempel ')), 'Zahntempel');
      expect(geoQuery(_item('x', ItemKind.activity)), isNull);
      expect(geoQuery(_item('x', ItemKind.transport, place: 'Bahnhof')), isNull);
      expect(geoQuery(_item('x', ItemKind.stay, lat: 1, lng: 2)), isNull);
    });

    test('tripBias is the median of located places', () {
      expect(tripBias([_item('a', ItemKind.stay)]), isNull);
      final b = tripBias([
        _item('a', ItemKind.stay, lat: 7, lng: 80),
        _item('b', ItemKind.stay, lat: 8, lng: 81),
        _item('c', ItemKind.stay, lat: 50, lng: 8), // the flight home
        _item('d', ItemKind.stay),
      ])!;
      expect([b.lat, b.lng, b.zoom], [8, 80, 5]);
    });

    test('biasFor prefers the located stay', () {
      final stay = _item('s', ItemKind.stay, lat: 7.29, lng: 80.63);
      final act = _item('a', ItemKind.activity, place: 'Tempel', parent: 's');
      const fallback = GeoBias(1, 2, 5);
      expect(biasFor(act, {'s': stay}, fallback), const GeoBias(7.29, 80.63, 11));
      expect(biasFor(act, {}, fallback), fallback);
      expect(biasFor(act, {'s': _item('s', ItemKind.stay)}, null), isNull);
    });

    test('countries from place names', () {
      expect(countryOf('Kandy, Central Province, Sri Lanka'), 'Sri Lanka');
      expect(countryOf('Kandy'), isNull);
      expect(countryOf(null), isNull);
      expect(
          tripCountries([
            _item('a', ItemKind.stay, place: 'Kandy, Sri Lanka', lat: 7, lng: 80),
            _item('b', ItemKind.stay, place: 'Rom, Italien'), // not located
          ]),
          {'sri lanka'});
    });
  });
}
