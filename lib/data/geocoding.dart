import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models.dart';
import '../domain/places.dart';

/// A place picked in the search. [lat]/[lng] are null when it is saved by
/// name only ("save without coordinates").
class PlaceResult {
  final String name;
  final String detail;
  final double? lat;
  final double? lng;

  /// The country Photon reports, if any.
  final String? country;
  const PlaceResult(this.name, this.detail, this.lat, this.lng, {this.country});

  bool get hasLocation => lat != null && lng != null;

  /// The name as saved on the item ("name, detail").
  String get label => detail.isEmpty ? name : '$name, $detail';
}

/// Place search via Photon (OpenStreetMap data, no API key).
class Geocoder {
  final http.Client _client;
  Geocoder([http.Client? client]) : _client = client ?? http.Client();

  /// Searches [query]; with a [bias], results near it rank higher.
  Future<List<PlaceResult>> search(String query, {String lang = 'en', GeoBias? bias}) async {
    if (query.trim().length < 2) return const [];
    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': query.trim(),
      'limit': '8',
      'lang': lang,
      if (bias != null) ...{
        'lat': bias.lat.toStringAsFixed(5),
        'lon': bias.lng.toStringAsFixed(5),
        'zoom': '${bias.zoom}',
        'location_bias_scale': '0.5',
      },
    });
    final res = await _client
        .get(uri, headers: {'User-Agent': 'TravelPlanner/1.0 (Flutter app)'})
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('Place search failed (${res.statusCode})');
    }
    return parsePhoton(res.body);
  }

  /// Follows the redirects of a short map link (maps.app.goo.gl/…) to the
  /// full link, which carries the coordinates. Needs a connection.
  Future<String> expand(String link) async {
    var uri = Uri.parse(link.trim());
    for (var hop = 0; hop < 6; hop++) {
      final req = http.Request('GET', uri)
        ..followRedirects = false
        ..headers['User-Agent'] = 'TravelPlanner/1.0 (Flutter app)';
      final res = await _client.send(req).timeout(const Duration(seconds: 10));
      final location = res.headers['location'];
      await res.stream.drain<void>();
      if (res.statusCode < 300 || res.statusCode >= 400 || location == null) break;
      uri = uri.resolve(location);
    }
    return uri.toString();
  }

  static List<PlaceResult> parsePhoton(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final out = <PlaceResult>[];
    for (final f in (json['features'] as List? ?? const [])) {
      final coords = (f['geometry']?['coordinates'] as List?)?.cast<num>();
      final props = (f['properties'] as Map?)?.cast<String, dynamic>() ?? const {};
      if (coords == null || coords.length < 2) continue;
      final name = (props['name'] ?? props['city'] ?? props['street'] ?? '?') as String;
      final detail = [
        props['city'],
        props['state'],
        props['country'],
      ].whereType<String>().where((s) => s != name).toSet().join(', ');
      out.add(PlaceResult(name, detail, coords[1].toDouble(), coords[0].toDouble(),
          country: props['country'] as String?));
    }
    return out;
  }
}

/// The outcome of [fillCoordinates].
class GeocodeOutcome {
  /// The items, with coordinates where a place was found.
  final List<PlanItem> items;

  /// Items that were looked up.
  final List<PlanItem> searched;

  /// Looked-up items for which nothing was found (or the search failed).
  final List<PlanItem> notFound;
  const GeocodeOutcome(this.items, this.searched, this.notFound);
}

/// Looks up missing coordinates of [items] ([geoQuery]). Searches lean
/// towards the trip: an item's located stay, else the middle of all located
/// places of [items] and [context] (the rest of the trip), and among the
/// results one in a country the trip already visits wins. Stays go first, so
/// their activities can lean on them. Failed lookups are reported, not thrown;
/// after two failures in a row the remaining items are not searched.
Future<GeocodeOutcome> fillCoordinates(
  List<PlanItem> items,
  Geocoder geocoder, {
  Iterable<PlanItem> context = const [],
  String lang = 'en',
}) async {
  final byId = {for (final i in context) i.id: i, for (final i in items) i.id: i};
  final countries = tripCountries(byId.values);
  final trip = tripBias(byId.values);
  final cache = <String, PlaceResult?>{};
  final searched = <PlanItem>[], notFound = <PlanItem>[];
  // After two failed requests in a row the network is taken as down: the
  // rest is reported as not found instead of waiting for each timeout.
  var failures = 0;
  final todo = [
    for (final i in items) if (geoQuery(i) != null && i.kind == ItemKind.stay) i,
    for (final i in items) if (geoQuery(i) != null && i.kind != ItemKind.stay) i,
  ];
  for (final i in todo) {
    final q = geoQuery(i)!;
    final bias = biasFor(i, byId, trip);
    final key = '$q|$bias';
    searched.add(i);
    if (!cache.containsKey(key) && failures < 2) {
      try {
        final results = await geocoder.search(q, lang: lang, bias: bias);
        failures = 0;
        cache[key] = results.where((r) => countries.contains(r.country?.toLowerCase())).firstOrNull ??
            results.firstOrNull;
      } catch (_) {
        failures++;
        cache[key] = null;
      }
    }
    final r = cache[key];
    if (r == null || !r.hasLocation) {
      notFound.add(i);
    } else {
      byId[i.id] = i.copyWith(lat: r.lat, lng: r.lng);
    }
  }
  return GeocodeOutcome([for (final i in items) byId[i.id]!], searched, notFound);
}
