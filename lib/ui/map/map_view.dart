import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../domain/analysis.dart';
import '../../domain/models.dart';
import '../../state/hints.dart';
import '../../state/providers.dart';
import '../common/hint_banner.dart';
import '../common/item_sheet.dart';
import '../common/l10n.dart';
import '../common/style.dart';
import '../editor/item_editor_page.dart';

/// OpenStreetMap-based vector style, free and without API key.
const mapStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';

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

  TripData get data => widget.data;

  @override
  void didUpdateWidget(TripMapView old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data) _scheduleRedraw();
    if (!old.active && widget.active) _focusSelection();
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

    return Stack(
      children: [
        MapLibreMap(
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
          child: FloatingActionButton.small(
            heroTag: 'fit',
            tooltip: context.l10n.showAll,
            onPressed: _fitAll,
            child: const Icon(Icons.zoom_out_map),
          ),
        ),
        const Positioned(
          left: 12,
          right: 68,
          top: 12,
          child: HintBanner(hint: Hint.map, icon: Icons.add_location_alt_outlined, floating: true),
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
      ],
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
