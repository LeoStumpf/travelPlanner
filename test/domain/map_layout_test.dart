import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/domain/map_layout.dart';
import 'package:travel_planner/domain/map_offline.dart';
import 'package:travel_planner/domain/models.dart';

final _t0 = DateTime(2026, 1, 1);

PlanItem item(String id, ItemKind kind,
        {double? lat, double? lng, String? parent, String? from, String? to, String? place, String? station}) =>
    PlanItem(
      id: id,
      tripId: 't',
      kind: kind,
      title: id,
      lat: lat,
      lng: lng,
      parentId: parent,
      fromId: from,
      toId: to,
      placeName: place,
      departureStation: station,
      createdAt: _t0,
    );

TripData trip(List<PlanItem> items) =>
    TripData(trip: Trip(id: 't', title: 'T', createdAt: _t0), items: items);

MapMarker marker(String id, ItemKind kind, double lat, double lng) => (id: id, kind: kind, lat: lat, lng: lng);

/// Distance in logical pixels at [zoom] between two (lat, lng) points.
double px((double, double) a, (double, double) b, double zoom) {
  final d = degreesPerPixel(zoom);
  final dx = (a.$2 - b.$2) / d;
  final dy = (a.$1 - b.$1) / (d * math.cos(a.$1 * math.pi / 180));
  return math.sqrt(dx * dx + dy * dy);
}

void main() {
  group('spreadMarkers', () {
    test('markers on their own spot stay where they are', () {
      final out = spreadMarkers([
        marker('a', ItemKind.stay, 48.85, 2.35),
        marker('b', ItemKind.activity, 48.86, 2.33),
      ], 12);
      expect(out, {'a': (48.85, 2.35), 'b': (48.86, 2.33)});
    });

    test('the stay keeps a shared spot, its children ring around it', () {
      const at = (48.85, 2.35);
      final out = spreadMarkers([
        marker('louvre', ItemKind.activity, at.$1, at.$2),
        marker('paris', ItemKind.stay, at.$1, at.$2),
        marker('hotel', ItemKind.accommodation, at.$1, at.$2),
      ], 12);
      expect(out['paris'], at);
      for (final id in ['louvre', 'hotel']) {
        expect(px(out[id]!, at, 12), closeTo(22, 0.5), reason: id);
      }
      // Distinct spots, and far enough apart for 8-px circles.
      expect(px(out['louvre']!, out['hotel']!, 12), greaterThan(20));
    });

    test('the first child sits top right, clear of the label below', () {
      const at = (10.0, 20.0);
      final out = spreadMarkers([
        marker('s', ItemKind.stay, at.$1, at.$2),
        marker('a', ItemKind.activity, at.$1, at.$2),
      ], 10);
      expect(out['a']!.$1, greaterThan(at.$1));
      expect(out['a']!.$2, greaterThan(at.$2));
    });

    test('offsets shrink in degrees as the map zooms in', () {
      const at = (0.0, 0.0);
      final ms = [marker('s', ItemKind.stay, 0, 0), marker('a', ItemKind.activity, 0, 0)];
      final far = spreadMarkers(ms, 8)['a']!, near = spreadMarkers(ms, 14)['a']!;
      expect(near.$2.abs(), lessThan(far.$2.abs()));
      expect(px(far, at, 8), closeTo(px(near, at, 14), 0.01));
    });

    test('many children get a wider ring so neighbours never touch', () {
      final ms = [
        marker('s', ItemKind.stay, 41.9, 12.5),
        for (var k = 0; k < 12; k++) marker('a$k', ItemKind.activity, 41.9, 12.5),
      ];
      final out = spreadMarkers(ms, 13);
      for (var k = 0; k < 12; k++) {
        final next = out['a${(k + 1) % 12}']!;
        expect(px(out['a$k']!, next, 13), greaterThanOrEqualTo(20), reason: 'a$k');
      }
      expect(out.values.toSet().length, 13);
    });
  });

  group('nearestMarker', () {
    final screen = {'a': (100.0, 100.0), 'b': (130.0, 100.0)};
    test('picks the closest marker within the radius', () {
      expect(nearestMarker(screen, (110, 104), 26), 'a');
      expect(nearestMarker(screen, (122, 98), 26), 'b');
    });
    test('nothing when the tap is too far from every marker', () {
      expect(nearestMarker(screen, (100, 140), 26), isNull);
      expect(nearestMarker(const {}, (0, 0), 26), isNull);
    });
  });

  group('needsPan', () {
    const view = GeoBox(40, 0, 50, 10);
    test('a point well inside the view needs no camera move', () {
      expect(needsPan(view, [(45, 5)]), isFalse);
    });
    test('points outside or right at the edge do', () {
      expect(needsPan(view, [(52, 5)]), isTrue);
      expect(needsPan(view, [(49.9, 5)]), isTrue);
      expect(needsPan(view, [(45, 5), (45, 11)]), isTrue);
    });
  });

  group('focusPoints', () {
    test('an activity without own place uses its stay, a transport both ends', () {
      final data = trip([
        item('paris', ItemKind.stay, lat: 48.85, lng: 2.35),
        item('lyon', ItemKind.stay, lat: 45.76, lng: 4.83),
        item('louvre', ItemKind.activity, parent: 'paris'),
        item('tgv', ItemKind.transport, from: 'paris', to: 'lyon'),
        item('idea', ItemKind.activity),
      ]);
      expect(focusPoints(data, data.item('louvre')!), [(48.85, 2.35)]);
      expect(focusPoints(data, data.item('tgv')!), [(48.85, 2.35), (45.76, 4.83)]);
      expect(focusPoints(data, data.item('idea')!), isEmpty);
    });
  });

  group('navigation', () {
    final data = trip([
      item('Paris', ItemKind.stay, lat: 48.85, lng: 2.35),
      item('Lyon', ItemKind.stay, lat: 45.76, lng: 4.83),
      item('Louvre', ItemKind.activity, parent: 'Paris'),
      item('Museum', ItemKind.activity, place: 'Rue de Rivoli 99, Paris'),
      item('TGV', ItemKind.transport, from: 'Paris', to: 'Lyon'),
      item('TGV2', ItemKind.transport, from: 'Paris', to: 'Lyon', station: 'Gare de Lyon'),
      item('Idea', ItemKind.activity),
      item('Hotel', ItemKind.accommodation, parent: 'Paris', place: 'Rue Cler 12, Paris'),
    ]);

    test('coordinates first: a geo: URI, then Google Maps directions', () {
      final t = navigationTarget(data, data.item('Louvre')!)!;
      expect(t.at, (48.85, 2.35));
      final uris = navigationUris(t);
      expect(uris.first.toString(), 'geo:48.85,2.35?q=48.85,2.35(Louvre)');
      expect(uris.last.host, 'www.google.com');
      expect(uris.last.queryParameters, {'api': '1', 'destination': '48.85,2.35'});
    });

    test('without coordinates the address is searched', () {
      final t = navigationTarget(data, data.item('Museum')!)!;
      expect(t.at, isNull);
      final uris = navigationUris(t);
      expect(uris.first.toString(), 'geo:0,0?q=Rue%20de%20Rivoli%2099%2C%20Paris');
      expect(uris.last.queryParameters['destination'], 'Rue de Rivoli 99, Paris');
    });

    test("an address of its own beats the stay's coordinates", () {
      final t = navigationTarget(data, data.item('Hotel')!)!;
      expect(t.at, isNull);
      expect(t.query, 'Rue Cler 12, Paris');
    });

    test('a transport leads to its departure: the station, else the origin', () {
      expect(navigationTarget(data, data.item('TGV')!)!.at, (48.85, 2.35));
      final station = navigationTarget(data, data.item('TGV2')!)!;
      expect(station.query, 'Gare de Lyon, Paris');
      expect(station.label, 'Gare de Lyon');
    });

    test('nothing known, no navigation', () {
      expect(navigationTarget(data, data.item('Idea')!), isNull);
      expect(navigationTarget(data, item('x', ItemKind.transport)), isNull);
    });
  });
}
