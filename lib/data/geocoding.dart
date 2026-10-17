import 'dart:convert';

import 'package:http/http.dart' as http;

/// A place picked in the search. [lat]/[lng] are null when it is saved by
/// name only ("save without coordinates").
class PlaceResult {
  final String name;
  final String detail;
  final double? lat;
  final double? lng;
  const PlaceResult(this.name, this.detail, this.lat, this.lng);

  bool get hasLocation => lat != null && lng != null;

  /// The name as saved on the item ("name, detail").
  String get label => detail.isEmpty ? name : '$name, $detail';
}

/// Place search via Photon (OpenStreetMap data, no API key).
class Geocoder {
  final http.Client _client;
  Geocoder([http.Client? client]) : _client = client ?? http.Client();

  Future<List<PlaceResult>> search(String query, {String lang = 'en'}) async {
    if (query.trim().length < 2) return const [];
    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': query.trim(),
      'limit': '8',
      'lang': lang,
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
      out.add(PlaceResult(name, detail, coords[1].toDouble(), coords[0].toDouble()));
    }
    return out;
  }
}
