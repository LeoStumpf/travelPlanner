import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/domain/demo.dart';
import 'package:travel_planner/domain/map_offline.dart';
import 'package:travel_planner/domain/models.dart';

final _t0 = DateTime(2026, 1, 1);

PlanItem place(String id, double? lat, double? lng, {ItemKind kind = ItemKind.stay, String? parent}) => PlanItem(
      id: id,
      tripId: 't',
      kind: kind,
      title: id,
      lat: lat,
      lng: lng,
      parentId: parent,
      createdAt: _t0,
    );

TripData trip(List<PlanItem> items) => TripData(trip: Trip(id: 't', title: 'T', createdAt: _t0), items: items);

void main() {
  group('GeoBox', () {
    test('around, padded, contains and the metadata list', () {
      final b = GeoBox.around([(48.0, 2.0), (45.0, 4.0), (46.0, 1.0)])!;
      expect(b, const GeoBox(45, 1, 48, 4));
      expect(GeoBox.around(const []), isNull);

      final p = b.padded();
      expect(p.south, closeTo(44.7, 1e-9));
      expect(p.east, closeTo(4.3, 1e-9));
      expect(p.contains(b), isTrue);
      expect(b.contains(p), isFalse);
      // A single point still gets an area around it.
      expect(const GeoBox(10, 10, 10, 10).padded(), const GeoBox(9.9, 9.9, 10.1, 10.1));
      // Clamped to the Mercator world.
      expect(const GeoBox(84, 179, 85, 180).padded(minDegrees: 2).north, maxMercatorLat);

      expect(GeoBox.fromList(b.toList()), b);
      expect(GeoBox.fromList([1, 2, 3, 4]), const GeoBox(1, 2, 3, 4));
      expect(GeoBox.fromList(null), isNull);
      expect(GeoBox.fromList(['a', 1, 2, 3]), isNull);
    });
  });

  test('tileCount', () {
    const world = GeoBox(-maxMercatorLat, -180, maxMercatorLat, 180);
    expect(tileCount(world, 0, 0), 1);
    expect(tileCount(world, 0, 2), 1 + 4 + 16);
    // About 10 km around Paris at street level: a handful of tiles per zoom.
    const paris = GeoBox(48.81, 2.28, 48.91, 2.42);
    expect(tileCount(paris, 14, 14), inInclusiveRange(30, 120));
    expect(tileCount(paris, 10, 10), lessThanOrEqualTo(4));
  });

  test('itemPosition falls back to the stay; placesBox ignores transports', () {
    final data = trip([
      place('paris', 48.85, 2.35),
      place('hotel', null, null, kind: ItemKind.accommodation, parent: 'paris'),
      place('louvre', 48.86, 2.33, kind: ItemKind.activity, parent: 'paris'),
      place('nowhere', null, null),
      place('flight', 0, 0, kind: ItemKind.transport),
    ]);
    expect(itemPosition(data, data.item('hotel')!), (48.85, 2.35));
    expect(itemPosition(data, data.item('nowhere')!), isNull);
    expect(placesBox(data), const GeoBox(48.85, 2.33, 48.86, 2.35));
    expect(placesBox(trip([place('x', null, null)])), isNull);
  });

  group('planOfflineMap', () {
    test('null without places', () {
      expect(planOfflineMap(trip([place('x', null, null)])), isNull);
    });

    test('Interrail: overview of the route plus street level around each stay', () {
      final data = demoInterrail();
      final plan = planOfflineMap(data)!;
      final overview = plan.regions.first;
      expect(overview.part, 'overview');
      expect(overview.minZoom, 0);
      expect(overview.box, plan.box);
      expect(plan.box.contains(placesBox(data)!), isTrue);

      final details = plan.regions.skip(1).toList();
      final stays = data.items.where((i) => i.kind == ItemKind.stay && i.hasLocation).length;
      expect(details, hasLength(stays));
      for (final d in details) {
        expect(d.part, 'stay');
        expect(d.minZoom, overview.maxZoom + 1);
        expect(d.maxZoom, maxTileZoom);
      }
      expect(plan.tiles, lessThanOrEqualTo(tileBudget));
      expect(plan.estimatedBytes, plan.tiles * OfflinePlan.avgTileBytes + OfflinePlan.styleBytes);
    });

    test('stays close together share one detail area', () {
      final plan = planOfflineMap(trip([place('a', 48.851, 2.351), place('b', 48.852, 2.349)]))!;
      expect(plan.regions.where((r) => r.part == 'stay'), hasLength(1));
    });

    test('a trip around the world stays within the budget', () {
      final plan = planOfflineMap(trip([
        place('lisbon', 38.72, -9.14),
        place('tokyo', 35.68, 139.76),
        place('sydney', -33.87, 151.21),
        place('nyc', 40.71, -74.0),
      ]))!;
      expect(plan.tiles, lessThanOrEqualTo(tileBudget));
      expect(plan.regions.first.maxZoom, lessThan(8));
      expect(plan.regions.where((r) => r.part == 'stay'), hasLength(4));
    });

    test('a small budget lowers the detail zoom, a tiny one drops it', () {
      final data = demoInterrail();
      final full = planOfflineMap(data)!;
      final small = planOfflineMap(data, budget: 400)!;
      expect(small.tiles, lessThanOrEqualTo(400));
      expect(small.regions.last.maxZoom, lessThan(full.regions.last.maxZoom));
      final tiny = planOfflineMap(data, budget: 10)!;
      expect(tiny.regions, hasLength(1));
    });
  });

  test('mapAvailability', () {
    MapAvailability a({bool loaded = false, bool timedOut = false, bool? online, bool saved = false}) =>
        mapAvailability(styleLoaded: loaded, styleTimedOut: timedOut, online: online, saved: saved);

    expect(a(), MapAvailability.loading);
    expect(a(online: true), MapAvailability.loading);
    expect(a(loaded: true), MapAvailability.ok);
    expect(a(loaded: true, online: true), MapAvailability.ok);
    expect(a(loaded: true, online: false), MapAvailability.offlineLimited);
    expect(a(loaded: true, online: false, saved: true), MapAvailability.offlineSaved);
    // Offline without a saved map: nothing will load.
    expect(a(online: false), MapAvailability.unavailable);
    // Offline with a saved map: the style may still come from it.
    expect(a(online: false, saved: true), MapAvailability.loading);
    expect(a(online: false, saved: true, timedOut: true), MapAvailability.unavailable);
    // Online, but the style never arrived.
    expect(a(online: true, timedOut: true), MapAvailability.unavailable);
  });
}
