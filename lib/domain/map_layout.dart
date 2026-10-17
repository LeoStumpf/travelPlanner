// Map placement and interaction in pure Dart: spreading markers that share
// one spot, finding the marker next to a tap, deciding whether a selection
// needs the camera to move, and where "Navigation" leads.
import 'dart:math' as math;

import 'map_offline.dart';
import 'models.dart';

/// A marker to place: [lat]/[lng] is where the item really is (its own or
/// its stay's coordinates).
typedef MapMarker = ({String id, ItemKind kind, double lat, double lng});

/// Degrees of longitude one logical pixel spans at [zoom] (MapLibre's
/// 512-px tiles). Latitude degrees per pixel are this times cos(latitude).
double degreesPerPixel(double zoom) => 360 / (512 * math.pow(2, zoom));

/// Where to draw each marker so that items sharing the exact same position
/// (typically lodging and activities without own coordinates, which sit
/// on their stay) don't hide each other: the most important one (stay,
/// then accommodation, then activity; ties in input order) keeps the spot,
/// the others go on a ring [pixels] logical pixels around it at [zoom].
/// The ring starts top right and grows with the number of items, so
/// markers never touch; labels below the centre stay readable.
Map<String, (double, double)> spreadMarkers(List<MapMarker> markers, double zoom, {double pixels = 22}) {
  final groups = <(double, double), List<MapMarker>>{};
  for (final m in markers) {
    groups.putIfAbsent((m.lat, m.lng), () => []).add(m);
  }
  final out = <String, (double, double)>{};
  for (final MapEntry(key: (lat, lng), value: group) in groups.entries) {
    if (group.length == 1) {
      out[group.first.id] = (lat, lng);
      continue;
    }
    final ordered = [...group]..sort((a, b) => _rank(a.kind).compareTo(_rank(b.kind)));
    out[ordered.first.id] = (lat, lng);
    final ring = ordered.length - 1;
    // Neighbours on the ring stay at least [pixels] apart.
    final radius = math.max(pixels, pixels * ring / (2 * math.pi) * 1.2);
    final dLng = degreesPerPixel(zoom) * radius;
    final dLat = dLng * math.cos(lat * math.pi / 180);
    for (var k = 0; k < ring; k++) {
      final angle = math.pi / 4 - 2 * math.pi * k / ring; // clockwise from top right
      out[ordered[k + 1].id] = (
        (lat + dLat * math.sin(angle)).clamp(-maxMercatorLat, maxMercatorLat),
        lng + dLng * math.cos(angle),
      );
    }
  }
  return out;
}

int _rank(ItemKind k) => switch (k) {
      ItemKind.stay => 0,
      ItemKind.accommodation => 1,
      ItemKind.activity => 2,
      ItemKind.transport => 3,
    };

/// The marker whose screen point is closest to [tap], if within [radius]
/// (same units as the points). Lets a tap next to a small circle still
/// hit it.
String? nearestMarker(Map<String, (double, double)> screen, (double, double) tap, double radius) {
  String? best;
  var bestD = radius * radius;
  for (final MapEntry(key: id, value: (x, y)) in screen.entries) {
    final dx = x - tap.$1, dy = y - tap.$2;
    final d = dx * dx + dy * dy;
    if (d <= bestD) {
      best = id;
      bestD = d;
    }
  }
  return best;
}

/// Whether showing [points] needs the camera to move: true when any lies
/// outside [visible] shrunk by [margin] of its size on every side (so a
/// selection at the very edge, under the buttons, still gets centred).
bool needsPan(GeoBox visible, Iterable<(double, double)> points, {double margin = 0.12}) {
  final dLat = (visible.north - visible.south) * margin;
  final dLng = (visible.east - visible.west) * margin;
  final inner = GeoBox(visible.south + dLat, visible.west + dLng, visible.north - dLat, visible.east - dLng);
  return points.any((p) => !inner.containsPoint(p.$1, p.$2));
}

/// The points the map shows for [item]: its position, or both ends of a
/// transport (those with coordinates).
List<(double, double)> focusPoints(TripData data, PlanItem item) {
  if (item.kind == ItemKind.transport) {
    return [
      for (final end in [data.item(item.fromId), data.item(item.toId)])
        if (end != null) ?itemPosition(data, end),
    ];
  }
  final p = itemPosition(data, item);
  return p == null ? const [] : [p];
}

/// Where "Navigation" leads for [item]: its coordinates (own or its stay's),
/// otherwise its address as a search. A transport leads to its departure,
/// where one has to get to: the departure station as a search when given
/// (more precise than the city's coordinates, "station, city"), else its
/// origin stay. Null when nothing is known.
({(double, double)? at, String? query, String label})? navigationTarget(TripData data, PlanItem item) {
  if (item.kind == ItemKind.transport) {
    final from = data.item(item.fromId);
    final station = item.departureStation?.trim();
    if (station != null && station.isNotEmpty) {
      final city = from?.title.trim();
      final q = city == null || city.isEmpty || station.toLowerCase().contains(city.toLowerCase())
          ? station
          : '$station, $city';
      return (at: null, query: q, label: station);
    }
    return from == null ? null : navigationTarget(data, from);
  }
  final at = itemPosition(data, item);
  final place = item.placeName?.trim();
  if (at == null && (place == null || place.isEmpty)) return null;
  return (at: at, query: at == null ? place : null, label: item.title);
}

/// URIs to try in order for navigating to [target]: a geo: URI, which
/// opens the maps app the user picked (Google Maps, OsmAnd, Organic Maps,
/// …), then Google Maps directions on the web as a fallback.
List<Uri> navigationUris(({(double, double)? at, String? query, String label}) target) {
  final at = target.at;
  if (at != null) {
    final ll = '${at.$1},${at.$2}';
    return [
      Uri.parse('geo:$ll?q=$ll(${Uri.encodeComponent(target.label)})'),
      Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': ll}),
    ];
  }
  final q = target.query!;
  return [
    Uri.parse('geo:0,0?q=${Uri.encodeComponent(q)}'),
    Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': q}),
  ];
}
