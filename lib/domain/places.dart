import 'models.dart';

/// What a pasted map link or typed coordinate pair says about a place.
/// [lat]/[lng] are null when the link only names the place (it then needs
/// a search); both [name] and the coordinates are null for a map link that
/// carries neither.
class ParsedPlace {
  final double? lat;
  final double? lng;
  final String? name;
  const ParsedPlace({this.lat, this.lng, this.name});

  bool get hasLocation => lat != null && lng != null;

  @override
  bool operator ==(Object other) => other is ParsedPlace && other.lat == lat && other.lng == lng && other.name == name;

  @override
  int get hashCode => Object.hash(lat, lng, name);

  @override
  String toString() => 'ParsedPlace($lat, $lng, $name)';
}

/// Reads raw coordinates ("48.8584, 2.2945", "48°51'30\"N 2°17'40\"E",
/// "N 48.8584 E 2.2945") and map links (Google Maps, OpenStreetMap, Apple
/// Maps, geo: URIs). Returns null when [input] is neither, i.e. plain text
/// to search for. Short links ([isShortMapLink]) need expanding first.
ParsedPlace? parsePlaceInput(String input) {
  final s = input.trim();
  if (s.isEmpty) return null;
  final pair = parseCoordinates(s);
  if (pair != null) return ParsedPlace(lat: pair.$1, lng: pair.$2);
  final uri = Uri.tryParse(s);
  if (uri == null) return null;
  if (uri.scheme == 'geo') return _parseGeo(uri);
  if ((uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty) return _parseWeb(uri);
  return null;
}

/// Shortened map links that only an online redirect turns into coordinates.
bool isShortMapLink(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) return false;
  final host = uri.host.toLowerCase();
  return host == 'maps.app.goo.gl' ||
      (host == 'goo.gl' && uri.path.startsWith('/maps')) ||
      (host == 'g.co' && uri.path.startsWith('/kgs')) ||
      ((host == 'osm.org' || host.endsWith('openstreetmap.org')) && uri.path.startsWith('/go/'));
}

// --- coordinates --------------------------------------------------------------

const _num = r'(-?\d{1,3}(?:\.\d+)?)';
const _dms = '$_num\\s*(?:°\\s*(?:(\\d{1,2}(?:\\.\\d+)?)\\s*[\'′]\\s*(?:(\\d{1,2}(?:\\.\\d+)?)\\s*(?:["″]|\'\')\\s*)?)?)?';
const _sep = r'\s*[,;/]?\s*';
final _suffixPair = RegExp('^$_dms([NSEWnsew])?$_sep$_dms([NSEWnsew])?\$');
final _prefixPair = RegExp('^([NSEWnsew])\\s*$_dms$_sep([NSEWnsew])\\s*$_dms\$');

/// A latitude/longitude pair in decimal degrees, or null. Each half needs a
/// decimal point, a degree sign or a hemisphere letter, so "Route 66 1" or a
/// house number never counts as coordinates.
(double, double)? parseCoordinates(String input) {
  final s = input.trim();
  final prefix = _prefixPair.firstMatch(s);
  final suffix = prefix == null ? _suffixPair.firstMatch(s) : null;
  final m = prefix ?? suffix;
  if (m == null) return null;

  ({double value, String? hemi, bool precise}) part(int numGroup, int hemiGroup) {
    final deg = double.parse(m.group(numGroup)!);
    final min = double.tryParse(m.group(numGroup + 1) ?? '') ?? 0;
    final sec = double.tryParse(m.group(numGroup + 2) ?? '') ?? 0;
    final abs = deg.abs() + min / 60 + sec / 3600;
    final hemi = m.group(hemiGroup)?.toUpperCase();
    final whole = m.group(0)!;
    final precise = m.group(numGroup)!.contains('.') || hemi != null || whole.contains('°');
    return (value: deg < 0 ? -abs : abs, hemi: hemi, precise: precise);
  }

  final a = prefix != null ? part(2, 1) : part(1, 4);
  final b = prefix != null ? part(6, 5) : part(5, 8);
  if (!a.precise || !b.precise) return null;
  double signed(({double value, String? hemi, bool precise}) p) =>
      p.hemi == 'S' || p.hemi == 'W' ? -p.value.abs() : p.value;
  var lat = signed(a), lng = signed(b);
  bool isLat(String? h) => h == 'N' || h == 'S';
  bool isLng(String? h) => h == 'E' || h == 'W';
  if (isLng(a.hemi) || isLat(b.hemi)) {
    // Longitude first ("2.29E 48.85N"): fine unless the letters clash.
    if (isLat(a.hemi) || isLng(b.hemi)) return null;
    (lat, lng) = (lng, lat);
  }
  return _valid(lat, lng);
}

(double, double)? _valid(double lat, double lng) =>
    lat.abs() <= 90 && lng.abs() <= 180 && !(lat == 0 && lng == 0) ? (lat, lng) : null;

// --- links --------------------------------------------------------------------

final _parenName = RegExp(r'^(.*?)\s*\((.*)\)\s*$');

ParsedPlace _parseGeo(Uri uri) {
  // geo:lat,lng[,alt][;u=…]?q=lat,lng(Label) | geo:0,0?q=Some+address
  final path = uri.path.split(';').first;
  final parts = path.split(',');
  final pathAt = parts.length >= 2 ? _pair(parts[0], parts[1]) : null;
  final q = _query(uri, 'q');
  String? name;
  (double, double)? qAt;
  if (q != null && q.isNotEmpty) {
    final m = _parenName.firstMatch(q);
    final head = m?.group(1) ?? q;
    final label = m?.group(2);
    qAt = parseCoordinates(head);
    name = (label != null && label.isNotEmpty) ? label : (qAt == null ? head : null);
  }
  final at = qAt ?? pathAt;
  return ParsedPlace(lat: at?.$1, lng: at?.$2, name: _clean(name));
}

final _googlePin = RegExp(r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)');
final _atViewport = RegExp(r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)');
final _osmHash = RegExp(r'map=\d+(?:\.\d+)?/(-?\d+(?:\.\d+)?)/(-?\d+(?:\.\d+)?)');

ParsedPlace? _parseWeb(Uri uri) {
  final host = uri.host.toLowerCase();
  final google = host.contains('google.') || host == 'goo.gl' || host.endsWith('.goo.gl');
  final osm = host.endsWith('openstreetmap.org') || host == 'osm.org';
  final apple = host == 'maps.apple.com';
  final String path;
  try {
    path = Uri.decodeFull(uri.path);
  } on FormatException {
    return null; // broken escapes ("%FF"): just text to search for
  }
  final googleMaps = google && (host.startsWith('maps.') || host.endsWith('goo.gl') || path.startsWith('/maps'));
  if (!googleMaps && !osm && !apple) return null;

  (double, double)? at;
  String? name;

  // Google: the pin (!3d…!4d…) beats the viewport centre (@lat,lng).
  final pin = _googlePin.firstMatch(uri.toString());
  if (pin != null) at = _pair(pin.group(1)!, pin.group(2)!);

  if (osm) {
    final mlat = _query(uri, 'mlat'), mlon = _query(uri, 'mlon');
    if (mlat != null && mlon != null) at ??= _pair(mlat, mlon);
    final hash = _osmHash.firstMatch(uri.fragment);
    if (hash != null) at ??= _pair(hash.group(1)!, hash.group(2)!);
  }

  for (final key in const ['q', 'query', 'll', 'sll', 'center', 'destination', 'daddr', 'saddr', 'coordinate']) {
    final v = _query(uri, key);
    if (v == null || v.isEmpty) continue;
    final c = parseCoordinates(v.replaceFirst(RegExp(r'^loc:'), ''));
    if (c != null) {
      at ??= c;
    } else if (key == 'q' || key == 'query' || key == 'destination' || key == 'daddr') {
      name ??= v;
    }
  }

  // /maps/place/<name or coords>/…, /maps/search/<…>/, /maps/dir/<a>/<b>
  final segs = path.split('/').where((s) => s.isNotEmpty).toList();
  final i = segs.indexWhere((s) => s == 'place' || s == 'search');
  if (i >= 0 && i + 1 < segs.length && !segs[i + 1].startsWith('@')) {
    final seg = segs[i + 1].replaceAll('+', ' ');
    final c = parseCoordinates(seg);
    if (c != null) {
      at ??= c;
    } else {
      name ??= seg;
    }
  }

  final view = _atViewport.firstMatch(path);
  if (view != null) at ??= _pair(view.group(1)!, view.group(2)!);

  return ParsedPlace(lat: at?.$1, lng: at?.$2, name: _clean(name));
}

(double, double)? _pair(String a, String b) {
  final lat = double.tryParse(a.trim()), lng = double.tryParse(b.trim());
  return lat == null || lng == null ? null : _valid(lat, lng);
}

String? _query(Uri uri, String key) {
  try {
    return uri.queryParameters[key];
  } on FormatException {
    return null;
  }
}

String? _clean(String? name) {
  final n = name?.replaceAll('+', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return n == null || n.isEmpty ? null : n;
}

// --- recently used places -----------------------------------------------------

/// A located item of some trip and when it was last saved.
class PlaceUse {
  final PlanItem item;
  final String tripTitle;
  final DateTime usedAt;
  const PlaceUse(this.item, this.tripTitle, this.usedAt);
}

/// A place used before, offered again by the place search (works offline).
class KnownPlace {
  final String name;
  final String detail;
  final double lat;
  final double lng;
  final String tripTitle;
  final DateTime usedAt;
  const KnownPlace(this.name, this.detail, this.lat, this.lng, this.tripTitle, this.usedAt);

  /// The place name as it was saved ("name, detail").
  String get label => detail.isEmpty ? name : '$name, $detail';
}

/// The places of [uses], newest first, one per spot (~10 m), limited to
/// [limit]. With a [query], only places whose name, detail or trip contain
/// every word of it. Place names in [generic] ("Picked on the map") say
/// nothing, so the item title stands in for them.
List<KnownPlace> recentPlaces(
  Iterable<PlaceUse> uses, {
  String query = '',
  int limit = 20,
  Set<String> generic = const {},
}) {
  final sorted = [for (final u in uses) if (u.item.hasLocation) u]..sort((a, b) => b.usedAt.compareTo(a.usedAt));
  final words = query.toLowerCase().split(RegExp(r'[\s,]+')).where((w) => w.isNotEmpty).toList();
  final seen = <String>{};
  final out = <KnownPlace>[];
  for (final u in sorted) {
    final i = u.item;
    final key = '${i.lat!.toStringAsFixed(4)},${i.lng!.toStringAsFixed(4)}';
    if (!seen.add(key)) continue;
    final saved = i.placeName?.trim() ?? '';
    final String name, detail;
    if (saved.isEmpty || generic.contains(saved)) {
      name = i.title.trim().isEmpty ? key : i.title.trim();
      detail = '';
    } else {
      final cut = saved.indexOf(', ');
      name = cut < 0 ? saved : saved.substring(0, cut);
      detail = cut < 0 ? '' : saved.substring(cut + 2);
    }
    final hay = '$name $detail ${i.title} ${u.tripTitle}'.toLowerCase();
    if (!words.every(hay.contains)) continue;
    out.add(KnownPlace(name, detail, i.lat!, i.lng!, u.tripTitle, u.usedAt));
    if (out.length >= limit) break;
  }
  return out;
}

// --- geocoding a plan -----------------------------------------------------------

/// Where a place search should look first (Photon's location bias). A
/// higher [zoom] keeps results closer to the point.
class GeoBias {
  final double lat;
  final double lng;
  final int zoom;
  const GeoBias(this.lat, this.lng, this.zoom);

  @override
  bool operator ==(Object other) => other is GeoBias && other.lat == lat && other.lng == lng && other.zoom == zoom;

  @override
  int get hashCode => Object.hash(lat, lng, zoom);

  @override
  String toString() => 'GeoBias($lat, $lng, z$zoom)';
}

/// The search text for an item that still lacks coordinates: its place, or
/// a stay's title. Null if it has coordinates, is a transport or has no
/// usable name.
String? geoQuery(PlanItem i) {
  if (i.hasLocation || i.kind == ItemKind.transport) return null;
  final q = i.placeName ?? (i.kind == ItemKind.stay ? i.title : null);
  return q == null || q.trim().length < 2 ? null : q.trim();
}

/// The middle of the trip's located [items] (median latitude and
/// longitude, so one far-off place does not drag it into the sea), as a
/// country-scale bias. Null without any located item.
GeoBias? tripBias(Iterable<PlanItem> items) {
  final located = [for (final i in items) if (i.hasLocation) i];
  if (located.isEmpty) return null;
  double median(List<double> v) {
    v.sort();
    final m = v.length ~/ 2;
    return v.length.isOdd ? v[m] : (v[m - 1] + v[m]) / 2;
  }

  return GeoBias(
    median([for (final i in located) i.lat!]),
    median([for (final i in located) i.lng!]),
    5,
  );
}

/// The bias for looking up [item]: the located stay it belongs to (city
/// scale), else the trip's [fallback].
GeoBias? biasFor(PlanItem item, Map<String, PlanItem> byId, GeoBias? fallback) {
  final p = byId[item.parentId];
  if (p != null && p.hasLocation) return GeoBias(p.lat!, p.lng!, 11);
  return fallback;
}

/// The country of a saved place name ("Kandy, Central Province, Sri Lanka"
/// → "Sri Lanka"): its last part, if it has more than one.
String? countryOf(String? placeName) {
  final parts = (placeName ?? '').split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  return parts.length < 2 ? null : parts.last;
}

/// The countries the trip's located [items] lie in, by their place names.
Set<String> tripCountries(Iterable<PlanItem> items) => {
      for (final i in items)
        if (i.hasLocation)
          if (countryOf(i.placeName) case final c?) c.toLowerCase(),
    };
