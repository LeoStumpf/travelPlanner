import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/domain/demo.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/domain/plan_exchange.dart';
import 'package:travel_planner/domain/time.dart';
import 'package:uuid/uuid.dart';

String _id() => const Uuid().v4();

PlanImport _apply(Object doc, {TripData? into}) => PlanExchange.apply(
      PlanExchange.parse(doc is String ? doc : jsonEncode(doc)),
      into: into,
      now: DateTime(2026, 10, 17),
      newId: _id,
    );

Map<String, Object?> _plan(List<Map<String, Object?>> items,
        {Map<String, Object?> trip = const {'title': 'T'}, List<Object?> notes = const [], List<String>? remove}) =>
    {
      'format': planFormat,
      'version': 1,
      'trip': trip,
      'items': items,
      'notes': notes,
      'remove': ?remove,
    };

void main() {
  test('export → import as new trip keeps structure, times and links', () {
    final demo = demoSriLanka();
    final imp = _apply(PlanExchange.exportText(demo));
    expect(imp.isNewTrip, isTrue);
    expect(imp.warnings, isEmpty);
    expect(imp.trip.title, demo.trip.title);
    expect(imp.trip.plannedDays, demo.trip.plannedDays);
    expect(imp.items, hasLength(demo.items.length));
    expect(imp.cards, hasLength(demo.cards.length));

    final byTitle = {for (final i in imp.items) i.title: i};
    final newIds = {for (final i in imp.items) i.id: i};
    for (final old in demo.items) {
      final i = byTitle[old.title]!;
      expect(i.id, isNot(old.id));
      expect(i.tripId, imp.trip.id);
      expect([i.kind, i.status, i.fixed, i.start, i.end, i.lat, i.mode],
          [old.kind, old.status, old.fixed, old.start, old.end, old.lat, old.mode]);
      expect(newIds[i.parentId]?.title, demo.item(old.parentId)?.title);
      expect(newIds[i.fromId]?.title, demo.item(old.fromId)?.title);
      expect(newIds[i.toId]?.title, demo.item(old.toId)?.title);
    }
    final note = imp.cards.firstWhere((c) => c.title == 'Train Kandy → Ella');
    expect(newIds[note.itemId]?.title, 'Kandy');
    final list = imp.cards.firstWhere((c) => c.type == CardType.checklist);
    expect(list.checklist.map((e) => e.text), contains('Apply for ETA visa'));
  });

  test('re-importing an unchanged export into the same trip changes nothing', () {
    final demo = demoInterrail();
    final imp = _apply(PlanExchange.exportText(demo), into: demo);
    expect(imp.warnings, isEmpty);
    expect(imp.isEmpty, isTrue, reason: '${imp.items.map((i) => i.title)}');
  });

  test('partial plan updates, adds and removes against an existing trip', () {
    final demo = demoSriLanka();
    final kandy = demo.items.firstWhere((i) => i.title == 'Kandy');
    final temple = demo.items.firstWhere((i) => i.title == 'Temple of the Tooth');
    final galle = demo.items.firstWhere((i) => i.title == 'Galle');
    final imp = _apply(
      _plan(
        [
          {'ref': temple.id, 'start': {'day': 5, 'time': '14:00'}, 'end': {'day': 5, 'time': '16:00'}, 'notes': 'Abends Puja'},
          {'ref': 'dance', 'kind': 'activity', 'title': 'Kandyan Dance', 'stay': kandy.id,
           'start': {'day': 5, 'time': '17:00'}, 'end': {'day': 5, 'time': '18:00'}},
        ],
        trip: {'id': demo.trip.id},
        notes: [
          {'ref': 'todo', 'title': 'Vor Ort', 'checklist': ['SIM-Karte', {'text': 'Tuk-Tuk-App', 'done': true}]},
        ],
        remove: [galle.id],
      ),
      into: demo,
    );
    expect(imp.warnings, isEmpty);
    expect(imp.isNewTrip, isFalse);
    expect([imp.itemsCreated, imp.itemsUpdated, imp.notesCreated], [1, 1, 1]);
    expect(imp.removeItemIds, [galle.id]);
    expect(imp.tripChanged, isFalse);

    final t = imp.items.firstWhere((i) => i.id == temple.id);
    expect(t.start, at(4, 14 * 60));
    expect(t.notes, 'Abends Puja');
    expect(t.title, temple.title, reason: 'fields not in the plan stay as they were');
    expect(t.lat, temple.lat);
    final dance = imp.items.firstWhere((i) => i.title == 'Kandyan Dance');
    expect(dance.parentId, kandy.id);
    expect(dance.tripId, demo.trip.id);
    expect(imp.cards.single.checklist.map((e) => (e.text, e.done)), [('SIM-Karte', false), ('Tuk-Tuk-App', true)]);
  });

  test('null clears a field; references to removed items are dropped', () {
    final demo = demoInterrail();
    final paris = demo.items.firstWhere((i) => i.title == 'Paris');
    final tgv = demo.items.firstWhere((i) => i.title.startsWith('TGV'));
    final imp = _apply(
      _plan([
        {'ref': tgv.id, 'notes': null, 'status': 'planned'},
        {'ref': paris.id, 'lat': null, 'lng': null},
      ], remove: [demo.items.firstWhere((i) => i.title == 'Lyon').id]),
      into: demo,
    );
    final t = imp.items.firstWhere((i) => i.id == tgv.id);
    expect(t.toId, isNull);
    expect(t.fromId, paris.id);
    expect(t.status, ItemStatus.planned);
    expect(imp.items.firstWhere((i) => i.id == paris.id).hasLocation, isFalse);
  });

  test('parses plans wrapped in prose and code fences', () {
    const text = 'Hier ist dein Plan:\n\n```json\n'
        '{"format": "tripboard-plan", "version": 1, "trip": {"title": "Rom"}, '
        '"items": [{"ref": "rom", "kind": "stay", "title": "Rom", '
        '"start": {"day": 1, "time": "14:00"}, "end": {"day": 4, "time": "10:00"}}]}\n'
        '```\n\nViel Spaß!';
    expect(PlanExchange.looksLikePlan(text), isTrue);
    final imp = _apply(text);
    expect(imp.trip.title, 'Rom');
    expect(nightsIn(imp.items.single.start!, imp.items.single.end!), 3);
  });

  test('calendar dates map onto trip days', () {
    final imp = _apply(_plan([
      {'ref': 'a', 'kind': 'activity', 'title': 'A', 'start': {'date': '2027-03-02', 'time': '09:00'}, 'end': '2027-03-02T11:30'},
    ], trip: {'title': 'T', 'startDate': '2027-02-27'}));
    expect(imp.warnings, isEmpty);
    expect(imp.trip.startDate, DateTime(2027, 2, 27));
    expect(imp.items.single.start, at(3, 9 * 60));
    expect(imp.items.single.end, at(3, 11 * 60 + 30));
  });

  test('bad entries become warnings instead of failing the import', () {
    final imp = _apply(_plan([
      {'ref': 'x', 'kind': 'castle', 'title': 'X'},
      {'ref': 'y', 'kind': 'activity'},
      {'ref': 'z', 'kind': 'activity', 'title': 'Z', 'stay': 'nowhere',
       'start': {'day': 2, 'time': '10:00'}, 'end': {'day': 1, 'time': '10:00'}},
      {'ref': 'd', 'kind': 'activity', 'title': 'D', 'start': {'date': '2027-01-01', 'time': '10:00'},
       'end': {'day': 1, 'time': '25:00'}},
      {'ref': 'z', 'kind': 'stay', 'title': 'Duplicate'},
    ], remove: ['ghost']));
    expect(imp.items.map((i) => i.title), ['Z', 'D']);
    expect(imp.items.every((i) => !i.isScheduled), isTrue);
    expect(imp.items.first.parentId, isNull);
    expect(imp.warnings, hasLength(8), reason: imp.warnings.join('\n'));
    // Language-neutral: a type plus the entry, field and value concerned.
    expect(
      [for (final w in imp.warnings) (w.type, w.entry, w.field, w.value)],
      unorderedEquals([
        (PlanWarningType.removeUnknown, null, null, 'ghost'),
        (PlanWarningType.duplicateRef, null, null, 'z'),
        (PlanWarningType.unknownKind, 'X', null, 'castle'),
        (PlanWarningType.missingTitle, 'y', null, null),
        (PlanWarningType.refNotFound, 'Z', 'stay', 'nowhere'),
        (PlanWarningType.endBeforeStart, 'Z', null, null),
        (PlanWarningType.dateNeedsStartDate, 'D', 'start', null),
        (PlanWarningType.invalidMoment, 'D', 'end', '{"day":1,"time":"25:00"}'),
      ]),
    );
  });

  test('a new trip without a title gets the given name', () {
    final doc = PlanExchange.parse(jsonEncode(_plan(const [], trip: const {})));
    final imp = PlanExchange.apply(doc, now: DateTime(2026, 10, 17), newId: _id, newTripTitle: 'Importierte Reise');
    expect(imp.trip.title, 'Importierte Reise');
    expect(PlanExchange.apply(doc, now: DateTime(2026, 10, 17), newId: _id).trip.title, 'Imported trip');
  });

  test('rejects non-plans', () {
    Matcher error(PlanErrorType type, [String? detail]) =>
        throwsA(isA<PlanFormatException>().having((e) => e.type, 'type', type).having((e) => e.detail, 'detail', detail));
    expect(() => PlanExchange.parse('Hallo'), throwsFormatException);
    expect(() => PlanExchange.parse('Hallo'), throwsA(isA<PlanFormatException>().having((e) => e.type, 'type', PlanErrorType.invalidJson)));
    expect(() => PlanExchange.parse('[1]'), error(PlanErrorType.notAnObject));
    expect(() => PlanExchange.parse('{"format": "other"}'), error(PlanErrorType.unknownFormat, 'other'));
    expect(() => PlanExchange.parse('{"foo": 1}'), error(PlanErrorType.notAPlan));
    expect(() => PlanExchange.parse('{"format": "tripboard-plan", "version": 9}'), error(PlanErrorType.tooNew, '9'));
  });

  test('the example in the format guide imports cleanly', () {
    final spec = File('assets/plan_format.md').readAsStringSync();
    final example = RegExp(r'```json\n([\s\S]*?)```').allMatches(spec).last.group(1)!;
    final imp = _apply(example);
    expect(imp.warnings, isEmpty);
    expect(imp.items, hasLength(7));
    expect(imp.cards, hasLength(2));
    final ids = {for (final i in imp.items) i.title: i.id};
    final train = imp.items.firstWhere((i) => i.kind == ItemKind.transport && i.mode == TransportMode.train);
    expect([train.fromId, train.toId], [ids['Colombo'], ids['Kandy']]);
    expect(imp.items.firstWhere((i) => i.title == 'Galle').isScheduled, isFalse);
    expect(train.departureStation, 'Colombo Fort');
    expect(train.transportNumber, '1009');
  });

  group('transport ticket details', () {
    PlanItem tgvOf(TripData d) => d.items.firstWhere((i) => i.title.startsWith('TGV'));

    TripData withDetails() {
      final demo = demoInterrail();
      final tgv = tgvOf(demo).copyWith(
        departureStation: 'Paris Gare de Lyon',
        arrivalStation: 'Lyon Part-Dieu',
        transportNumber: 'TGV 6603',
        seat: 'Car 12, seat 81',
        bookingRef: 'QX7K2P',
      );
      return TripData(trip: demo.trip, items: [for (final i in demo.items) i.id == tgv.id ? tgv : i], cards: demo.cards);
    }

    test('are exported under short keys and only when set', () {
      final d = withDetails();
      final items = PlanExchange.export(d)['items'] as List;
      final tgv = items.cast<Map<String, Object?>>().firstWhere((i) => i['ref'] == tgvOf(d).id);
      expect(tgv['departure'], 'Paris Gare de Lyon');
      expect(tgv['arrival'], 'Lyon Part-Dieu');
      expect(tgv['number'], 'TGV 6603');
      expect(tgv['seat'], 'Car 12, seat 81');
      expect(tgv['bookingRef'], 'QX7K2P');
      final other = items.cast<Map<String, Object?>>().firstWhere((i) => i['title'] == 'Euromed Barcelona → Valencia');
      expect(other.keys, isNot(contains('bookingRef')));
      expect(other.keys, isNot(contains('departure')));
    });

    test('survive an export → import round trip; re-import changes nothing', () {
      final d = withDetails();
      final imp = _apply(PlanExchange.exportText(d));
      final tgv = imp.items.firstWhere((i) => i.title.startsWith('TGV'));
      expect(tgv.departureStation, 'Paris Gare de Lyon');
      expect(tgv.arrivalStation, 'Lyon Part-Dieu');
      expect(tgv.transportNumber, 'TGV 6603');
      expect(tgv.seat, 'Car 12, seat 81');
      expect(tgv.bookingRef, 'QX7K2P');
      expect(_apply(PlanExchange.exportText(d), into: d).isEmpty, isTrue);
    });

    test('are set, trimmed and cleared (null or blank) on an existing item', () {
      final d = withDetails();
      final id = tgvOf(d).id;
      final imp = _apply(
        _plan([
          {'ref': id, 'number': '  TGV 6611 ', 'seat': null, 'bookingRef': '   '},
        ]),
        into: d,
      );
      expect(imp.warnings, isEmpty);
      final tgv = imp.items.single;
      expect(tgv.transportNumber, 'TGV 6611');
      expect(tgv.seat, isNull);
      expect(tgv.bookingRef, isNull);
      // Fields left out stay as they were.
      expect(tgv.departureStation, 'Paris Gare de Lyon');
      expect(tgv.arrivalStation, 'Lyon Part-Dieu');
    });

    test('plans without the fields (older exports) import as before', () {
      final imp = _apply(_plan([
        {'ref': 'bus', 'kind': 'transport', 'mode': 'bus', 'title': 'Bus'},
      ]));
      expect(imp.items.single.hasTransportDetails, isFalse);
    });
  });
}
