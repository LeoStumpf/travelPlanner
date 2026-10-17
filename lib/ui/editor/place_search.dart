import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/geocoding.dart';
import '../../domain/places.dart';
import '../../state/providers.dart';
import '../common/l10n.dart';

/// Full-screen place search (OpenStreetMap / Photon). Returns the chosen
/// place; one without coordinates when the user saves the name only.
/// Offline it still offers recently used places, pasted map links and
/// typed coordinates.
Future<PlaceResult?> searchPlace(BuildContext context, {String initial = ''}) =>
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PlaceSearchPage(initial: initial),
    ));

class PlaceSearchPage extends ConsumerStatefulWidget {
  final String initial;
  const PlaceSearchPage({super.key, this.initial = ''});

  @override
  ConsumerState<PlaceSearchPage> createState() => _PlaceSearchPageState();
}

class _PlaceSearchPageState extends ConsumerState<PlaceSearchPage> {
  late final _ctrl = TextEditingController(text: widget.initial);
  Timer? _debounce;
  List<PlaceResult> _results = const [];
  String? _error;
  bool _loading = false;
  int _req = 0;

  /// The text the shown [_results] belong to (null before any search).
  String? _searched;

  /// A short link and what its expanded form says.
  String? _expandedFor;
  ParsedPlace? _expanded;

  /// "Picked on the map" in every language: says nothing as a place name.
  static final _generic = {
    for (final loc in AppLocalizations.supportedLocales) lookupAppLocalizations(loc).pickedOnMap,
  };

  @override
  void initState() {
    super.initState();
    if (widget.initial.isNotEmpty) _search(widget.initial);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    setState(() {}); // links, coordinates and recent places need no wait
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String raw) async {
    final q = raw.trim();
    final req = ++_req;
    final lang = context.l10n.localeName;
    final geocoder = ref.read(geocoderProvider);
    setState(() {
      _error = null;
      _results = const [];
      _searched = null;
    });
    if (q.isEmpty) return;

    var parsed = parsePlaceInput(q);
    if (isShortMapLink(q)) {
      setState(() => _loading = true);
      try {
        final full = await geocoder.expand(q);
        if (req != _req || !mounted) return;
        parsed = parsePlaceInput(full) ?? const ParsedPlace();
        setState(() {
          _expandedFor = q;
          _expanded = parsed;
        });
      } catch (_) {
        if (req == _req && mounted) {
          setState(() {
            _error = context.l10n.placeShortLinkOffline;
            _loading = false;
          });
        }
        return;
      }
    }
    // Coordinates are all we need; a link with a name only is searched by it.
    final text = parsed == null ? q : (parsed.hasLocation ? null : parsed.name);
    if (text == null || text.length < 2) {
      if (req == _req && mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await geocoder.search(text, lang: lang);
      if (req == _req && mounted) {
        setState(() {
          _results = r;
          _searched = q;
        });
      }
    } catch (e) {
      if (req == _req && mounted) setState(() => _error = context.l10n.placeSearchFailed);
    } finally {
      if (req == _req && mounted) setState(() => _loading = false);
    }
  }

  static String _coords(double lat, double lng) => '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final q = _ctrl.text.trim();
    final short = isShortMapLink(q);
    final parsed = short ? (_expandedFor == q ? _expanded : null) : parsePlaceInput(q);
    final isPlainText = q.isNotEmpty && !short && parsed == null;
    final uses = ref.watch(placeUsesProvider).value ?? const <PlaceUse>[];
    final recent = q.isEmpty || isPlainText
        ? recentPlaces(uses, query: q, limit: q.isEmpty ? 20 : 5, generic: _generic)
        : const <KnownPlace>[];
    final noHits = !_loading && _error == null && _searched == q && _results.isEmpty;
    final small = theme.textTheme.bodySmall;

    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        );

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          key: const ValueKey('place-query'),
          controller: _ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: l.placeSearchHint, border: InputBorder.none),
          onChanged: _onChanged,
          onSubmitted: (v) {
            _debounce?.cancel();
            _search(v);
          },
        ),
        bottom: _loading
            ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2))
            : null,
      ),
      body: ListView(
        children: [
          if (_error != null)
            ListTile(
              key: const ValueKey('place-error'),
              leading: const Icon(Icons.cloud_off),
              title: Text(_error!),
              subtitle: Text(l.placeOfflineHint),
            ),
          if (parsed != null && parsed.hasLocation)
            ListTile(
              key: const ValueKey('place-from-input'),
              leading: const Icon(Icons.my_location),
              title: Text(parsed.name ?? _coords(parsed.lat!, parsed.lng!)),
              subtitle: Text(parsed.name == null
                  ? l.placeUseCoordinates
                  : '${l.placeFromLink} · ${_coords(parsed.lat!, parsed.lng!)}'),
              onTap: () => Navigator.pop(
                context,
                PlaceResult(parsed.name ?? _coords(parsed.lat!, parsed.lng!), '', parsed.lat, parsed.lng),
              ),
            ),
          if (parsed != null && !parsed.hasLocation && parsed.name == null && !_loading)
            ListTile(
              key: const ValueKey('place-link-empty'),
              leading: const Icon(Icons.link_off),
              title: Text(l.placeLinkNoCoordinates),
              subtitle: Text(l.placePasteHint),
            ),
          for (final r in _results)
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(r.name),
              subtitle: r.detail.isEmpty ? null : Text(r.detail),
              onTap: () => Navigator.pop(context, r),
            ),
          if (noHits)
            ListTile(
              key: const ValueKey('place-no-results'),
              leading: const Icon(Icons.search_off),
              title: Text(l.placeNoResults(parsed?.name ?? q)),
              subtitle: Text(l.placeNoResultsHint),
            ),
          if (recent.isNotEmpty) ...[
            header(l.placeRecent),
            for (final p in recent)
              ListTile(
                key: ValueKey('recent-${p.label}'),
                leading: const Icon(Icons.history),
                title: Text(p.name),
                subtitle: Text([if (p.detail.isNotEmpty) p.detail, p.tripTitle].join(' · ')),
                onTap: () => Navigator.pop(context, PlaceResult(p.name, p.detail, p.lat, p.lng)),
              ),
          ],
          if (isPlainText) ...[
            const Divider(),
            ListTile(
              key: const ValueKey('place-without-coordinates'),
              leading: const Icon(Icons.edit_location_alt_outlined),
              title: Text(l.placeSaveWithoutCoordinates(q)),
              subtitle: Text(l.placeSaveWithoutCoordinatesHint),
              onTap: () => Navigator.pop(context, PlaceResult(q, '', null, null)),
            ),
          ],
          if (q.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(l.placePasteHint, style: small),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l.osmAttribution, style: const TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
