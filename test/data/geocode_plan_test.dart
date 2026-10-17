import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:travel_planner/data/geocoding.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/domain/places.dart';

/// Answers from a table by query; records each call with its bias.
class _Geocoder extends Geocoder {
  final Map<String, List<PlaceResult>> answers;
  final calls = <(String, GeoBias?)>[];
  bool offline = false;
  _Geocoder(this.answers);

  @override
  Future<List<PlaceResult>> search(String query, {String lang = 'en', GeoBias? bias}) async {
    calls.add((query, bias));
    if (offline) throw const SocketException('offline');
    return answers[query] ?? const [];
  }
}

/// Fails while [fail] says so, else finds every place at 1/1.
class _FlakyGeocoder extends Geocoder {
  final bool Function() fail;
  _FlakyGeocoder(this.fail);

  @override
  Future<List<PlaceResult>> search(String query, {String lang = 'en', GeoBias? bias}) async {
    if (fail()) throw const SocketException('flaky');
    return [PlaceResult(query, '', 1, 1)];
  }
}

PlanItem _item(String id, ItemKind kind, {String? place, double? lat, double? lng, String? parent, String? title}) =>
    PlanItem(
      id: id,
      tripId: 't',
      kind: kind,
      title: title ?? id,
      placeName: place,
      lat: lat,
      lng: lng,
      parentId: parent,
      createdAt: DateTime(2026),
    );

void main() {
  final kandy = _item('kandy', ItemKind.stay, place: 'Kandy, Central Province, Sri Lanka', lat: 7.29, lng: 80.63);
  final colombo = _item('colombo', ItemKind.stay, place: 'Colombo, Sri Lanka', lat: 6.93, lng: 79.85);

  test('leans on the trip, prefers its countries and reports what was not found', () async {
    final g = _Geocoder({
      'Galle': [
        const PlaceResult('Galle', 'Ohio, USA', 40.1, -83.0, country: 'USA'),
        const PlaceResult('Galle', 'Southern Province, Sri Lanka', 6.03, 80.21, country: 'Sri Lanka'),
      ],
      'Fort': [const PlaceResult('Galle Fort', 'Sri Lanka', 6.026, 80.217, country: 'Sri Lanka')],
    });
    final galle = _item('Galle', ItemKind.stay);
    final fort = _item('fort', ItemKind.activity, place: 'Fort', parent: 'Galle');
    final nowhere = _item('nowhere', ItemKind.activity, place: 'Atlantis');
    final train = _item('train', ItemKind.transport, place: 'Bahnhof');

    // The activity comes first but is looked up after its stay.
    final out = await fillCoordinates([fort, nowhere, galle, train], g, context: [kandy, colombo]);

    expect(g.calls.map((c) => c.$1), ['Galle', 'Fort', 'Atlantis']);
    // Galle: trip middle (median of Kandy, Colombo), country scale.
    expect(g.calls[0].$2, const GeoBias((7.29 + 6.93) / 2, (80.63 + 79.85) / 2, 5));
    // Fort: the freshly found Galle, city scale.
    expect(g.calls[1].$2, const GeoBias(6.03, 80.21, 11));

    final byId = {for (final i in out.items) i.id: i};
    expect([byId['Galle']!.lat, byId['Galle']!.lng], [6.03, 80.21], reason: 'Sri Lanka beats Ohio');
    expect([byId['fort']!.lat, byId['fort']!.lng], [6.026, 80.217]);
    expect(byId['nowhere']!.hasLocation, isFalse);
    expect(out.items.map((i) => i.id), ['fort', 'nowhere', 'Galle', 'train'], reason: 'order kept');
    expect(out.searched.map((i) => i.id), ['Galle', 'fort', 'nowhere']);
    expect(out.notFound.map((i) => i.id), ['nowhere']);
  });

  test('offline: everything searched is reported as not found', () async {
    final g = _Geocoder({})..offline = true;
    final out = await fillCoordinates(
        [_item('Galle', ItemKind.stay), _item('Ella', ItemKind.stay), _item('Mirissa', ItemKind.stay)], g);
    expect(out.notFound, hasLength(3));
    expect(out.searched, hasLength(3));
    expect(out.items.every((i) => !i.hasLocation), isTrue);
    expect(g.calls.map((c) => c.$2), [null, null], reason: 'nothing located, no bias; gives up after two failures');
  });

  test('a single failed request does not stop the search', () async {
    var n = 0;
    final g = _FlakyGeocoder(() => n++ == 0);
    final out = await fillCoordinates([_item('Galle', ItemKind.stay), _item('Ella', ItemKind.stay)], g);
    expect(out.notFound.map((i) => i.id), ['Galle']);
    expect(out.items.last.hasLocation, isTrue);
  });

  test('the same name with the same bias is looked up once', () async {
    final g = _Geocoder({'Ella': [const PlaceResult('Ella', '', 6.87, 81.05)]});
    final out = await fillCoordinates([
      _item('a', ItemKind.activity, place: 'Ella'),
      _item('b', ItemKind.activity, place: 'Ella'),
    ], g);
    expect(g.calls, hasLength(1));
    expect(out.notFound, isEmpty);
  });

  test('Photon gets the bias as lat/lon/zoom and the country is parsed', () async {
    late Uri seen;
    final client = MockClient((req) async {
      seen = req.url;
      return http.Response(
          jsonEncode({
            'features': [
              {
                'geometry': {'coordinates': [80.21, 6.03]},
                'properties': {'name': 'Galle', 'state': 'Southern Province', 'country': 'Sri Lanka'},
              },
            ],
          }),
          200);
    });
    final r = await Geocoder(client).search('Galle', lang: 'de', bias: const GeoBias(7.1, 80.2, 5));
    expect(seen.queryParameters, containsPair('lat', '7.10000'));
    expect(seen.queryParameters, containsPair('lon', '80.20000'));
    expect(seen.queryParameters, containsPair('zoom', '5'));
    expect(r.single.country, 'Sri Lanka');

    await Geocoder(client).search('Galle');
    expect(seen.queryParameters.containsKey('lat'), isFalse);
  });
}
