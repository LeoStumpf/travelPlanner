import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../data/location.dart';
import '../../data/offline_maps.dart';
import '../../domain/analysis.dart';
import '../../domain/map_layout.dart';
import '../../domain/map_offline.dart';
import '../../domain/models.dart';
import '../../domain/zones.dart';
import '../../state/hints.dart';
import '../../state/offline_map.dart';
import '../../state/providers.dart';
import '../common/hint_banner.dart';
import '../common/item_sheet.dart';
import '../common/l10n.dart';
import '../common/style.dart';
import '../editor/item_editor_page.dart';
import 'offline_map_sheet.dart';
import 'places_list.dart';

/// False in widget tests: an empty surface stands in for the MapLibre
/// platform view, whose style then never loads.
final nativeMapProvider = Provider<bool>((ref) => true);

/// How long the style may take before the map counts as unavailable. The
/// plugin reports no load errors, so silence is the only signal.
const mapStyleTimeout = Duration(seconds: 12);

/// How far from a marker a tap still selects it, in logical pixels.
const markerHitRadius = 26.0;

class TripMapView extends ConsumerStatefulWidget {
  final TripData data;
  final bool active;
  const TripMapView({super.key, required this.data, required this.active});

  @override
  ConsumerState<TripMapView> createState() => _TripMapViewState();
}

class _TripMapViewState extends ConsumerState<TripMapView> {
  MapLibreMapController? _map;
  bool _styleReady = false;
  bool _fitted = false;
  Future<void> _drawing = Future.value();

  // Offline detection: style loaded, waited too long for it, server reachable
  // (null while asking). [_generation] keys the map, so "try again" rebuilds
  // it and makes MapLibre request the style anew.
  bool _styleLoaded = false;
  bool _styleTimedOut = false;
  bool? _online;
  int _generation = 0;
  Timer? _styleTimer;
  late final AppLifecycleListener _lifecycle;

  // Where each marker was drawn (spread apart when sharing a spot) and at
  // which whole zoom the spreading was computed.
  Map<String, LatLng> _drawn = const {};
  int _spreadZoom = -1;

  // "My location": the last fix, whether a request is running, updates
  // while the map is showing, and the blue dot.
  LatLng? _me;
  bool _locating = false;
  StreamSubscription<(double, double)>? _meUpdates;
  Circle? _meCircle;

  TripData get data => widget.data;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (!widget.active) return;
        _probe();
        if (_me != null) _watchMe();
      },
      // No GPS while the app is in the background.
      onPause: _stopWatchingMe,
    );
    _startStyleTimer();
    _probe();
  }

  @override
  void dispose() {
    _styleTimer?.cancel();
    _meUpdates?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  void _startStyleTimer() {
    _styleTimer?.cancel();
    _styleTimer = Timer(mapStyleTimeout, () {
      if (mounted && !_styleLoaded) setState(() => _styleTimedOut = true);
    });
  }

  Future<void> _probe() async {
    final online = await ref.read(mapReachabilityProvider)();
    if (!mounted) return;
    final wasOffline = _online == false;
    setState(() => _online = online);
    // Back online after the map gave up: load it again by itself.
    if (online && wasOffline && !_styleLoaded) _retry();
  }

  void _retry() {
    setState(() {
      _generation++;
      _map = null;
      _styleReady = false;
      _styleLoaded = false;
      _styleTimedOut = false;
      _fitted = false;
      _meCircle = null;
      _online = null;
    });
    _startStyleTimer();
    _probe();
  }

  @override
  void didUpdateWidget(TripMapView old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data) _scheduleRedraw();
    if (!old.active && widget.active) {
      _focusSelection();
      _probe();
      if (_me != null) _watchMe();
    }
    // No position updates while another view shows.
    if (old.active && !widget.active) _stopWatchingMe();
  }

  void _scheduleRedraw() {
    if (!_styleReady) return;
    _drawing = _drawing.then((_) => _redraw()).catchError((_) {});
  }

  /// Item position; lodging/activities without own coordinates use their stay's.
  LatLng? _pos(PlanItem i) {
    if (i.hasLocation) return LatLng(i.lat!, i.lng!);
    final p = data.item(i.parentId);
    if (p != null && p.hasLocation) return LatLng(p.lat!, p.lng!);
    return null;
  }

  Future<void> _redraw() async {
    final map = _map;
    if (map == null) return;
    final ui = ref.read(tripUiProvider);
    await map.clearLines();
    await map.clearCircles();
    await map.clearSymbols();
    _meCircle = null;

    final visible = [for (final i in data.items) if (ui.shows(i)) i];
    _spreadZoom = _zoom.floor();
    final spread = spreadMarkers([
      for (final i in visible)
        if (i.kind != ItemKind.transport)
          if (_pos(i) case final p?) (id: i.id, kind: i.kind, lat: p.latitude, lng: p.longitude),
    ], _spreadZoom.toDouble());
    _drawn = {for (final MapEntry(:key, :value) in spread.entries) key: LatLng(value.$1, value.$2)};

    // Route: confirmed stays in order.
    if (ui.layers.contains(ItemKind.stay)) {
      final route = [for (final s in stayChain(data.items, zones: data.zones)) if (s.hasLocation) LatLng(s.lat!, s.lng!)];
      if (route.length >= 2) {
        await map.addLine(LineOptions(
          geometry: route,
          lineColor: kindHex(ItemKind.stay),
          lineWidth: 2.5,
          lineOpacity: 0.45,
        ));
      }
    }

    // Transports as arcs between their stays.
    for (final t in visible.where((i) => i.kind == ItemKind.transport)) {
      final a = data.item(t.fromId), b = data.item(t.toId);
      if (a == null || b == null || !a.hasLocation || !b.hasLocation) continue;
      await map.addLine(
        LineOptions(
          geometry: _arc(LatLng(a.lat!, a.lng!), LatLng(b.lat!, b.lng!)),
          lineColor: kindHex(ItemKind.transport),
          // MapLibre lines can't be dashed here: options are thinner too.
          lineWidth: t.id == ui.selectedId ? 5 : (isTentative(t) ? 1.5 : 3),
          lineOpacity: isTentative(t) ? 0.6 : 0.9,
        ),
        {'id': t.id},
      );
    }

    final chain = stayChain(data.items, zones: data.zones);
    // Smaller things first so stays end up on top.
    final order = [ItemKind.activity, ItemKind.accommodation, ItemKind.stay];
    for (final kind in order) {
      for (final i in visible.where((x) => x.kind == kind)) {
        final p = _drawn[i.id];
        if (p == null) continue;
        final selected = i.id == ui.selectedId;
        // Options and ideas are hollow rings (shape, not only opacity);
        // unscheduled items are paler.
        final tentative = isTentative(i);
        final faded = !tentative && !i.isScheduled;
        // Taps next to a circle count too (see [_onMapClick]).
        final radius = switch (kind) {
          ItemKind.stay => 12.0,
          ItemKind.accommodation => 9.0,
          _ => 8.0,
        };
        await map.addCircle(
          CircleOptions(
            geometry: p,
            circleRadius: selected ? radius + 4 : radius,
            circleColor: tentative ? '#ffffff' : kindHex(kind),
            circleOpacity: faded ? 0.45 : 1,
            circleStrokeWidth: tentative ? (selected ? 5 : 3.5) : (selected ? 3 : 1.5),
            circleStrokeColor: tentative ? kindHex(kind) : '#ffffff',
          ),
          {'id': i.id},
        );
        if (kind == ItemKind.stay || selected) {
          final n = chain.indexWhere((s) => s.id == i.id);
          await map.addSymbol(
            SymbolOptions(
              geometry: p,
              textField: n >= 0 ? '${n + 1}. ${i.title}' : i.title,
              textSize: kind == ItemKind.stay ? 13 : 11,
              textOffset: const Offset(0, 1.6),
              textColor: '#222222',
              textHaloColor: '#ffffff',
              textHaloWidth: 1.5,
            ),
            {'id': i.id},
          );
        }
      }
    }
    await _drawMe();
  }

  /// The blue dot on top of everything; moved in place on updates.
  Future<void> _drawMe() async {
    final map = _map, me = _me;
    if (map == null || me == null || !_styleReady) return;
    final circle = _meCircle;
    if (circle != null) {
      await map.updateCircle(circle, CircleOptions(geometry: me));
      return;
    }
    _meCircle = await map.addCircle(CircleOptions(
      geometry: me,
      circleRadius: 8,
      circleColor: '#1a73e8',
      circleStrokeWidth: 3,
      circleStrokeColor: '#ffffff',
    ));
  }

  double get _zoom => _map?.cameraPosition?.zoom ?? 2;

  /// Spreading depends on the zoom: redraw when it crosses a whole level
  /// and some markers share a spot.
  void _onCameraIdle() {
    if (_zoom.floor() == _spreadZoom) return;
    final shared = <(double, double)>{};
    final any = data.items.any((i) {
      if (i.kind == ItemKind.transport) return false;
      final p = _pos(i);
      return p != null && !shared.add((p.latitude, p.longitude));
    });
    if (any) _scheduleRedraw();
  }

  /// A tap that missed every circle: the nearest marker within
  /// [markerHitRadius] still counts.
  Future<void> _onMapClick(math.Point<double> point) async {
    final map = _map;
    if (map == null || _drawn.isEmpty) return;
    final ids = _drawn.keys.toList();
    final screen = await map.toScreenLocationBatch([for (final id in ids) _drawn[id]!]);
    if (!mounted) return;
    // Android reports physical pixels, iOS logical ones.
    final scale = defaultTargetPlatform == TargetPlatform.android ? MediaQuery.devicePixelRatioOf(context) : 1.0;
    final hit = nearestMarker(
      {for (var k = 0; k < ids.length; k++) ids[k]: (screen[k].x.toDouble(), screen[k].y.toDouble())},
      (point.x, point.y),
      markerHitRadius * scale,
    );
    _onTap(hit);
  }

  /// "My location": asks for the permission if needed, shows the position
  /// and follows it while the map is showing. Failures say what to do.
  Future<void> _locateMe() async {
    if (_locating) return;
    setState(() => _locating = true);
    final source = ref.read(locationSourceProvider);
    final r = await source.locate();
    if (!mounted) return;
    setState(() => _locating = false);
    final p = r.position;
    if (p == null) {
      final l = context.l10n;
      final (text, settings) = switch (r.failure!) {
        LocateFailure.serviceDisabled => (l.locationServiceOff, source.openLocationSettings),
        LocateFailure.denied => (l.locationDenied, null),
        LocateFailure.deniedForever => (l.locationDeniedForever, source.openAppSettings),
        LocateFailure.unavailable => (l.locationUnavailable, null),
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(text),
        action: settings == null ? null : SnackBarAction(label: l.locationSettings, onPressed: settings),
      ));
      return;
    }
    setState(() => _me = LatLng(p.$1, p.$2));
    await _drawMe();
    if (!mounted) return;
    // The user may have switched views while the fix was coming.
    if (widget.active) _watchMe();
    // Close enough to see the streets around, but never zoom out.
    await _map?.animateCamera(_zoom >= 13 ? CameraUpdate.newLatLng(_me!) : CameraUpdate.newLatLngZoom(_me!, 14));
  }

  void _watchMe() {
    _meUpdates ??= ref.read(locationSourceProvider).watch().listen(
      (p) {
        if (!mounted) return;
        setState(() => _me = LatLng(p.$1, p.$2));
        _drawMe();
      },
      // A stream that ended (e.g. permission revoked) is restarted next time.
      onDone: () => _meUpdates = null,
    );
  }

  void _stopWatchingMe() {
    _meUpdates?.cancel();
    _meUpdates = null;
  }

  /// Slightly curved line so overlapping connections stay distinguishable.
  List<LatLng> _arc(LatLng a, LatLng b) {
    const steps = 16;
    final mx = (a.latitude + b.latitude) / 2, my = (a.longitude + b.longitude) / 2;
    final dx = b.latitude - a.latitude, dy = b.longitude - a.longitude;
    final cx = mx - dy * 0.15, cy = my + dx * 0.15;
    return [
      for (var k = 0; k <= steps; k++)
        () {
          final t = k / steps;
          final u = 1 - t;
          return LatLng(
            u * u * a.latitude + 2 * u * t * cx + t * t * b.latitude,
            u * u * a.longitude + 2 * u * t * cy + t * t * b.longitude,
          );
        }(),
    ];
  }

  Future<void> _fitAll() async {
    final pts = [for (final i in data.items) ?_pos(i)];
    if (pts.isEmpty || _map == null) return;
    if (pts.length == 1) {
      await _map!.animateCamera(CameraUpdate.newLatLngZoom(pts.first, 11));
      return;
    }
    var s = pts.first.latitude, n = s, w = pts.first.longitude, e = w;
    for (final p in pts) {
      s = math.min(s, p.latitude);
      n = math.max(n, p.latitude);
      w = math.min(w, p.longitude);
      e = math.max(e, p.longitude);
    }
    await _map!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(southwest: LatLng(s, w), northeast: LatLng(n, e)),
      left: 48,
      right: 48,
      top: 64,
      bottom: 64,
    ));
  }

  /// Brings the selection into view without changing the zoom: nothing
  /// happens while it is already visible, otherwise the map pans to it.
  /// A transport whose ends don't fit is shown whole. [initial] (the
  /// world view after loading) zooms in to street level instead.
  Future<void> _focusSelection({bool initial = false}) async {
    final sel = data.item(ref.read(tripUiProvider).selectedId);
    final map = _map;
    if (sel == null || map == null) return;
    // A marker spread away from its stay is focused where it is drawn.
    final drawn = sel.kind == ItemKind.transport ? null : _drawn[sel.id];
    final pts = drawn != null ? [drawn] : [for (final (lat, lng) in focusPoints(data, sel)) LatLng(lat, lng)];
    if (pts.isEmpty) return;
    if (initial) {
      await map.animateCamera(CameraUpdate.newLatLngZoom(pts.first, 10));
      return;
    }
    final r = await map.getVisibleRegion();
    final visible = GeoBox(r.southwest.latitude, r.southwest.longitude, r.northeast.latitude, r.northeast.longitude);
    if (!needsPan(visible, [for (final p in pts) (p.latitude, p.longitude)])) return;
    if (pts.length == 1) {
      await map.animateCamera(CameraUpdate.newLatLng(pts.first));
      return;
    }
    final box = GeoBox.around([for (final p in pts) (p.latitude, p.longitude)])!;
    final fits = box.north - box.south <= (visible.north - visible.south) * 0.76 &&
        box.east - box.west <= (visible.east - visible.west) * 0.76;
    final centre = LatLng((box.north + box.south) / 2, (box.east + box.west) / 2);
    await map.animateCamera(fits
        ? CameraUpdate.newLatLng(centre)
        : CameraUpdate.newLatLngBounds(
            LatLngBounds(southwest: LatLng(box.south, box.west), northeast: LatLng(box.north, box.east)),
            left: 48,
            right: 48,
            top: 64,
            bottom: 64,
          ));
  }

  void _onTap(String? id) {
    if (id == null || !mounted) return;
    showItemSheet(context, ref, data.trip.id, id);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tripUiProvider, (prev, next) {
      if (prev?.selectedId != next.selectedId ||
          prev?.layers != next.layers ||
          prev?.showOptions != next.showOptions) {
        _scheduleRedraw();
      }
      if (widget.active && prev?.selectedId != next.selectedId) _focusSelection();
    });

    final unplaced = [
      for (final i in data.items)
        if (i.kind != ItemKind.transport && _pos(i) == null) i,
    ];
    final offline = ref.watch(offlineMapProvider(data.trip.id));
    final availability = mapAvailability(
      styleLoaded: _styleLoaded,
      styleTimedOut: _styleTimedOut,
      online: _online,
      // Until the stored regions are listed, assume a saved map rather than
      // flashing "unavailable" when the connection check answers first.
      saved: offline.saved || !offline.loaded,
    );
    final covered = offline.covers(placesBox(data));
    final l = context.l10n;
    final placed = data.items.where((i) => i.kind != ItemKind.transport).length - unplaced.length;

    return Stack(
      children: [
        // The native map is opaque to screen readers: it is announced as a
        // whole, and "Places as a list" offers the same content.
        Semantics(
          key: const ValueKey('map-semantics'),
          container: true,
          label: l.a11yMap(placed),
          child: !ref.watch(nativeMapProvider)
              ? const ColoredBox(key: ValueKey('map-surface'), color: Color(0xFF202020), child: SizedBox.expand())
              : MapLibreMap(
                  key: ValueKey('map-$_generation'),
                  styleString: mapStyleUrl,
                  initialCameraPosition: const CameraPosition(target: LatLng(30, 10), zoom: 2),
                  compassEnabled: true,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  trackCameraPosition: true,
                  onMapCreated: (c) {
                    _map = c;
                    c.onCircleTapped.add((circle) => _onTap(circle.data?['id'] as String?));
                    c.onLineTapped.add((line) => _onTap(line.data?['id'] as String?));
                    c.onSymbolTapped.add((symbol) => _onTap(symbol.data?['id'] as String?));
                  },
                  onMapClick: (point, _) => _onMapClick(point),
                  onCameraIdle: _onCameraIdle,
                  onStyleLoadedCallback: () async {
                    _styleReady = true;
                    _styleTimer?.cancel();
                    if (mounted) setState(() => _styleLoaded = true);
                    _scheduleRedraw();
                    await _drawing;
                    if (!_fitted) {
                      _fitted = true;
                      final sel = ref.read(tripUiProvider).selectedId;
                      if (sel != null && data.item(sel) != null) {
                        await _focusSelection(initial: true);
                      } else {
                        await _fitAll();
                      }
                    }
                  },
                  onMapLongClick: (_, latLng) => _addHere(latLng),
                ),
        ),
        Positioned(
          right: 12,
          top: 12,
          child: Column(children: [
            FloatingActionButton.small(
              heroTag: 'fit',
              tooltip: l.showAll,
              onPressed: _fitAll,
              child: const Icon(Icons.zoom_out_map),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.small(
              key: const ValueKey('offline-map-button'),
              heroTag: 'offline',
              tooltip: l.offlineMapSave,
              onPressed: () => showOfflineMapSheet(context, data, online: _online),
              child: offline.downloading
                  ? SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, value: offline.progress),
                    )
                  : Icon(offline.saved ? Icons.offline_pin : Icons.download_for_offline_outlined),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.small(
              key: const ValueKey('places-list-button'),
              heroTag: 'places-list',
              tooltip: l.a11yPlacesList,
              onPressed: _showPlaces,
              child: const Icon(Icons.format_list_bulleted),
            ),
            const SizedBox(height: 8),
            FloatingActionButton.small(
              key: const ValueKey('my-location-button'),
              heroTag: 'my-location',
              tooltip: l.myLocation,
              onPressed: _locateMe,
              child: _locating
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : Icon(_me != null ? Icons.my_location : Icons.location_searching),
            ),
          ]),
        ),
        Positioned(
          left: 12,
          right: 68,
          top: 12,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (availability == MapAvailability.offlineLimited)
              _StatusBanner(
                key: const ValueKey('map-offline-limited'),
                icon: Icons.cloud_off,
                text: l.mapOfflineLimited,
                warning: true,
                action: TextButton(onPressed: _showPlaces, child: Text(l.mapPlaces)),
              )
            else if (availability == MapAvailability.offlineSaved)
              _StatusBanner(
                key: const ValueKey('map-offline-saved'),
                icon: Icons.offline_pin,
                text: covered ? l.mapOfflineSaved : l.offlineMapOutdated,
                warning: !covered,
                action: TextButton(onPressed: _showPlaces, child: Text(l.mapPlaces)),
              )
            else
              const HintBanner(hint: Hint.map, icon: Icons.add_location_alt_outlined, floating: true),
          ]),
        ),
        if (unplaced.isNotEmpty)
          Positioned(
            left: 12,
            bottom: 12,
            child: ActionChip(
              avatar: const Icon(Icons.location_off_outlined, size: 18),
              label: Text(context.l10n.withoutPlaceCount(unplaced.length)),
              onPressed: () => _showUnplaced(unplaced),
            ),
          ),
        if (availability == MapAvailability.unavailable) Positioned.fill(child: _unavailablePanel(context)),
      ],
    );
  }

  /// Covers the empty map: why it is missing, the places as a list, try
  /// again and the offline map sheet (which covers the map buttons).
  Widget _unavailablePanel(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onErrorContainer;
    return Material(
      key: const ValueKey('map-unavailable'),
      color: theme.colorScheme.surface,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Material(
          color: theme.colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.cloud_off, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(l.mapUnavailableTitle, style: theme.textTheme.titleMedium?.copyWith(color: fg)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(_online == false ? l.mapUnavailableOffline : l.mapUnavailableFailed, style: TextStyle(color: fg)),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(spacing: 8, children: [
                  TextButton(
                    onPressed: () => showOfflineMapSheet(context, data, online: _online),
                    child: Text(l.offlineMapTitle),
                  ),
                  TextButton.icon(onPressed: _retry, icon: const Icon(Icons.refresh), label: Text(l.mapRetry)),
                ]),
              ),
            ]),
          ),
        ),
        Expanded(child: PlacesList(data: data)),
      ]),
    );
  }

  /// The places as a sheet while the map shows, but maybe incompletely.
  void _showPlaces() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (c, controller) => Column(children: [
          ListTile(title: Text(c.l10n.mapPlacesTitle, style: Theme.of(c).textTheme.titleMedium)),
          Expanded(child: PlacesList(data: data, controller: controller)),
        ]),
      ),
    );
  }

  Future<void> _addHere(LatLng p) async {
    final kind = await showModalBottomSheet<ItemKind>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(c.l10n.addHere)),
          for (final k in [ItemKind.stay, ItemKind.accommodation, ItemKind.activity])
            ListTile(
              leading: Icon(kindIcon(k), color: kindColor(k)),
              title: Text(c.l10n.kind(k)),
              onTap: () => Navigator.pop(c, k),
            ),
        ]),
      ),
    );
    if (kind == null || !mounted) return;
    await openItemEditor(context, data,
        newKind: kind, parentHint: ref.read(tripUiProvider).selectedId, lat: p.latitude, lng: p.longitude);
  }

  void _showUnplaced(List<PlanItem> items) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(title: Text(c.l10n.itemsWithoutPlace)),
          for (final i in items)
            ListTile(
              leading: Icon(itemIcon(i), color: kindColor(i.kind)),
              title: Text(i.title),
              trailing: const Icon(Icons.edit_location_alt_outlined),
              onTap: () {
                Navigator.pop(c);
                openItemEditor(context, data, item: i);
              },
            ),
        ],
      ),
    );
  }
}

/// Floating status strip on top of the map.
class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool warning;
  final Widget? action;
  const _StatusBanner({super.key, required this.icon, required this.text, this.warning = false, this.action});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = warning ? scheme.onTertiaryContainer : scheme.onSecondaryContainer;
    return Material(
      color: warning ? scheme.tertiaryContainer : scheme.secondaryContainer,
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Row(children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: fg))),
          ?action,
        ]),
      ),
    );
  }
}
