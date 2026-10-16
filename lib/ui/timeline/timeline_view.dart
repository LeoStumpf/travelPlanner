import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/analysis.dart';
import '../../domain/models.dart';
import '../../domain/scheduler.dart';
import '../../domain/time.dart';
import '../../state/providers.dart';
import '../common/conflict_tile.dart';
import '../common/dialogs.dart';
import '../common/item_sheet.dart';
import '../common/style.dart';
import '../editor/item_editor_page.dart';
import '../trip/trip_page.dart';

const _headerH = 44.0;
const _labelW = 40.0;
const _lanePad = 6.0;

double _rowHeight(ItemKind k) => switch (k) {
  ItemKind.stay => 48,
  ItemKind.transport => 32,
  ItemKind.accommodation => 36,
  ItemKind.activity => 32,
};

enum _DragType { move, resizeStart, resizeEnd }

class TimelineView extends ConsumerStatefulWidget {
  final TripData data;
  const TimelineView({super.key, required this.data});

  @override
  ConsumerState<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends ConsumerState<TimelineView> {
  final _hScroll = ScrollController();
  double _dayWidth = 64;

  String? _dragId;
  _DragType? _dragType;
  int _dragMinutes = 0;

  // Two-finger pinch on the time axis.
  final Map<int, Offset> _pointers = {};
  double? _pinchStartDist;
  double _pinchStartWidth = 0;
  double _pinchFocalDays = 0;

  TripData get data => widget.data;

  @override
  void initState() {
    super.initState();
    // Long blocks keep their title at the left edge while scrolling.
    _hScroll.addListener(_onScroll);
  }

  double _scrollX = 0;
  void _onScroll() {
    if ((_hScroll.offset - _scrollX).abs() >= 2) setState(() => _scrollX = _hScroll.offset);
  }

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  double get _pxPerMin => _dayWidth / minutesPerDay;

  /// Drag step for [i]: stays and lodging move by whole days (nights);
  /// everything else by the finest time step that is still ~10 px wide.
  int _snapFor(PlanItem i) {
    if (i.kind == ItemKind.stay || i.kind == ItemKind.accommodation) return minutesPerDay;
    for (final step in const [15, 30, 60, 120, 360, 720]) {
      if (step * _pxPerMin >= 10) return step;
    }
    return minutesPerDay;
  }

  void _dragTo(PlanItem i, double dx) {
    final snap = _snapFor(i);
    final m = (dx / _pxPerMin / snap).round() * snap;
    if (m != _dragMinutes) {
      HapticFeedback.selectionClick();
      setState(() => _dragMinutes = m);
    }
  }

  void _startDrag(PlanItem i, _DragType type) {
    HapticFeedback.mediumImpact();
    ref.read(tripUiProvider.notifier).select(i.id);
    setState(() {
      _dragId = i.id;
      _dragType = type;
      _dragMinutes = 0;
    });
  }

  /// Items as they would look with the current drag applied.
  ScheduleResult? _preview(ShiftMode mode) {
    final id = _dragId;
    if (id == null || _dragMinutes == 0) return null;
    final item = data.item(id);
    final isRoot = item != null && item.anchorId == null;
    final m = isRoot ? mode : ShiftMode.single;
    return switch (_dragType!) {
      _DragType.move => Scheduler.move(data.items, id, _dragMinutes, m),
      _DragType.resizeEnd => Scheduler.resizeEnd(data.items, id, _dragMinutes, m),
      _DragType.resizeStart => Scheduler.resizeStart(data.items, id, _dragMinutes),
    };
  }

  /// "+1 Tag → Mi 12. Mär, 14:00" while dragging.
  String _dragLabel(ScheduleResult? preview) {
    if (_dragMinutes == 0) return 'Ziehen …';
    final m = _dragMinutes.abs();
    final days = m ~/ minutesPerDay, hours = (m % minutesPerDay) ~/ 60, mins = m % 60;
    final amount = [if (days > 0) pluralDays(days), if (hours > 0) '${hours}h', if (mins > 0) '${mins}min'].join(' ');
    final item = preview?.items.where((i) => i.id == _dragId).firstOrNull;
    final at = item == null
        ? ''
        : ' → ${formatMoment(data.trip.startDate, _dragType == _DragType.resizeEnd ? item.end! : item.start!)}';
    return '${_dragMinutes > 0 ? '+' : '−'}$amount$at';
  }

  /// Changes the zoom while keeping the time under [focalX] (viewport
  /// coordinates) in place.
  void _zoomTo(double width, double focalX) {
    final w = width.clamp(28.0, 480.0);
    if (!_hScroll.hasClients) {
      setState(() => _dayWidth = w);
      return;
    }
    final focalDays = (_hScroll.offset + focalX) / _dayWidth;
    setState(() => _dayWidth = w);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hScroll.hasClients) return;
      _hScroll.jumpTo((focalDays * w - focalX).clamp(0, _hScroll.position.maxScrollExtent));
    });
  }

  void _onPointerDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 2) {
      final ps = _pointers.values.toList();
      _pinchStartDist = (ps[0].dx - ps[1].dx).abs().clamp(20, double.infinity);
      _pinchStartWidth = _dayWidth;
      final focalX = (ps[0].dx + ps[1].dx) / 2;
      _pinchFocalDays = ((_hScroll.hasClients ? _hScroll.offset : 0) + focalX) / _dayWidth;
      setState(() {});
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.localPosition;
    final start = _pinchStartDist;
    if (_pointers.length < 2 || start == null) return;
    final ps = _pointers.values.toList();
    final dist = (ps[0].dx - ps[1].dx).abs().clamp(20, double.infinity);
    final w = (_pinchStartWidth * dist / start).clamp(28.0, 480.0);
    final focalX = (ps[0].dx + ps[1].dx) / 2;
    setState(() => _dayWidth = w);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hScroll.hasClients) return;
      _hScroll.jumpTo((_pinchFocalDays * w - focalX).clamp(0, _hScroll.position.maxScrollExtent));
    });
  }

  void _onPointerUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2 && _pinchStartDist != null) {
      setState(() => _pinchStartDist = null);
    }
  }

  Future<void> _commitDrag(ShiftMode mode) async {
    final r = _preview(mode);
    final item = data.item(_dragId);
    setState(() {
      _dragId = null;
      _dragMinutes = 0;
    });
    if (r == null || item == null || r.changedIds.isEmpty) return;
    final actions = ref.read(planActionsProvider);
    final label = switch (_dragType!) {
      _DragType.move => '„${item.title}“ verschoben',
      _DragType.resizeEnd => '„${item.title}“: Ende geändert',
      _DragType.resizeStart => '„${item.title}“: Beginn geändert',
    };
    await actions.applySchedule(data, r, label);
    if (!mounted) return;
    final others = r.changedIds.length - 1;
    final conflicts = findConflicts(r.items).length;
    showSnack(
      context,
      [
        label,
        if (others > 0) '$others weitere mitverschoben',
        if (conflicts > 0) '$conflicts Konflikt${conflicts == 1 ? '' : 'e'}',
      ].join(' · '),
      action: SnackBarAction(label: 'Rückgängig', onPressed: () => actions.undo(data.trip.id)),
    );
  }

  /// Brings [item] into view, but only if it is not visible already.
  void _scrollTo(PlanItem? item, int firstDay) {
    if (item == null || !item.isScheduled || !_hScroll.hasClients) return;
    final start = (item.start! - firstDay * minutesPerDay) * _pxPerMin;
    final end = (item.end! - firstDay * minutesPerDay) * _pxPerMin;
    final view = _hScroll.offset, viewEnd = view + _hScroll.position.viewportDimension;
    if (end > view + 20 && start < viewEnd - 20) return;
    final x = start - 60;
    _hScroll.animateTo(
      x.clamp(0, _hScroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(tripUiProvider);
    final preview = _preview(ui.shiftMode);
    final items = preview?.items ?? data.items;
    final changed = preview?.changedIds ?? const <String>{};
    final (first, lastRaw) = dayRange(items, plannedDays: data.trip.plannedDays);
    final firstDay = first;
    final lastDay = lastRaw + 2;
    final totalW = (lastDay - firstDay + 1) * _dayWidth;
    final conflicts = findConflicts(items);
    final conflictIds = {
      for (final c in conflicts) ...[c.itemId, ?c.otherId],
    };

    ref.listen(tripUiProvider.select((u) => (u.selectedId, u.view)), (prev, next) {
      if (next.$2 == TripView.timeline && next != prev) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(data.item(next.$1), firstDay));
      }
    });

    final missingNights = uncoveredNights(items);
    final lanes = <_LaneSpec>[];
    for (final k in ItemKind.values) {
      if (!ui.layers.contains(k)) continue;
      final laneItems = [
        for (final i in items)
          if (i.kind == k && i.isScheduled && ui.shows(i)) i,
      ];
      final (rows, count) = packLanes(laneItems);
      // Lodging gets an extra row for "no bed yet" markers.
      final extra = k == ItemKind.accommodation && missingNights.isNotEmpty ? 1 : 0;
      lanes.add(_LaneSpec(k, laneItems, rows, (laneItems.isEmpty ? 0 : count) + extra));
    }
    final unscheduled = [
      for (final i in data.items)
        if (!i.isScheduled && ui.shows(i)) i,
    ];

    double x(int minute) => (minute - firstDay * minutesPerDay) * _pxPerMin;

    final laneWidgets = <Widget>[];
    final labelWidgets = <Widget>[];
    for (final lane in lanes) {
      final rowH = _rowHeight(lane.kind);
      final h = (lane.rowCount < 1 ? 1 : lane.rowCount) * rowH + 2 * _lanePad;
      final children = <Widget>[];

      if (lane.kind == ItemKind.stay) {
        for (final g in findGaps(items, plannedDays: data.trip.plannedDays)) {
          if (g.firstDay < firstDay) continue;
          children.add(
            Positioned(
              left: x(at(g.firstDay, 0)) + 3,
              width: g.days * _dayWidth - 6,
              top: _lanePad,
              height: rowH - 6,
              child: _GapBox(
                label: g.days == 1 ? '1 Tag frei' : '${g.days} Tage frei',
                onTap: () => showAddSheet(context, ref, data, atDay: g.firstDay),
              ),
            ),
          );
        }
      }
      if (lane.kind == ItemKind.accommodation) {
        for (final n in missingNights) {
          final stay = stayChain(items).where((s) => dayOf(s.start!) <= n && n < lastDayOf(s.end!)).firstOrNull;
          children.add(
            Positioned(
              left: x(at(n, 19 * 60)),
              width: 13 * 60 * _pxPerMin,
              top: _lanePad + (lane.rowCount - 1) * rowH,
              height: rowH - 6,
              child: _MissingNight(
                onTap: () =>
                    openItemEditor(context, data, newKind: ItemKind.accommodation, atDay: n, parentHint: stay?.id),
              ),
            ),
          );
        }
      }

      for (final i in lane.items) {
        final left = x(i.start!);
        final width = math.max(i.duration * _pxPerMin, 26.0);
        final row = lane.rows[i.id] ?? 0;
        final draggable = !i.fixed;
        children.add(
          Positioned(
            key: ValueKey(i.id),
            left: left,
            width: width,
            top: _lanePad + row * rowH,
            height: rowH - 6,
            child: _Block(
              titleInset: (_scrollX - left).clamp(0, math.max(0, width - 90)),
              item: i,
              tripStart: data.trip.startDate,
              selected: ui.selectedId == i.id,
              conflict: conflictIds.contains(i.id),
              moving: changed.contains(i.id),
              onTap: () => showItemSheet(context, ref, data.trip.id, i.id),
              onLongPressStart: () {
                if (!draggable) {
                  showSnack(context, '„${i.title}“ ist fix und wird nicht verschoben');
                  return;
                }
                if (_pinchStartDist != null) return;
                _startDrag(i, _DragType.move);
              },
              onLongPressMove: (dx) {
                if (_dragId == i.id && _dragType == _DragType.move) _dragTo(i, dx);
              },
              onLongPressEnd: () {
                if (_dragId == i.id) _commitDrag(ui.shiftMode);
              },
              onResizeStart: draggable && width >= 56
                  ? _ResizeCallbacks(
                      start: () => _startDrag(i, _DragType.resizeStart),
                      update: (dx) => _dragTo(i, dx),
                      end: () => _commitDrag(ui.shiftMode),
                    )
                  : null,
              onResizeEnd: draggable && width >= 40
                  ? _ResizeCallbacks(
                      start: () => _startDrag(i, _DragType.resizeEnd),
                      update: (dx) => _dragTo(i, dx),
                      end: () => _commitDrag(ui.shiftMode),
                    )
                  : null,
            ),
          ),
        );
      }

      laneWidgets.add(
        Container(
          height: h,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.4))),
          ),
          child: Stack(clipBehavior: Clip.none, children: children),
        ),
      );
      labelWidgets.add(
        SizedBox(
          height: h,
          child: Tooltip(
            message: 'Ebene ${lane.kind.layer}: ${lane.kind.label}',
            child: Center(child: Icon(kindIcon(lane.kind), color: kindColor(lane.kind), size: 20)),
          ),
        ),
      );
    }

    return Column(
      children: [
        _Toolbar(
          mode: ui.shiftMode,
          conflicts: conflicts,
          data: data,
          dragLabel: _dragId != null ? _dragLabel(preview) : null,
          onZoom: (f) => _zoomTo(_dayWidth * f, _hScroll.hasClients ? _hScroll.position.viewportDimension / 2 : 0),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _labelW,
                  child: Column(
                    children: [
                      const SizedBox(height: _headerH),
                      ...labelWidgets,
                    ],
                  ),
                ),
                Expanded(
                  child: Listener(
                    onPointerDown: _onPointerDown,
                    onPointerMove: _onPointerMove,
                    onPointerUp: _onPointerUp,
                    onPointerCancel: _onPointerUp,
                    child: SingleChildScrollView(
                      controller: _hScroll,
                      scrollDirection: Axis.horizontal,
                      physics: _pinchStartDist != null ? const NeverScrollableScrollPhysics() : null,
                      child: SizedBox(
                        width: totalW,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _GridPainter(
                                  firstDay: firstDay,
                                  dayWidth: _dayWidth,
                                  headerH: _headerH,
                                  tripStart: data.trip.startDate,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  today: _todayIndex(),
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _DayHeader(
                                  firstDay: firstDay,
                                  lastDay: lastDay,
                                  dayWidth: _dayWidth,
                                  tripStart: data.trip.startDate,
                                  onLongPress: (d) => showAddSheet(context, ref, data, atDay: d),
                                ),
                                ...laneWidgets,
                                const SizedBox(height: 24),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (unscheduled.isNotEmpty) _UnscheduledTray(items: unscheduled, tripId: data.trip.id),
      ],
    );
  }

  int? _todayIndex() {
    final s = data.trip.startDate;
    if (s == null) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).difference(DateTime(s.year, s.month, s.day)).inHours ~/ 24;
  }
}

class _LaneSpec {
  final ItemKind kind;
  final List<PlanItem> items;
  final Map<String, int> rows;
  final int rowCount;
  _LaneSpec(this.kind, this.items, this.rows, this.rowCount);
}

class _ResizeCallbacks {
  final VoidCallback start;
  final ValueChanged<double> update;
  final VoidCallback end;
  const _ResizeCallbacks({required this.start, required this.update, required this.end});
}

class _Block extends StatelessWidget {
  final PlanItem item;
  final DateTime? tripStart;
  final bool selected;
  final bool conflict;
  final bool moving;
  final VoidCallback onTap;
  final VoidCallback onLongPressStart;
  final ValueChanged<double> onLongPressMove;
  final VoidCallback onLongPressEnd;
  final _ResizeCallbacks? onResizeStart;
  final _ResizeCallbacks? onResizeEnd;

  /// Pushes the title right when the block starts left of the viewport.
  final double titleInset;

  const _Block({
    required this.item,
    required this.tripStart,
    required this.selected,
    required this.conflict,
    required this.moving,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressMove,
    required this.onLongPressEnd,
    required this.onResizeStart,
    required this.onResizeEnd,
    this.titleInset = 0,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = kindColor(item.kind);
    final option = item.isOption || item.status == ItemStatus.idea;
    final bg = option ? base.withValues(alpha: 0.22) : base;
    final fg = option ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : base) : Colors.white;
    final borderColor = conflict
        ? scheme.error
        : selected
        ? scheme.onSurface
        : (option ? base : Colors.transparent);
    final nights = item.kind == ItemKind.stay || item.kind == ItemKind.accommodation
        ? nightsIn(item.start!, item.end!)
        : null;

    return GestureDetector(
      onTap: onTap,
      onLongPressStart: (_) => onLongPressStart(),
      onLongPressMoveUpdate: (d) => onLongPressMove(d.offsetFromOrigin.dx),
      onLongPressEnd: (_) => onLongPressEnd(),
      onLongPressCancel: onLongPressEnd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(item.kind == ItemKind.accommodation ? 18 : 8),
          border: Border.all(color: borderColor, width: conflict || selected ? 2 : 1),
          boxShadow: moving ? [BoxShadow(color: base.withValues(alpha: 0.5), blurRadius: 8)] : null,
        ),
        child: Stack(
          children: [
            // Narrow blocks (short transports, zoomed out) show less detail.
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  if (w < 40) return Center(child: Icon(itemIcon(item), size: 14, color: fg));
                  return Padding(
                    padding: EdgeInsets.only(left: 6 + titleInset, right: 6),
                    child: Row(
                      children: [
                        Icon(itemIcon(item), size: 15, color: fg),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            softWrap: false,
                            style: TextStyle(
                              color: fg,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontStyle: item.isOption ? FontStyle.italic : null,
                            ),
                          ),
                        ),
                        if (w > 110 && item.fixed) Icon(Icons.lock, size: 13, color: fg),
                        if (w > 110 && item.status == ItemStatus.booked) Icon(Icons.verified, size: 13, color: fg),
                        if (w > 80 && nights != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 2, right: 8),
                            child: Text('${nights}N', style: TextStyle(color: fg, fontSize: 11)),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (onResizeStart != null)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 16,
                child: _ResizeHandle(callbacks: onResizeStart!, color: fg),
              ),
            if (onResizeEnd != null)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 16,
                child: _ResizeHandle(callbacks: onResizeEnd!, color: fg),
              ),
          ],
        ),
      ),
    );
  }
}

/// Grip on the left/right edge of a block; reports the horizontal distance
/// dragged since the gesture started.
class _ResizeHandle extends StatefulWidget {
  final _ResizeCallbacks callbacks;
  final Color color;
  const _ResizeHandle({required this.callbacks, required this.color});

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  double _startX = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onHorizontalDragStart: (d) {
      _startX = d.globalPosition.dx;
      widget.callbacks.start();
    },
    onHorizontalDragUpdate: (d) => widget.callbacks.update(d.globalPosition.dx - _startX),
    onHorizontalDragEnd: (_) => widget.callbacks.end(),
    onHorizontalDragCancel: widget.callbacks.end,
    child: Center(
      child: Container(
        width: 3,
        height: 16,
        decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(2)),
      ),
    ),
  );
}

class _GapBox extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GapBox({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.outline;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: CustomPaint(
        painter: _DashedRectPainter(c),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 14, color: c),
                  Text(label, style: TextStyle(fontSize: 11, color: c)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MissingNight extends StatelessWidget {
  final VoidCallback onTap;
  const _MissingNight({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.error;
    return Tooltip(
      message: 'Noch keine Unterkunft für diese Nacht',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: CustomPaint(
          painter: _DashedRectPainter(c, radius: 18),
          child: Center(child: Icon(Icons.bed_outlined, size: 15, color: c)),
        ),
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  _DashedRectPainter(this.color, {this.radius = 8});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 5), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRectPainter old) => old.color != color;
}

class _DayHeader extends StatelessWidget {
  final int firstDay;
  final int lastDay;
  final double dayWidth;
  final DateTime? tripStart;
  final ValueChanged<int> onLongPress;

  const _DayHeader({
    required this.firstDay,
    required this.lastDay,
    required this.dayWidth,
    required this.tripStart,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return SizedBox(
      height: _headerH,
      child: Row(
        children: [
          for (var d = firstDay; d <= lastDay; d++)
            GestureDetector(
              onLongPress: () => onLongPress(d),
              child: SizedBox(
                width: dayWidth,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tag ${d + 1}', style: style?.copyWith(fontWeight: FontWeight.bold), maxLines: 1),
                      if (tripStart != null && dayWidth > 44)
                        Text(formatDay(tripStart, d), style: style, maxLines: 1, overflow: TextOverflow.clip),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Day separators, night shading (20:00–06:00) and weekend tint, so that
/// days vs. nights are visible behind all lanes.
class _GridPainter extends CustomPainter {
  final int firstDay;
  final double dayWidth;
  final double headerH;
  final DateTime? tripStart;
  final Color color;
  final int? today;

  _GridPainter({
    required this.firstDay,
    required this.dayWidth,
    required this.headerH,
    required this.tripStart,
    required this.color,
    required this.today,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final px = dayWidth / minutesPerDay;
    final line = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    final night = Paint()..color = color.withValues(alpha: 0.05);
    final weekend = Paint()..color = color.withValues(alpha: 0.03);
    final days = (size.width / dayWidth).ceil();
    for (var k = 0; k <= days; k++) {
      final x = k * dayWidth;
      final d = firstDay + k;
      if (tripStart != null) {
        final wd = dateOfDay(tripStart!, d).weekday;
        if (wd >= 6) canvas.drawRect(Rect.fromLTWH(x, 0, dayWidth, size.height), weekend);
      }
      // Night from 20:00 of this day to 06:00 of the next.
      canvas.drawRect(Rect.fromLTWH(x + 20 * 60 * px, headerH, 10 * 60 * px, size.height - headerH), night);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    if (today != null) {
      final x = (today! - firstDay) * dayWidth + 12 * 60 * px;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = Colors.redAccent
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.firstDay != firstDay ||
      old.dayWidth != dayWidth ||
      old.tripStart != tripStart ||
      old.color != color ||
      old.today != today;
}

class _Toolbar extends ConsumerWidget {
  final ShiftMode mode;
  final List<Conflict> conflicts;
  final TripData data;
  final String? dragLabel;
  final ValueChanged<double> onZoom;

  const _Toolbar({
    required this.mode,
    required this.conflicts,
    required this.data,
    required this.dragLabel,
    required this.onZoom,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          children: [
            PopupMenuButton<ShiftMode>(
              tooltip: 'Verschiebe-Modus',
              initialValue: mode,
              onSelected: ref.read(tripUiProvider.notifier).setShiftMode,
              itemBuilder: (_) => [for (final m in ShiftMode.values) PopupMenuItem(value: m, child: Text(m.label))],
              child: Chip(
                avatar: const Icon(Icons.swap_horiz, size: 18),
                label: Text(mode.shortLabel),
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 8),
            if (dragLabel != null)
              Expanded(
                child: Text(
                  dragLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.primary, fontWeight: FontWeight.bold),
                ),
              )
            else ...[
              if (conflicts.isNotEmpty)
                ActionChip(
                  avatar: Icon(Icons.warning_amber, color: scheme.error, size: 18),
                  label: Text('${conflicts.length} Konflikt${conflicts.length == 1 ? '' : 'e'}'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showConflicts(context, ref),
                ),
              const Spacer(),
            ],
            IconButton(tooltip: 'Verkleinern', onPressed: () => onZoom(1 / 1.3), icon: const Icon(Icons.zoom_out)),
            IconButton(tooltip: 'Vergrößern', onPressed: () => onZoom(1.3), icon: const Icon(Icons.zoom_in)),
          ],
        ),
      ),
    );
  }

  void _showConflicts(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          for (final k in conflicts)
            ConflictTile(
              conflict: k,
              data: data,
              onFixed: () => Navigator.pop(c),
              onTap: () {
                Navigator.pop(c);
                showItemSheet(context, ref, data.trip.id, k.itemId);
              },
            ),
        ],
      ),
    );
  }
}

class _UnscheduledTray extends ConsumerWidget {
  final List<PlanItem> items;
  final String tripId;
  const _UnscheduledTray({required this.items, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        children: [
          const Center(
            child: Padding(padding: EdgeInsets.only(right: 8), child: Text('Ohne Termin:')),
          ),
          for (final i in items)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ActionChip(
                avatar: Icon(itemIcon(i), size: 16, color: kindColor(i.kind)),
                label: Text(i.title),
                visualDensity: VisualDensity.compact,
                onPressed: () => showItemSheet(context, ref, tripId, i.id),
              ),
            ),
        ],
      ),
    ),
  );
}
