import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/analysis.dart';
import '../../domain/models.dart';
import '../../domain/zones.dart';
import '../../state/hints.dart';
import '../../state/providers.dart';
import '../common/dialogs.dart';
import '../common/hint_banner.dart';
import '../common/item_sheet.dart';
import '../common/l10n.dart';
import '../common/style.dart';
import '../editor/card_editor_page.dart';
import '../keep/card_preview.dart';

/// Half the size of the canvas world; node coordinates range ±_half.
const _half = 5000.0;
const _itemW = 200.0;

/// On-screen distance (px) a node must be dragged before its new position
/// is saved (and an undo step recorded).
const canvasMoveThreshold = 4.0;

/// Default positions for nodes that were never moved: stays left-to-right in
/// trip order with their lodging/activities below; loose cards above.
Map<String, Offset> autoLayout(TripData d) {
  final out = <String, Offset>{};
  final stays = [
    ...stayChain(d.items, zones: d.zones),
    ...d.items.where((i) => i.kind == ItemKind.stay && (!i.isScheduled || i.isOption)),
  ];
  for (var k = 0; k < stays.length; k++) {
    out[stays[k].id] = Offset(k * 280.0, 0);
    final kids = d.items.where((i) => i.kind != ItemKind.stay && i.anchorId == stays[k].id && i.toId != stays[k].id);
    var j = 0;
    for (final c in kids) {
      out[c.id] = Offset(k * 280.0, 150.0 + j++ * 130);
    }
  }
  // Transports sit between their stays.
  for (final t in d.items.where((i) => i.kind == ItemKind.transport)) {
    final a = out[t.fromId], b = out[t.toId];
    if (a != null && b != null) {
      out[t.id] = Offset((a.dx + b.dx) / 2, -150);
    } else if (b != null || a != null) {
      // Arrival/departure from outside the plan (e.g. flights) sit higher.
      out[t.id] = (b ?? a)! + const Offset(0, -290);
    }
  }
  var loose = 0;
  for (final i in d.items) {
    if (!out.containsKey(i.id)) out[i.id] = Offset(loose++ * 280.0, 720);
  }
  var c = 0;
  for (final card in d.cards) {
    out[card.id] = Offset((c % 4) * 250.0, -620.0 - (c ~/ 4) * 260);
    c++;
  }
  return out;
}

class CanvasView extends ConsumerStatefulWidget {
  final TripData data;
  const CanvasView({super.key, required this.data});

  @override
  ConsumerState<CanvasView> createState() => _CanvasViewState();
}

class _CanvasViewState extends ConsumerState<CanvasView> {
  final _tc = TransformationController();
  final Map<String, Offset> _dragPos = {};
  final Map<String, Offset> _dragOrigin = {};
  final Map<String, Size> _sizes = {};
  bool _connectMode = false;
  String? _connectFrom;
  bool _initialised = false;

  TripData get data => widget.data;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  Map<String, Offset> _positions() {
    final auto = autoLayout(data);
    return {
      for (final i in data.items) i.id: _dragPos[i.id] ?? (i.canvasX != null ? Offset(i.canvasX!, i.canvasY!) : auto[i.id]!),
      for (final c in data.cards) c.id: _dragPos[c.id] ?? (c.canvasX != null ? Offset(c.canvasX!, c.canvasY!) : auto[c.id]!),
    };
  }

  void _centerOn(Offset worldPoint, {double? scale}) {
    final size = context.size;
    if (size == null) return;
    final s = scale ?? _tc.value.getMaxScaleOnAxis();
    final p = worldPoint + const Offset(_half, _half);
    _tc.value = Matrix4.identity()
      ..translateByDouble(size.width / 2 - p.dx * s, size.height / 2 - p.dy * s, 0, 1)
      ..scaleByDouble(s, s, 1, 1);
  }

  /// Fits everything once the view has a size (retries for a few frames).
  void _fitWhenLaidOut([int attempt = 0]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = context.size;
      if ((size == null || size.isEmpty) && attempt < 30) {
        _fitWhenLaidOut(attempt + 1);
        return;
      }
      _fitAll();
    });
  }

  void _fitAll() {
    final pos = _positions();
    final size = context.size;
    if (pos.isEmpty || size == null) return;
    var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
    for (final e in pos.entries) {
      final s = _sizes[e.key] ?? const Size(_itemW, 80);
      minX = math.min(minX, e.value.dx);
      minY = math.min(minY, e.value.dy);
      maxX = math.max(maxX, e.value.dx + s.width);
      maxY = math.max(maxY, e.value.dy + s.height);
    }
    final w = maxX - minX + 80, h = maxY - minY + 80;
    final scale = math.min(size.width / w, size.height / h).clamp(0.15, 1.2);
    _centerOn(Offset((minX + maxX) / 2, (minY + maxY) / 2), scale: scale);
  }

  Future<void> _savePosition(String id, Offset p) async {
    final actions = ref.read(planActionsProvider);
    final item = data.item(id);
    final card = data.card(id);
    final l = context.l10n;
    final title = item?.title ?? (card?.title.isNotEmpty == true ? card!.title : l.cardNote);
    await actions.record(data.trip.id, l.stepMovedOnCanvas(title), (repo) async {
      if (item != null) {
        await repo.saveItem(item.copyWith(canvasX: p.dx, canvasY: p.dy));
      } else if (card != null) {
        await repo.saveCard(card.copyWith(canvasX: p.dx, canvasY: p.dy));
      }
    });
  }

  /// Saves a long-press drag, but only if the node really moved: a press
  /// without movement must not create an undo step.
  Future<void> _endDrag(String id) async {
    final origin = _dragOrigin.remove(id);
    final p = _dragPos[id];
    if (origin == null || p == null) return;
    final movedPx = (p - origin).distance * _tc.value.getMaxScaleOnAxis();
    if (movedPx >= canvasMoveThreshold) await _savePosition(id, p);
    if (mounted) setState(() => _dragPos.remove(id));
  }

  Future<void> _tapNode(String id) async {
    if (_connectMode) {
      if (_connectFrom == null) {
        setState(() => _connectFrom = id);
        return;
      }
      if (_connectFrom == id) {
        setState(() => _connectFrom = null);
        return;
      }
      final a = _connectFrom!;
      setState(() => _connectFrom = null);
      final existing = data.edges.where((e) => (e.fromId == a && e.toId == id) || (e.fromId == id && e.toId == a));
      final actions = ref.read(planActionsProvider);
      final l = context.l10n;
      if (existing.isNotEmpty) {
        await actions.record(data.trip.id, l.stepConnectionRemoved, (repo) async {
          for (final e in existing) {
            await repo.deleteEdge(e.id);
          }
        });
        if (mounted) showSnack(context, l.stepConnectionRemoved);
      } else {
        await actions.record(data.trip.id, l.stepConnectionCreated,
            (repo) => repo.saveEdge(Edge(id: newId(), tripId: data.trip.id, fromId: a, toId: id)));
      }
      return;
    }
    final item = data.item(id);
    if (item != null) {
      await showItemSheet(context, ref, data.trip.id, id);
    } else {
      final c = data.card(id);
      if (c != null) await openCardEditor(context, data, card: c);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(tripUiProvider);
    final pos = _positions();

    ref.listen(tripUiProvider.select((u) => (u.selectedId, u.view)), (prev, next) {
      if (next.$2 == TripView.canvas && next != prev && next.$1 != null) {
        final p = _positions()[next.$1];
        if (p != null) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => _centerOn(p + Offset((_sizes[next.$1]?.width ?? _itemW) / 2, 40)));
        }
      }
    });
    if (!_initialised) {
      _initialised = true;
      _fitWhenLaidOut();
    }

    final links = <_Link>[
      for (final e in data.edges) _Link(e.fromId, e.toId, _LinkStyle.user),
      for (final c in data.cards)
        if (c.itemId != null) _Link(c.id, c.itemId!, _LinkStyle.reference),
      for (final i in data.items)
        if (i.parentId != null) _Link(i.parentId!, i.id, _LinkStyle.child),
      for (final t in data.items.where((i) => i.kind == ItemKind.transport)) ...[
        if (t.fromId != null) _Link(t.fromId!, t.id, _LinkStyle.sequence),
        if (t.toId != null) _Link(t.id, t.toId!, _LinkStyle.sequence),
      ],
    ];
    // Stays in order, unless a transport already connects them.
    final chain = stayChain(data.items, zones: data.zones);
    for (var k = 0; k + 1 < chain.length; k++) {
      final a = chain[k].id, b = chain[k + 1].id;
      final viaTransport = data.items.any((t) => t.kind == ItemKind.transport && t.fromId == a && t.toId == b);
      if (!viaTransport) links.add(_Link(a, b, _LinkStyle.sequence));
    }

    Widget node(String id, Widget child, double width) {
      final p = pos[id]!;
      return Positioned(
        key: ValueKey(id),
        left: p.dx + _half,
        top: p.dy + _half,
        width: width,
        child: _MeasureSize(
          onChange: (s) {
            if (_sizes[id] != s) setState(() => _sizes[id] = s);
          },
          // A plain swipe pans the canvas (InteractiveViewer); nodes only
          // move after a long press, like blocks on the timeline.
          child: GestureDetector(
            onTap: () => _tapNode(id),
            onLongPressStart: (_) {
              HapticFeedback.mediumImpact();
              _dragOrigin[id] = pos[id]!;
              setState(() => _dragPos[id] = pos[id]!);
            },
            onLongPressMoveUpdate: (d) {
              final origin = _dragOrigin[id];
              if (origin == null) return;
              final scale = _tc.value.getMaxScaleOnAxis();
              setState(() => _dragPos[id] = origin + d.offsetFromOrigin / scale);
            },
            onLongPressEnd: (_) => _endDrag(id),
            onLongPressCancel: () => _endDrag(id),
            child: child,
          ),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: scheme.surfaceContainerLowest,
            child: InteractiveViewer(
              transformationController: _tc,
              constrained: false,
              minScale: 0.1,
              maxScale: 2.5,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              child: SizedBox(
                width: _half * 2,
                height: _half * 2,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _LinkPainter(
                          links: links,
                          positions: pos,
                          sizes: _sizes,
                          color: scheme.onSurface,
                          dot: scheme.outlineVariant,
                        ),
                      ),
                    ),
                    for (final c in data.cards)
                      node(
                        c.id,
                        CardPreview(card: c, data: data, selected: _connectFrom == c.id, maxLines: 6),
                        c.canvasW,
                      ),
                    for (final i in data.items)
                      node(
                        i.id,
                        _ItemNode(
                          item: i,
                          tripStart: data.trip.startDate,
                          zones: data.zones,
                          selected: ui.selectedId == i.id || _connectFrom == i.id,
                        ),
                        _itemW,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 12,
          top: 12,
          child: Column(
            children: [
              FloatingActionButton.small(
                heroTag: 'canvas-fit',
                tooltip: context.l10n.showAll,
                onPressed: _fitAll,
                child: const Icon(Icons.fit_screen),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'canvas-connect',
                tooltip: context.l10n.connect,
                backgroundColor: _connectMode ? scheme.primary : null,
                foregroundColor: _connectMode ? scheme.onPrimary : null,
                onPressed: () => setState(() {
                  _connectMode = !_connectMode;
                  _connectFrom = null;
                }),
                child: const Icon(Icons.polyline),
              ),
            ],
          ),
        ),
        // The connect instructions take this spot while connecting.
        if (!_connectMode)
          const Positioned(
            left: 12,
            right: 72,
            top: 12,
            child: HintBanner(hint: Hint.canvas, floating: true),
          ),
        if (_connectMode)
          Positioned(
            left: 12,
            right: 72,
            top: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_connectFrom == null ? context.l10n.connectFirst : context.l10n.connectSecond),
              ),
            ),
          ),
      ],
    );
  }
}

class _ItemNode extends StatelessWidget {
  final PlanItem item;
  final DateTime? tripStart;
  final TripZones zones;
  final bool selected;
  const _ItemNode({required this.item, required this.tripStart, required this.zones, required this.selected});

  @override
  Widget build(BuildContext context) {
    final c = kindColor(item.kind);
    final theme = Theme.of(context);
    final faded = item.isOption || item.status == ItemStatus.idea;
    return Material(
      elevation: selected ? 6 : 2,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? theme.colorScheme.onSurface : c, width: selected ? 2.5 : 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Opacity(
        opacity: faded ? 0.7 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: faded ? c.withValues(alpha: 0.3) : c,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(children: [
                Icon(itemIcon(item), size: 16, color: faded ? c : Colors.white),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: faded ? null : Colors.white, fontWeight: FontWeight.w600)),
                ),
                if (item.fixed) Icon(Icons.lock, size: 14, color: faded ? c : Colors.white),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(timeSummary(context.l10n, item, tripStart, zones: zones), style: theme.textTheme.bodySmall, maxLines: 2),
                  Text(context.l10n.status(item.status), style: theme.textTheme.labelSmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _LinkStyle { user, reference, child, sequence }

class _Link {
  final String a;
  final String b;
  final _LinkStyle style;
  const _Link(this.a, this.b, this.style);
}

class _LinkPainter extends CustomPainter {
  final List<_Link> links;
  final Map<String, Offset> positions;
  final Map<String, Size> sizes;
  final Color color;
  final Color dot;

  _LinkPainter({
    required this.links,
    required this.positions,
    required this.sizes,
    required this.color,
    required this.dot,
  });

  Offset? _center(String id) {
    final p = positions[id];
    if (p == null) return null;
    final s = sizes[id] ?? const Size(_itemW, 70);
    return p + const Offset(_half, _half) + Offset(s.width / 2, s.height / 2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Dot grid, so panning feels like moving over a surface.
    canvas.drawPoints(
      PointMode.points,
      _gridPoints(size),
      Paint()
        ..color = dot
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    for (final l in links) {
      final a = _center(l.a), b = _center(l.b);
      if (a == null || b == null) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      switch (l.style) {
        case _LinkStyle.user:
          paint
            ..color = color.withValues(alpha: 0.75)
            ..strokeWidth = 2.5;
        case _LinkStyle.reference:
          paint
            ..color = color.withValues(alpha: 0.35)
            ..strokeWidth = 1.5;
        case _LinkStyle.child:
          paint
            ..color = color.withValues(alpha: 0.25)
            ..strokeWidth = 1.5;
        case _LinkStyle.sequence:
          paint
            ..color = kindColor(ItemKind.stay).withValues(alpha: 0.6)
            ..strokeWidth = 3;
      }
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2 - 30);
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);
      if (l.style == _LinkStyle.reference) {
        for (final m in path.computeMetrics()) {
          for (double d = 0; d < m.length; d += 12) {
            canvas.drawPath(m.extractPath(d, d + 6), paint);
          }
        }
      } else {
        canvas.drawPath(path, paint);
      }
      if (l.style == _LinkStyle.sequence) {
        // Arrow head at the middle pointing towards b.
        final m = path.computeMetrics().first;
        final t = m.getTangentForOffset(m.length / 2);
        if (t != null) {
          final dir = t.vector / t.vector.distance;
          final normal = Offset(-dir.dy, dir.dx);
          final tip = t.position + dir * 8;
          final arrow = Path()
            ..moveTo(tip.dx, tip.dy)
            ..lineTo((t.position - dir * 6 + normal * 7).dx, (t.position - dir * 6 + normal * 7).dy)
            ..lineTo((t.position - dir * 6 - normal * 7).dx, (t.position - dir * 6 - normal * 7).dy)
            ..close();
          canvas.drawPath(arrow, Paint()..color = paint.color);
        }
      }
    }
  }

  static List<Offset>? _grid;
  static List<Offset> _gridPoints(Size size) => _grid ??= [
        for (double x = 0; x < size.width; x += 80)
          for (double y = 0; y < size.height; y += 80) Offset(x, y),
      ];

  @override
  bool shouldRepaint(_LinkPainter old) => true;
}

/// Reports the laid-out size of its child (for drawing link endpoints).
class _MeasureSize extends SingleChildRenderObjectWidget {
  final ValueChanged<Size> onChange;
  const _MeasureSize({required this.onChange, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _MeasureSizeRender(onChange);

  @override
  void updateRenderObject(BuildContext context, _MeasureSizeRender renderObject) => renderObject.onChange = onChange;
}

class _MeasureSizeRender extends RenderProxyBox {
  ValueChanged<Size> onChange;
  Size? _last;
  _MeasureSizeRender(this.onChange);

  @override
  void performLayout() {
    super.performLayout();
    if (size != _last) {
      _last = size;
      final s = size;
      WidgetsBinding.instance.addPostFrameCallback((_) => onChange(s));
    }
  }
}
