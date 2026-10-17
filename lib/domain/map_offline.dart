// Offline map support in pure Dart: which area of the map a trip needs, how
// many tiles that is at which zooms, and what the map view should tell the
// user when the online style or tiles can't be reached.
import 'dart:math' as math;

import 'models.dart';

/// A latitude/longitude rectangle (degrees). Does not wrap around the
/// antimeridian: a trip across it spans the whole width instead.
class GeoBox {
  final double south, west, north, east;
  const GeoBox(this.south, this.west, this.north, this.east);

  /// Smallest box around [points] (lat, lng); null when there are none.
  static GeoBox? around(Iterable<(double, double)> points) {
    GeoBox? box;
    for (final (lat, lng) in points) {
      box = box == null
          ? GeoBox(lat, lng, lat, lng)
          : GeoBox(
              math.min(box.south, lat),
              math.min(box.west, lng),
              math.max(box.north, lat),
              math.max(box.east, lng),
            );
    }
    return box;
  }

  /// Grown by [fraction] of its size on every side, at least [minDegrees];
  /// clamped to what Web-Mercator maps can show.
  GeoBox padded({double fraction = 0.1, double minDegrees = 0.1}) {
    final dLat = math.max((north - south) * fraction, minDegrees);
    final dLng = math.max((east - west) * fraction, minDegrees);
    return GeoBox(
      math.max(south - dLat, -maxMercatorLat),
      math.max(west - dLng, -180),
      math.min(north + dLat, maxMercatorLat),
      math.min(east + dLng, 180),
    );
  }

  bool contains(GeoBox o) => o.south >= south && o.north <= north && o.west >= west && o.east <= east;

  bool containsPoint(double lat, double lng) => lat >= south && lat <= north && lng >= west && lng <= east;

  /// [south, west, north, east], as stored in offline region metadata.
  List<double> toList() => [south, west, north, east];

  static GeoBox? fromList(Object? json) {
    if (json is! List || json.length != 4 || json.any((v) => v is! num)) return null;
    final v = [for (final n in json) (n as num).toDouble()];
    return GeoBox(v[0], v[1], v[2], v[3]);
  }

  @override
  bool operator ==(Object other) =>
      other is GeoBox && other.south == south && other.west == west && other.north == north && other.east == east;

  @override
  int get hashCode => Object.hash(south, west, north, east);

  @override
  String toString() => 'GeoBox($south, $west, $north, $east)';
}

const maxMercatorLat = 85.05112878;

/// Where [item] sits on the map: its own coordinates, or those of its stay
/// (lodging and activities without an own place).
(double, double)? itemPosition(TripData data, PlanItem item) {
  if (item.hasLocation) return (item.lat!, item.lng!);
  final p = data.item(item.parentId);
  if (p != null && p.hasLocation) return (p.lat!, p.lng!);
  return null;
}

/// The area covering every place of the trip (unpadded); null without any.
GeoBox? placesBox(TripData data) => GeoBox.around([
  for (final i in data.items)
    if (i.kind != ItemKind.transport) ?itemPosition(data, i),
]);

/// Number of map tiles covering [box] at zoom levels [minZoom]..[maxZoom].
int tileCount(GeoBox box, int minZoom, int maxZoom) {
  var total = 0;
  for (var z = minZoom; z <= maxZoom; z++) {
    final (x0, y0) = _tile(box.north, box.west, z);
    final (x1, y1) = _tile(box.south, box.east, z);
    total += (x1 - x0 + 1) * (y1 - y0 + 1);
  }
  return total;
}

(int, int) _tile(double lat, double lng, int z) {
  final n = 1 << z;
  final x = ((lng + 180) / 360 * n).floor().clamp(0, n - 1);
  final r = lat.clamp(-maxMercatorLat, maxMercatorLat) * math.pi / 180;
  final y = ((1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) / 2 * n).floor().clamp(0, n - 1);
  return (x, y);
}

/// One area to download at a zoom range.
class RegionSpec {
  /// `overview` for the whole trip, `stay` for the surroundings of a stay.
  final String part;
  final GeoBox box;
  final int minZoom, maxZoom;
  const RegionSpec(this.part, this.box, this.minZoom, this.maxZoom);

  int get tiles => tileCount(box, minZoom, maxZoom);

  @override
  String toString() => 'RegionSpec($part, $box, z$minZoom-$maxZoom)';
}

/// What "save map offline" downloads for a trip.
class OfflinePlan {
  /// The padded area of the whole trip; a saved map covers the trip as long
  /// as all places still lie inside it.
  final GeoBox box;
  final List<RegionSpec> regions;
  const OfflinePlan(this.box, this.regions);

  int get tiles => regions.fold(0, (s, r) => s + r.tiles);

  /// Rough download size: OpenFreeMap vector tiles average a few dozen KB,
  /// plus style, fonts and sprites once.
  int get estimatedBytes => tiles * avgTileBytes + styleBytes;

  static const avgTileBytes = 30 * 1024;
  static const styleBytes = 2 * 1024 * 1024;
}

/// Highest zoom the vector tiles exist at; the map overzooms beyond it, so
/// streets stay readable at closer zooms too.
const maxTileZoom = 14;

/// Tiles one trip may download. MapLibre's own default limit is 6000 tiles
/// for all regions together; the app raises it (see the offline store), but
/// a trip stays well below to keep downloads at a few dozen MB.
const tileBudget = 6000;

/// Download plan: the whole trip at overview zooms (as close as the budget
/// allows, at most z11) plus the surroundings (~5 km) of every stay down to
/// street level (z14). Null when the trip has no places yet.
OfflinePlan? planOfflineMap(TripData data, {int budget = tileBudget}) {
  final places = placesBox(data);
  if (places == null) return null;
  final box = places.padded();

  // Overview: the deepest zoom that keeps it at 60 % of the budget.
  var overviewMax = 3;
  for (var z = 11; z >= 3; z--) {
    if (tileCount(box, 0, z) <= budget * 0.6) {
      overviewMax = z;
      break;
    }
  }
  final overview = RegionSpec('overview', box, 0, overviewMax);

  // Detail around each stay; stays a few hundred metres apart share one.
  final centres = <(double, double)>{};
  for (final s in data.items.where((i) => i.kind == ItemKind.stay && i.hasLocation)) {
    centres.add(((s.lat! * 100).round() / 100, (s.lng! * 100).round() / 100));
  }
  final boxes = [
    for (final (lat, lng) in centres)
      () {
        const dLat = 0.05;
        final dLng = dLat / math.max(math.cos(lat * math.pi / 180), 0.2);
        return GeoBox(lat - dLat, lng - dLng, lat + dLat, lng + dLng).padded(fraction: 0, minDegrees: 0);
      }(),
  ];
  final remaining = budget - overview.tiles;
  for (var detailMax = maxTileZoom; detailMax > overviewMax; detailMax--) {
    final details = [for (final b in boxes) RegionSpec('stay', b, overviewMax + 1, detailMax)];
    if (details.fold(0, (s, r) => s + r.tiles) <= remaining) return OfflinePlan(box, [overview, ...details]);
  }
  return OfflinePlan(box, [overview]);
}

/// What the map view shows about its own state.
enum MapAvailability {
  /// Style still loading, nothing to say yet.
  loading,

  /// Online and loaded.
  ok,

  /// No connection, but the trip's map is saved offline.
  offlineSaved,

  /// No connection; the style came from the cache, tiles may be missing.
  offlineLimited,

  /// The map can't be shown: style never loaded.
  unavailable,
}

/// [online] is null while the connection check is still running. A saved
/// offline map lets the style load without connection, so the view waits
/// for it until [styleTimedOut].
MapAvailability mapAvailability({
  required bool styleLoaded,
  required bool styleTimedOut,
  required bool? online,
  required bool saved,
}) {
  if (styleLoaded) {
    if (online == false) return saved ? MapAvailability.offlineSaved : MapAvailability.offlineLimited;
    return MapAvailability.ok;
  }
  if (styleTimedOut || (online == false && !saved)) return MapAvailability.unavailable;
  return MapAvailability.loading;
}
