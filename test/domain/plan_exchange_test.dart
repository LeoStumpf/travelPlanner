import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/domain/demo.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/domain/plan_exchange.dart';
import 'package:travel_planner/domain/analysis.dart';
import 'package:travel_planner/domain/time.dart';
import 'package:travel_planner/domain/zones.dart';
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
    // Zones: the outbound flight leaves at 21:15 in Berlin and lands 10:20 in Colombo.
    expect(imp.trip.homeZone, 'Europe/Berlin');
    final data = TripData(trip: imp.trip, items: imp.items);
    final flight = imp.items.firstWhere((i) => i.mode == TransportMode.plane);
    expect(data.zones.absDuration(flight), 8 * 60 + 35);
    expect(findConflicts(data.items, zones: data.zones), isEmpty);
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

  group('time zones', () {
    // FRA → CMB in local times: 21:30 in Frankfurt, 10:30 next day in Colombo.
    Map<String, Object?> fraCmb({Object? flightTz, Object? flightEnd}) => _plan(
          [
            {'ref': 'fra', 'kind': 'stay', 'title': 'Frankfurt', 'tz': 'Europe/Berlin',
              'start': {'day': 1, 'time': '14:00'}, 'end': {'day': 2, 'time': '19:00'}},
            {'ref': 'lh', 'kind': 'transport', 'mode': 'plane', 'title': 'LH 754', 'from': 'fra', 'to': 'cmb',
              'tz': ?flightTz,
              'start': {'day': 2, 'time': '21:30'}, 'end': flightEnd ?? {'day': 3, 'time': '10:30'}},
            {'ref': 'cmb', 'kind': 'stay', 'title': 'Colombo', 'tz': 'Asia/Colombo',
              'start': {'day': 3, 'time': '10:30'}, 'end': {'day': 6, 'time': '10:00'}},
          ],
          trip: {'title': 'Sri Lanka', 'startDate': '2027-03-01', 'tz': 'Europe/Berlin'},
        );

    test('import reads tz on trip and stays; times stay local', () {
      final imp = _apply(fraCmb());
      expect(imp.warnings, isEmpty);
      expect(imp.trip.homeZone, 'Europe/Berlin');
      final byRef = {for (final i in imp.items) i.title: i};
      expect(byRef['Frankfurt']!.tz, 'Europe/Berlin');
      expect(byRef['Colombo']!.tz, 'Asia/Colombo');
      final lh = byRef['LH 754']!;
      expect(lh.tz, isNull, reason: 'follows its stays');
      expect([lh.start, lh.end], [at(1, 21 * 60 + 30), at(2, 10 * 60 + 30)]);
      final data = TripData(trip: imp.trip, items: imp.items);
      expect(data.zones.absDuration(lh), 8 * 60 + 30);
      expect(findConflicts(data.items, zones: data.zones), isEmpty);
    });

    test('export writes tz / endTz only where set; round trip changes nothing', () {
      final imp = _apply(fraCmb());
      final items = [
        for (final i in imp.items) i.title == 'LH 754' ? i.copyWith(endTz: 'Asia/Kolkata') : i,
      ];
      final d = TripData(trip: imp.trip, items: items);
      final out = PlanExchange.export(d);
      expect((out['trip'] as Map)['tz'], 'Europe/Berlin');
      final byTitle = {for (final i in (out['items'] as List).cast<Map<String, Object?>>()) i['title']: i};
      expect(byTitle['Colombo']!['tz'], 'Asia/Colombo');
      expect(byTitle['LH 754']!['endTz'], 'Asia/Kolkata');
      expect(byTitle['LH 754']!.keys, isNot(contains('tz')));
      expect(_apply(PlanExchange.exportText(d), into: d).isEmpty, isTrue);
      final again = _apply(PlanExchange.exportText(d));
      expect(again.items.firstWhere((i) => i.title == 'LH 754').endTz, 'Asia/Kolkata');
      // A trip without zones exports no tz keys at all.
      expect(PlanExchange.exportText(demoSriLanka()), isNot(contains('"tz"')));
    });

    test('unknown zones are reported and ignored', () {
      final doc = fraCmb(flightTz: 'Europe/Atlantis');
      (doc['trip'] as Map)['tz'] = 'Nowhere';
      final imp = _apply(doc);
      final w = imp.warnings.where((w) => w.type == PlanWarningType.unknownTimeZone).toList();
      expect(w, hasLength(2));
      expect(w.map((x) => (x.entry, x.field, x.value)), containsAll([(null, 'tz', 'Nowhere'), ('LH 754', 'tz', 'Europe/Atlantis')]));
      expect(imp.trip.homeZone, isNull);
      expect(imp.items.firstWhere((i) => i.title == 'LH 754').tz, isNull);
    });

    test('blank tz clears; tz on lodging and activities is ignored', () {
      final imp = _apply(fraCmb());
      final d = TripData(trip: imp.trip, items: imp.items);
      final cmb = imp.items.firstWhere((i) => i.title == 'Colombo');
      final r = _apply(
        _plan([
          {'ref': cmb.id, 'tz': ''},
          {'ref': 'h', 'kind': 'accommodation', 'title': 'Hotel', 'stay': cmb.id, 'tz': 'Asia/Tokyo'},
        ], trip: {'tz': null}),
        into: d,
      );
      expect(r.warnings, isEmpty);
      expect(r.trip.homeZone, isNull);
      expect(r.items.firstWhere((i) => i.id == cmb.id).tz, isNull);
      expect(r.items.firstWhere((i) => i.title == 'Hotel').tz, isNull);
    });

    test('a transport may land "before" take-off in local time, but not in real time', () {
      // Tokyo 21:00 → Honolulu 09:00 the same day is a 7 h flight.
      final ok = _apply(_plan([
        {'ref': 'tyo', 'kind': 'stay', 'title': 'Tokyo', 'tz': 'Asia/Tokyo',
          'start': {'day': 1, 'time': '14:00'}, 'end': {'day': 4, 'time': '18:00'}},
        {'ref': 'fl', 'kind': 'transport', 'title': 'Flight', 'from': 'tyo', 'to': 'hnl',
          'start': {'day': 4, 'time': '21:00'}, 'end': {'day': 4, 'time': '09:00'}},
        {'ref': 'hnl', 'kind': 'stay', 'title': 'Honolulu', 'tz': 'Pacific/Honolulu',
          'start': {'day': 4, 'time': '11:00'}, 'end': {'day': 7, 'time': '10:00'}},
      ], trip: {'title': 'T', 'startDate': '2027-03-01'}));
      expect(ok.warnings, isEmpty);
      expect(ok.items.firstWhere((i) => i.title == 'Flight').end, at(3, 9 * 60));

      // Same zone at both ends: arriving before departing is an error.
      final bad = _apply(fraCmb(flightEnd: {'day': 2, 'time': '20:00'}));
      bad.items.where((i) => i.title == 'LH 754').forEach((i) => expect(i.isScheduled, isFalse));
      // Frankfurt 21:30 is 02:00 the next day in Colombo: landing at 02:30
      // there is a 30 min hop, landing at 01:00 would be before take-off
      // although the clock reads later.
      final short = _apply(fraCmb(flightEnd: {'day': 3, 'time': '02:30'}));
      expect(short.warnings, isEmpty);
      expect(short.items.firstWhere((i) => i.title == 'LH 754').isScheduled, isTrue);
      final tooEarly = _apply(fraCmb(flightEnd: {'day': 3, 'time': '01:00'}));
      expect(tooEarly.warnings.map((w) => w.type), [PlanWarningType.endBeforeStart]);
      expect(tooEarly.items.firstWhere((i) => i.title == 'LH 754').isScheduled, isFalse);
    });

    test('a bad arrival on an existing transport keeps its old times', () {
      final imp = _apply(fraCmb());
      final d = TripData(trip: imp.trip, items: imp.items);
      final lh = imp.items.firstWhere((i) => i.title == 'LH 754');
      final r = _apply(
        _plan([
          {'ref': lh.id, 'end': {'day': 2, 'time': '23:00'}},
        ], trip: const {}),
        into: d,
      );
      expect(r.warnings.map((w) => w.type), [PlanWarningType.endBeforeStart]);
      expect(r.items, isEmpty);
      expect(r.isEmpty, isTrue);
    });
  });
}
