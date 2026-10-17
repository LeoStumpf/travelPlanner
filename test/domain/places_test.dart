import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/domain/places.dart';

void main() {
  group('parseCoordinates', () {
    test('decimal pairs in common spellings', () {
      expect(parseCoordinates('48.8584, 2.2945'), (48.8584, 2.2945));
      expect(parseCoordinates('48.8584,2.2945'), (48.8584, 2.2945));
      expect(parseCoordinates('  -33.8568 151.2153 '), (-33.8568, 151.2153));
      expect(parseCoordinates('7.2906;80.6337'), (7.2906, 80.6337));
    });

    test('hemisphere letters, before or after, in either order', () {
      expect(parseCoordinates('48.8584N, 2.2945E'), (48.8584, 2.2945));
      expect(parseCoordinates('33.8568 S 151.2153 E'), (-33.8568, 151.2153));
      expect(parseCoordinates('N 48.8584 W 2.2945'), (48.8584, -2.2945));
      expect(parseCoordinates('2.2945E 48.8584N'), (48.8584, 2.2945));
      expect(parseCoordinates('48.85N 2.29N'), isNull);
    });

    test('degrees, minutes and seconds as Google Maps copies them', () {
      final c = parseCoordinates('48°51\'30.2"N 2°17\'40.2"E')!;
      expect(c.$1, closeTo(48.85839, 1e-4));
      expect(c.$2, closeTo(2.29450, 1e-4));
      final s = parseCoordinates('33° 51′ 24″ S, 151° 12′ 55″ E')!;
      expect(s.$1, closeTo(-33.8567, 1e-3));
      expect(s.$2, closeTo(151.2153, 1e-3));
    });

    test('plain text and impossible values are no coordinates', () {
      expect(parseCoordinates('Kandy'), isNull);
      expect(parseCoordinates('Route 66 1'), isNull);
      expect(parseCoordinates('12 3'), isNull);
      expect(parseCoordinates('95.0, 2.0'), isNull);
      expect(parseCoordinates('45.0, 200.0'), isNull);
      expect(parseCoordinates('0.0, 0.0'), isNull);
    });
  });

  group('parsePlaceInput links', () {
    test('Google Maps place link prefers the pin over the viewport', () {
      final p = parsePlaceInput(
          'https://www.google.com/maps/place/Eiffel+Tower/@48.8583701,2.2919064,17z/data=!3m1!4b1!4m6!3m5!1s0x0:0x8ddca9ee380ef7e0!8m2!3d48.8583701!4d2.2944813!16zL20vMDJqODE')!;
      expect(p.lat, 48.8583701);
      expect(p.lng, 2.2944813);
      expect(p.name, 'Eiffel Tower');
    });

    test('Google Maps viewport, query and search links', () {
      expect(parsePlaceInput('https://www.google.de/maps/@7.2906,80.6337,14z'), const ParsedPlace(lat: 7.2906, lng: 80.6337));
      expect(parsePlaceInput('https://maps.google.com/?q=7.2906,80.6337'), const ParsedPlace(lat: 7.2906, lng: 80.6337));
      expect(parsePlaceInput('https://www.google.com/maps/search/?api=1&query=48.8584%2C2.2945'),
          const ParsedPlace(lat: 48.8584, lng: 2.2945));
      expect(parsePlaceInput('https://www.google.com/maps/search/48.8584,+2.2945'),
          const ParsedPlace(lat: 48.8584, lng: 2.2945));
    });

    test('a Google link with a name only asks for a search', () {
      expect(parsePlaceInput('https://maps.google.com/?q=Temple+of+the+Tooth'), const ParsedPlace(name: 'Temple of the Tooth'));
      expect(parsePlaceInput('https://www.google.com/maps/place/Sigiriya/'), const ParsedPlace(name: 'Sigiriya'));
    });

    test('OpenStreetMap marker and map links', () {
      expect(parsePlaceInput('https://www.openstreetmap.org/?mlat=48.85840&mlon=2.29450#map=17/48.85840/2.29450'),
          const ParsedPlace(lat: 48.8584, lng: 2.2945));
      expect(parsePlaceInput('https://www.openstreetmap.org/#map=15/7.29060/80.63370'),
          const ParsedPlace(lat: 7.2906, lng: 80.6337));
      expect(parsePlaceInput('https://www.openstreetmap.org/node/123'), const ParsedPlace());
    });

    test('Apple Maps and geo: URIs', () {
      expect(parsePlaceInput('https://maps.apple.com/?ll=48.8584,2.2945&q=Eiffel%20Tower'),
          const ParsedPlace(lat: 48.8584, lng: 2.2945, name: 'Eiffel Tower'));
      expect(parsePlaceInput('geo:48.8584,2.2945'), const ParsedPlace(lat: 48.8584, lng: 2.2945));
      expect(parsePlaceInput('geo:48.8584,2.2945;u=35'), const ParsedPlace(lat: 48.8584, lng: 2.2945));
      expect(parsePlaceInput('geo:0,0?q=48.8584,2.2945(Eiffel Tower)'),
          const ParsedPlace(lat: 48.8584, lng: 2.2945, name: 'Eiffel Tower'));
      expect(parsePlaceInput('geo:0,0?q=Kandy+Lake'), const ParsedPlace(name: 'Kandy Lake'));
    });

    test('plain text and other sites are left to the search', () {
      expect(parsePlaceInput('Kandy'), isNull);
      expect(parsePlaceInput(''), isNull);
      expect(parsePlaceInput('https://example.com/?q=48.1,11.5'), isNull);
      expect(parsePlaceInput('https://www.google.com/search?q=kandy'), isNull);
    });

    test('short links are recognised', () {
      expect(isShortMapLink('https://maps.app.goo.gl/AbC123'), isTrue);
      expect(isShortMapLink('https://goo.gl/maps/xyz'), isTrue);
      expect(isShortMapLink('https://osm.org/go/0BOdUs9e--'), isTrue);
      expect(isShortMapLink('https://www.google.com/maps/@1.5,2.5,3z'), isFalse);
      expect(isShortMapLink('Kandy'), isFalse);
    });
  });

  group('recentPlaces', () {
    PlanItem item(String id, String title, {String? place, double? lat, double? lng}) => PlanItem(
          id: id,
          tripId: 't',
          kind: ItemKind.stay,
          title: title,
          placeName: place,
          lat: lat,
          lng: lng,
          status: ItemStatus.planned,
          createdAt: DateTime(2026),
        );

    final uses = [
      PlaceUse(item('a', 'Kandy', place: 'Kandy, Central Province, Sri Lanka', lat: 7.2906, lng: 80.6337), 'Sri Lanka',
          DateTime(2026, 3, 1)),
      PlaceUse(item('b', 'Old Kandy', place: 'Kandy', lat: 7.29061, lng: 80.63371), 'Old trip', DateTime(2025, 1, 1)),
      PlaceUse(item('c', 'Picnic', place: 'Picked on the map', lat: 48.1, lng: 11.5), 'Bavaria', DateTime(2026, 5, 1)),
      PlaceUse(item('d', 'Nowhere'), 'Bavaria', DateTime(2026, 6, 1)),
    ];

    test('newest first, one per spot, located items only', () {
      final r = recentPlaces(uses, generic: {'Picked on the map'});
      expect(r.map((p) => p.label), ['Picnic', 'Kandy, Central Province, Sri Lanka']);
      expect(r[1].name, 'Kandy');
      expect(r[1].detail, 'Central Province, Sri Lanka');
      expect(r[1].tripTitle, 'Sri Lanka');
    });

    test('filters by every word of the query, also the trip title', () {
      expect(recentPlaces(uses, query: 'kandy lanka').map((p) => p.name), ['Kandy']);
      expect(recentPlaces(uses, query: 'bavaria', generic: {'Picked on the map'}).map((p) => p.name), ['Picnic']);
      expect(recentPlaces(uses, query: 'paris'), isEmpty);
    });

    test('respects the limit', () {
      expect(recentPlaces(uses, limit: 1), hasLength(1));
    });
  });
}
