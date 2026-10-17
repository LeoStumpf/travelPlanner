import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../data/offline_maps.dart';
import '../../domain/analysis.dart';
import '../../domain/map_offline.dart';
import '../../domain/models.dart';
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

  TripData get data => widget.data;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () {
      if (widget.active) _probe();
    });
    _startStyleTimer();
    _probe();
  }

  @override
  void dispose() {
    _styleTimer?.cancel();
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
    }
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

    final visible = [for (final i in data.items) if (ui.shows(i)) i];

    // Route: confirmed stays in order.
    if (ui.layers.contains(ItemKind.stay)) {
      final route = [for (final s in stayChain(data.items)) if (s.hasLocation) LatLng(s.lat!, s.lng!)];
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
          lineWidth: t.id == ui.selectedId ? 5 : 3,
          lineOpacity: t.isOption ? 0.4 : 0.9,
        ),
        {'id': t.id},
      );
    }

    final chain = stayChain(data.items);
    // Smaller things first so stays end up on top.
    final order = [ItemKind.activity, ItemKind.accommodation, ItemKind.stay];
    for (final kind in order) {
      for (final i in visible.where((x) => x.kind == kind)) {
        final p = _pos(i);
        if (p == null) continue;
        final selected = i.id == ui.selectedId;
        final faded = i.isOption || i.status == ItemStatus.idea || !i.isScheduled;
        final radius = switch (kind) {
          ItemKind.stay => 11.0,
          ItemKind.accommodation => 7.0,
          _ => 6.0,
        };
        await map.addCircle(
          CircleOptions(
            geometry: p,
            circleRadius: selected ? radius + 4 : radius,
            circleColor: kindHex(kind),
            circleOpacity: faded ? 0.45 : 1,
            circleStrokeWidth: selected ? 3 : 1.5,
            circleStrokeColor: '#ffffff',
          ),
          {'id': i.id},
        );
        if (kind == ItemKind.stay || selected) {
          final n = chain.indexWhere((s) => s.id == i.id);
          await map.addSymbol(SymbolOptions(
            geometry: p,
            textField: n >= 0 ? '${n + 1}. ${i.title}' : i.title,
            textSize: kind == ItemKind.stay ? 13 : 11,
            textOffset: const Offset(0, 1.6),
            textColor: '#222222',
            textHaloColor: '#ffffff',
            textHaloWidth: 1.5,
          ));
        }
      }
    }
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

  Future<void> _focusSelection() async {
    final sel = data.item(ref.read(tripUiProvider).selectedId);
    if (sel == null || _map == null) return;
    LatLng? p = _pos(sel);
    if (sel.kind == ItemKind.transport) {
      final a = data.item(sel.fromId);
      if (a != null && a.hasLocation) p = LatLng(a.lat!, a.lng!);
    }
    if (p != null) await _map!.animateCamera(CameraUpdate.newLatLngZoom(p, 10));
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
      saved: offline.saved,
    );
    final covered = offline.covers(placesBox(data));
    final l = context.l10n;

    return Stack(
      children: [
        if (!ref.watch(nativeMapProvider))
          const ColoredBox(key: ValueKey('map-surface'), color: Color(0xFF202020), child: SizedBox.expand())
        else
          MapLibreMap(
            key: ValueKey('map-$_generation'),
            styleString: mapStyleUrl,
            initialCameraPosition: const CameraPosition(target: LatLng(30, 10), zoom: 2),
            compassEnabled: true,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            onMapCreated: (c) {
              _map = c;
              c.onCircleTapped.add((circle) => _onTap(circle.data?['id'] as String?));
              c.onLineTapped.add((line) => _onTap(line.data?['id'] as String?));
            },
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
                  await _focusSelection();
                } else {
                  await _fitAll();
                }
              }
            },
            onMapLongClick: (_, latLng) => _addHere(latLng),
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
