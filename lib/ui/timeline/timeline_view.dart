import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/analysis.dart';
import '../../domain/models.dart';
import '../../domain/zones.dart';
import '../../domain/scheduler.dart';
import '../../domain/time.dart';
import '../../domain/timeline.dart';
import '../../state/hints.dart';
import '../../state/providers.dart';
import '../common/a11y.dart';
import '../common/conflict_tile.dart';
import '../common/dashed_border.dart';
import '../common/dialogs.dart';
import '../common/hint_banner.dart';
import '../common/item_sheet.dart';
import '../common/l10n.dart';
import '../common/schedule_sheet.dart';
import '../common/style.dart';
import '../common/theme.dart';
import '../editor/item_editor_page.dart';
import '../trip/trip_page.dart';

const _headerH = 52.0;
const _labelW = 40.0;
const _lanePad = 6.0;

/// Touch width of a resize grip (centred on the block edge).
const _handleW = 24.0;

/// Minimum width of a "+ Transport" marker, so it stays tappable.
const _transportGapMinW = 84.0;

/// Blocks narrower than this show their title next to them when the row
/// has room there.
const _spillBelowW = 56.0;

/// Minimum free space for a title next to a block.
const _spillMinW = 30.0;

/// Widest title next to a block.
const _spillMaxW = 180.0;

/// Row heights grow with the system text size (up to 2×), so titles keep
/// fitting their blocks.
double _textScale(BuildContext context) => (MediaQuery.textScalerOf(context).scale(12) / 12).clamp(1.0, 2.0);

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
      _DragType.move => Scheduler.move(data.items, id, _dragMinutes, m, zones: data.zones),
      _DragType.resizeEnd => Scheduler.resizeEnd(data.items, id, _dragMinutes, m, zones: data.zones),
      _DragType.resizeStart => Scheduler.resizeStart(data.items, id, _dragMinutes, zones: data.zones),
    };
  }

  /// "+1 day → Wed, Mar 12, 14:00" while dragging.
  String _dragLabel(ScheduleResult? preview) {
    final l = context.l10n;
    if (_dragMinutes == 0) return l.dragging;
    final amount = l.duration(_dragMinutes.abs(), withMinutes: true);
    final item = preview?.items.where((i) => i.id == _dragId).firstOrNull;
    final at = item == null
        ? ''
        : ' → ${l.moment(data.trip.startDate, _dragType == _DragType.resizeEnd ? item.end! : item.start!)}';
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

  /// A night without a bed: offer the options covering it first, else
  /// (or on request) create a new accommodation.
  void _onMissingNight(TripData data, int night, PlanItem? stay) {
    void create() => openItemEditor(context, data, newKind: ItemKind.accommodation, atDay: night, parentHint: stay?.id);
    final options = optionsForNight(data.items, night);
    if (options.isEmpty) {
      create();
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => _NightOptionsSheet(
        title: context.l10n.nightTitle(
          context.l10n.day(data.trip.startDate, night),
          context.l10n.day(data.trip.startDate, night + 1),
        ),
        options: options,
        tripStart: data.trip.startDate,
        onChoose: (o) {
          Navigator.pop(c);
          chooseAccommodation(context, ref, data, o);
        },
        onDetails: (o) {
          Navigator.pop(c);
          showItemSheet(context, ref, data.trip.id, o.id);
        },
        onCreate: () {
          Navigator.pop(c);
          create();
        },
      ),
    );
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
    final l = context.l10n;
    final label = switch (_dragType!) {
      _DragType.move => l.stepMoved(item.title),
      _DragType.resizeEnd => l.stepEndChanged(item.title),
      _DragType.resizeStart => l.stepStartChanged(item.title),
    };
    await actions.applySchedule(data, r, label);
    if (!mounted) return;
    final others = r.changedIds.length - 1;
    final conflicts = findConflicts(r.items, zones: data.zones).length;
    showSnack(
      context,
      [label, if (others > 0) l.othersMovedAlong(others), if (conflicts > 0) l.conflictsCount(conflicts)].join(' · '),
      action: SnackBarAction(label: l.undo, onPressed: () => actions.undo(data.trip.id)),
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
    final conflicts = findConflicts(items, zones: data.zones);
    final conflictIds = {
      for (final c in conflicts) ...[c.itemId, ?c.otherId],
    };

    ref.listen(tripUiProvider.select((u) => (u.selectedId, u.view)), (prev, next) {
      if (next.$2 == TripView.timeline && next != prev) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(data.item(next.$1), firstDay));
      }
    });

    final missingNights = uncoveredNights(items);
    final transportGaps = missingTransports(items, zones: data.zones);
    final lanes = <_LaneSpec>[];
    for (final k in ItemKind.values) {
      if (!ui.layers.contains(k)) continue;
      final laneItems = [
        for (final i in items)
          if (i.kind == k && i.isScheduled && ui.shows(i)) i,
      ];
      final (rows, count) = packLanes(laneItems);
      // Lodging gets an extra row for "no bed yet" markers.
      // Transport gets one for "+ Transport" markers between stays.
      final extra = switch (k) {
        ItemKind.accommodation when missingNights.isNotEmpty => 1,
        ItemKind.transport when transportGaps.isNotEmpty => 1,
        _ => 0,
      };
      lanes.add(_LaneSpec(k, laneItems, rows, (laneItems.isEmpty ? 0 : count) + extra));
    }
    final unscheduled = [
      for (final i in data.items)
        if (!i.isScheduled && ui.shows(i)) i,
    ];

    double x(int minute) => (minute - firstDay * minutesPerDay) * _pxPerMin;
    final scale = _textScale(context);
    final headerH = _headerH * scale;
    final hasStays = data.items.any((i) => i.kind == ItemKind.stay);
    final hasScheduled = data.items.any((i) => i.isScheduled);

    final laneWidgets = <Widget>[];
    final labelWidgets = <Widget>[];
    for (final lane in lanes) {
      final rowH = _rowHeight(lane.kind) * scale;
      final room = labelRoom(lane.items, lane.rows);
      final h = (lane.rowCount < 1 ? 1 : lane.rowCount) * rowH + 2 * _lanePad;
      final children = <Widget>[];

      if (lane.kind == ItemKind.stay) {
        for (final g in findGaps(items, plannedDays: data.trip.plannedDays)) {
          if (g.firstDay < firstDay) continue;
          children.add(
            Positioned(
              key: ValueKey('free-days-${g.firstDay}'),
              left: x(at(g.firstDay, 0)) + 3,
              width: g.days * _dayWidth - 6,
              top: _lanePad,
              height: rowH - 6,
              child: _GapBox(
                label: context.l10n.freeDays(g.days),
                onTap: () => showAddSheet(context, ref, data, atDay: g.firstDay),
              ),
            ),
          );
        }
      }
      if (lane.kind == ItemKind.accommodation) {
        for (final n in missingNights) {
          final stay = stayChain(
            items,
            zones: data.zones,
          ).where((s) => dayOf(s.start!) <= n && n < lastDayOf(s.end!)).firstOrNull;
          children.add(
            Positioned(
              left: x(at(n, 19 * 60)),
              width: 13 * 60 * _pxPerMin,
              top: _lanePad + (lane.rowCount - 1) * rowH,
              height: rowH - 6,
              child: _MissingNight(
                key: ValueKey('missing-night-$n'),
                night: context.l10n.nightTitle(
                  context.l10n.day(data.trip.startDate, n),
                  context.l10n.day(data.trip.startDate, n + 1),
                ),
                options: optionsForNight(items, n).length,
                onTap: () => _onMissingNight(data, n, stay),
              ),
            ),
          );
        }
      }

      if (lane.kind == ItemKind.transport) {
        for (final g in transportGaps) {
          // Centered between leaving the one stay and reaching the next,
          // wide enough to tap even when they touch.
          final mid = (x(g.from.end!) + x(g.to.start!)) / 2;
          final w = math.max((x(g.to.start!) - x(g.from.end!)).abs(), _transportGapMinW);
          children.add(
            Positioned(
              key: ValueKey('transport-gap-${g.from.id}-${g.to.id}'),
              left: mid - w / 2,
              width: w,
              top: _lanePad + (lane.rowCount - 1) * rowH,
              height: rowH - 6,
              child: _GapBox(
                label: context.l10n.kindTransport,
                tooltip: context.l10n.noTransportBetween(g.from.title, g.to.title),
                onTap: () => openTransportEditor(context, data, from: g.from, to: g.to),
              ),
            ),
          );
        }
      }

      final handles = <Widget>[];
      for (final i in lane.items) {
        final left = x(i.start!);
        final width = math.max(i.duration * _pxPerMin, 26.0);
        final row = lane.rows[i.id] ?? 0;
        final draggable = !i.fixed;
        // Free space until the next block in this row (or the end).
        final roomPx = room[i.id] == null ? totalW - left : room[i.id]! * _pxPerMin;
        final spillW = math.min(roomPx - width - 6, _spillMaxW);
        final spill =
            lane.kind != ItemKind.stay && width < _spillBelowW && spillW >= _spillMinW && i.title.trim().isNotEmpty;
        if (spill) {
          children.add(
            Positioned(
              key: ValueKey('label-${i.id}'),
              left: left + width + 3,
              width: spillW,
              top: _lanePad + row * rowH,
              height: rowH - 6,
              child: _SpillLabel(item: i, onTap: () => showItemSheet(context, ref, data.trip.id, i.id)),
            ),
          );
        }
        children.add(
          Positioned(
            key: ValueKey(i.id),
            left: left,
            width: width,
            top: _lanePad + row * rowH,
            height: rowH - 6,
            child: _Block(
              titleInset: (_scrollX - left).clamp(0, math.max(0, width - 90)),
              // A place's name may run on above the line up to the next place.
              titleWidth: lane.kind == ItemKind.stay ? math.max(width, roomPx - 6) : width,
              titleOutside: spill,
              item: i,
              tripStart: data.trip.startDate,
              selected: ui.selectedId == i.id,
              conflict: conflictIds.contains(i.id),
              moving: changed.contains(i.id),
              // Screen readers move items with these instead of dragging.
              semanticActions: _dragId == null ? itemShiftActions(context, ref, data, i) : const {},
              onTap: () => showItemSheet(context, ref, data.trip.id, i.id),
              onLongPressStart: () {
                if (!draggable) {
                  showSnack(context, context.l10n.itemIsFixed(i.title));
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
            ),
          ),
        );
        // Resize grips only on the selected block, so swipes over other
        // blocks keep scrolling the timeline.
        if (draggable && ui.selectedId == i.id) {
          final top = _lanePad + row * rowH;
          Widget handle(_DragType type, double centerX) => Positioned(
            key: ValueKey('${type.name}-${i.id}'),
            left: centerX - _handleW / 2,
            width: _handleW,
            top: top,
            height: rowH - 6,
            child: _ResizeHandle(
              callbacks: _ResizeCallbacks(
                start: () => _startDrag(i, type),
                update: (dx) => _dragTo(i, dx),
                end: () => _commitDrag(ui.shiftMode),
              ),
              color: kindColor(i.kind),
            ),
          );
          // Narrow blocks keep only the end grip, so the body stays grabbable.
          if (width >= 48) handles.add(handle(_DragType.resizeStart, left));
          handles.add(handle(_DragType.resizeEnd, left + width));
        }
      }
      children.addAll(handles);

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
            message: context.l10n.layer(lane.kind),
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
        const HintBanner(hint: Hint.timeline),
        if (!hasStays && hasScheduled) _EmptyTimeline(data: data, compact: true),
        if (!hasStays && !hasScheduled)
          Expanded(child: _EmptyTimeline(data: data))
        else
          Expanded(
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _labelW,
                    child: Column(
                      children: [
                        SizedBox(height: headerH),
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
                                    headerH: headerH,
                                    tripStart: data.trip.startDate,
                                    color: Theme.of(context).colorScheme.onSurface,
                                    nightColor: AppColors.of(context).night,
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
                                    height: headerH,
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
        if (unscheduled.isNotEmpty) _UnscheduledTray(items: unscheduled, data: data),
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

  /// Custom screen-reader actions ("1 Tag später/früher").
  final Map<CustomSemanticsAction, VoidCallback> semanticActions;

  /// Pushes the title right when the block starts left of the viewport.
  final double titleInset;

  /// Space for the title; wider than the block for places, whose name may
  /// run on above the line.
  final double? titleWidth;

  /// The title is drawn next to the block ([_SpillLabel]); show the icon.
  final bool titleOutside;

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
    this.semanticActions = const {},
    this.titleInset = 0,
    this.titleWidth,
    this.titleOutside = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final base = kindColor(item.kind);
    // Options and ideas: opaque tint, dashed outline and status icon, so
    // they stand out by shape too, and their text keeps 4.5:1 contrast.
    final option = isTentative(item);
    final bg = option ? tentativeFill(base, brightness) : base;
    final fg = option ? tentativeInk(base, brightness) : Colors.white;
    final borderColor = conflict
        ? scheme.error
        : selected
        ? scheme.onSurface
        : Colors.transparent;
    final dashed = option && !conflict && !selected;
    final radius = item.kind == ItemKind.accommodation ? 18.0 : 8.0;
    final nights = item.kind == ItemKind.stay || item.kind == ItemKind.accommodation
        ? nightsIn(item.start!, item.end!)
        : null;

    final rail = item.kind == ItemKind.stay;
    final ink = scheme.onSurface;

    final block = GestureDetector(
      // Semantics come from the wrapper below (label, tap, custom actions);
      // a semantic long press would only start a drag that never moves.
      excludeFromSemantics: true,
      onTap: onTap,
      onLongPressStart: (_) => onLongPressStart(),
      onLongPressMoveUpdate: (d) => onLongPressMove(d.offsetFromOrigin.dx),
      onLongPressEnd: (_) => onLongPressEnd(),
      onLongPressCancel: onLongPressEnd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: rail
            // Stays are drawn as a transit line; the box only shows state.
            ? BoxDecoration(
                color: selected || moving ? scheme.surfaceContainerHigh : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: conflict ? Border.all(color: scheme.error, width: 2) : null,
              )
            : BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: borderColor, width: conflict || selected ? 2 : 1),
                boxShadow: moving ? [BoxShadow(color: base.withValues(alpha: 0.5), blurRadius: 8)] : null,
              ),
        child: CustomPaint(
          foregroundPainter: dashed && !rail ? DashedBorderPainter(fg, radius: radius, strokeWidth: 1.5) : null,
          child: LayoutBuilder(
            builder: (context, c) =>
                rail ? _rail(context, c.maxWidth, base, option, ink, nights) : _box(context, c.maxWidth, fg, nights),
          ),
        ),
      ),
    );
    return Semantics(
      key: ValueKey('block-semantics-${item.id}'),
      container: true,
      button: true,
      selected: selected,
      label: itemSemanticsLabel(context.l10n, item, tripStart: tripStart, conflict: conflict),
      onTapHint: context.l10n.a11yHintDetails,
      onTap: onTap,
      customSemanticsActions: semanticActions.isEmpty ? null : semanticActions,
      excludeSemantics: true,
      child: block,
    );
  }

  /// A stay: name above a thick line with a station at each end; the
  /// number of nights sits on the line itself.
  Widget _rail(BuildContext context, double w, Color base, bool option, Color ink, int? nights) {
    final line = option ? base.withValues(alpha: 0.7) : base;
    final station = Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: line, width: 4),
      ),
    );
    final textW = math.max(0.0, (titleWidth ?? w) - 8 - titleInset);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 4 + titleInset,
          width: textW,
          top: 2,
          child: Row(
            children: [
              Flexible(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    color: ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    fontStyle: item.isOption ? FontStyle.italic : null,
                  ),
                ),
              ),
              if (w > 110 && item.fixed)
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Icon(Icons.lock, size: 13, color: ink),
                ),
            ],
          ),
        ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          height: 8,
          // A tentative place is a dashed line, like a planned route.
          child: option
              ? CustomPaint(painter: DashedLinePainter(line))
              : DecoratedBox(
                  decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(4)),
                ),
        ),
        Positioned(left: 0, bottom: 4, child: station),
        Positioned(right: 0, bottom: 4, child: station),
        // Between the stations, so it clearly belongs to this place.
        if (nights != null && nights > 0 && w >= 52)
          Positioned(
            left: 16,
            right: 16,
            bottom: 5,
            child: Center(
              child: _NightsBadge(
                key: ValueKey('nights-${item.id}'),
                nights: nights,
                // Solid even for options, so white text keeps its contrast.
                color: base,
                textColor: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  /// Transport, lodging and activities: a filled block. Narrow ones show the
  /// title whenever it still fits a few letters, else only the icon (the
  /// title then runs next to the block, see [titleOutside]).
  Widget _box(BuildContext context, double w, Color fg, int? nights) {
    final icon = Icon(isTentative(item) ? statusIcon(item.status) : itemIcon(item), size: 15, color: fg);
    final title = Text(
      item.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: TextStyle(
        color: fg,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        fontStyle: item.isOption ? FontStyle.italic : null,
      ),
    );
    if (titleOutside || w < 30 || item.title.trim().isEmpty) return Center(child: icon);
    // Too narrow for icon and title: the title wins.
    if (w < 64) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Align(alignment: Alignment.centerLeft, child: title),
      );
    }
    return Padding(
      padding: EdgeInsets.only(left: 6 + titleInset, right: 6),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 4),
          Expanded(child: title),
          if (w > 110 && item.fixed) Icon(Icons.lock, size: 13, color: fg),
          if (w > 110 && item.status == ItemStatus.booked) Icon(Icons.verified, size: 13, color: fg),
          if (w > 96 && nights != null && nights > 0)
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 8),
              child: _NightsBadge(
                key: ValueKey('nights-${item.id}'),
                nights: nights,
                // Darkens filled blocks (white text stays >= 4.5:1).
                color: isTentative(item) ? fg.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.2),
                textColor: fg,
              ),
            ),
        ],
      ),
    );
  }
}

/// "2N" as a small pill on its place's line / inside its lodging block.
class _NightsBadge extends StatelessWidget {
  final int nights;
  final Color color;
  final Color textColor;
  const _NightsBadge({super.key, required this.nights, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: context.l10n.nights(nights),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)),
      child: Text(
        context.l10n.nightsShort(nights),
        maxLines: 1,
        softWrap: false,
        style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.w800, height: 1.4),
      ),
    ),
  );
}

/// The title of a narrow block, drawn in the free space right of it.
class _SpillLabel extends StatelessWidget {
  final PlanItem item;
  final VoidCallback onTap;
  const _SpillLabel({required this.item, required this.onTap});

  @override
  // The block itself carries the title for screen readers.
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    excludeFromSemantics: true,
    behavior: HitTestBehavior.translucent,
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          fontStyle: item.isOption || item.status == ItemStatus.idea ? FontStyle.italic : null,
        ),
      ),
    ),
  );
}

/// No places yet: explains the timeline and offers to add the first one.
/// [compact] = a banner above a timeline that already has other items.
class _EmptyTimeline extends StatelessWidget {
  final TripData data;
  final bool compact;
  const _EmptyTimeline({required this.data, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final action = FilledButton.icon(
      key: const ValueKey('timeline-add-first-stay'),
      onPressed: () => openItemEditor(context, data, newKind: ItemKind.stay, atDay: 0),
      icon: const Icon(Icons.add_location_alt),
      label: Text(l.timelineEmptyAction),
    );
    if (compact) {
      return Material(
        color: theme.colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          // Wraps the button below the text on narrow screens / big text.
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(kindIcon(ItemKind.stay), color: kindColor(ItemKind.stay)),
                  const SizedBox(width: 12),
                  Flexible(child: Text(l.timelineEmptyTitle, style: theme.textTheme.titleSmall)),
                ],
              ),
              action,
            ],
          ),
        ),
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.view_timeline_outlined, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(l.timelineEmptyTitle, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(l.timelineEmptyBody, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            action,
          ],
        ),
      ),
    );
  }
}

/// Visible grip centred on the left/right edge of the selected block;
/// reports the horizontal distance dragged since the gesture started. The
/// whole (>= 24 dp wide) area is touchable, the pill shows where.
class _ResizeHandle extends StatefulWidget {
  final _ResizeCallbacks callbacks;

  /// Outline colour of the pill (the block's kind colour).
  final Color color;
  const _ResizeHandle({required this.callbacks, required this.color});

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  double _startX = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Screen readers use the block's "1 Tag später/früher" actions instead.
    return GestureDetector(
      excludeFromSemantics: true,
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
          width: 12,
          height: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 1),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: widget.color, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
          ),
          child: Center(
            child: Container(
              width: 2,
              height: 10,
              decoration: BoxDecoration(color: scheme.onSurface, borderRadius: BorderRadius.circular(1)),
            ),
          ),
        ),
      ),
    );
  }
}

class _GapBox extends StatelessWidget {
  final String label;
  final String? tooltip;
  final VoidCallback onTap;
  const _GapBox({required this.label, this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.outline;
    final box = InkWell(
      onTap: onTap,
      excludeFromSemantics: true,
      borderRadius: BorderRadius.circular(8),
      child: CustomPaint(
        painter: DashedBorderPainter(c.withValues(alpha: 0.7), dash: 5, gap: 4),
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
    return Semantics(
      container: true,
      button: true,
      label: tooltip ?? label,
      onTapHint: context.l10n.a11yHintAdd,
      onTap: onTap,
      excludeSemantics: true,
      child: tooltip == null ? box : Tooltip(message: tooltip!, excludeFromSemantics: true, child: box),
    );
  }
}

/// Lists the accommodation options for one night plus "Neue Unterkunft".
class _NightOptionsSheet extends StatelessWidget {
  final String title;
  final List<PlanItem> options;
  final DateTime? tripStart;
  final ValueChanged<PlanItem> onChoose;
  final ValueChanged<PlanItem> onDetails;
  final VoidCallback onCreate;
  const _NightOptionsSheet({
    required this.title,
    required this.options,
    required this.tripStart,
    required this.onChoose,
    required this.onDetails,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(l.noAccommodationTonight),
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Text(l.chooseOption, style: theme.textTheme.titleSmall),
          ),
          for (final o in options)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(itemIcon(o), color: kindColor(o.kind).withValues(alpha: 0.5)),
              title: Text(o.title, style: const TextStyle(fontStyle: FontStyle.italic)),
              subtitle: Text(timeSummary(l, o, tripStart)),
              onTap: () => onDetails(o),
              trailing: TextButton(onPressed: () => onChoose(o), child: Text(l.choose)),
            ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.add),
            title: Text(l.newAccommodation),
            onTap: onCreate,
          ),
        ],
      ),
    );
  }
}

class _MissingNight extends StatelessWidget {
  /// "Night Wed → Thu", spoken before the tooltip text.
  final String night;

  /// Number of accommodation options covering this night.
  final int options;
  final VoidCallback onTap;
  const _MissingNight({super.key, required this.night, required this.options, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final message = context.l10n.noAccommodationOptions(options);
    return Semantics(
      container: true,
      button: true,
      label: '$night: $message',
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: message,
        excludeFromSemantics: true,
        child: Material(
          color: colors.signal,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bed_outlined, size: 15, color: colors.onSignal),
                    Text(
                      options == 0 ? '!' : ' $options?',
                      style: TextStyle(color: colors.onSignal, fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final int firstDay;
  final int lastDay;
  final double dayWidth;
  final double height;
  final DateTime? tripStart;
  final ValueChanged<int> onLongPress;

  const _DayHeader({
    required this.firstDay,
    required this.lastDay,
    required this.dayWidth,
    required this.height,
    required this.tripStart,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    final number = TextStyle(
      fontSize: dayWidth > 44 ? 22 : 16,
      fontWeight: FontWeight.w900,
      letterSpacing: -1,
      height: 1.1,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: Theme.of(context).colorScheme.onSurface,
    );
    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (var d = firstDay; d <= lastDay; d++)
            Semantics(
              container: true,
              label: context.l10n.day(tripStart, d, withDayNumber: tripStart != null),
              onLongPressHint: context.l10n.a11yHintAddOnDay,
              onLongPress: () => onLongPress(d),
              excludeSemantics: true,
              child: GestureDetector(
                excludeFromSemantics: true,
                onLongPress: () => onLongPress(d),
                child: SizedBox(
                  width: dayWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((d + 1).toString().padLeft(2, '0'), style: number, maxLines: 1),
                        if (tripStart != null && dayWidth > 44)
                          Text(
                            context.l10n.day(tripStart, d),
                            style: style,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
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
  final Color nightColor;
  final int? today;

  _GridPainter({
    required this.firstDay,
    required this.dayWidth,
    required this.headerH,
    required this.tripStart,
    required this.color,
    required this.nightColor,
    required this.today,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final px = dayWidth / minutesPerDay;
    final line = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    final night = Paint()..color = nightColor;
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
          ..color = const Color(0xFFFFC21A)
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.firstDay != firstDay ||
      old.dayWidth != dayWidth ||
      old.tripStart != tripStart ||
      old.color != color ||
      old.nightColor != nightColor ||
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
    final l = context.l10n;
    final shiftChip = PopupMenuButton<ShiftMode>(
      tooltip: l.shiftModeTooltip,
      initialValue: mode,
      onSelected: ref.read(tripUiProvider.notifier).setShiftMode,
      itemBuilder: (_) => [for (final m in ShiftMode.values) PopupMenuItem(value: m, child: Text(l.shiftMode(m)))],
      child: Chip(
        avatar: const Icon(Icons.swap_horiz, size: 18),
        label: Text(l.shiftModeShort(mode), maxLines: 1, overflow: TextOverflow.ellipsis),
        visualDensity: VisualDensity.compact,
      ),
    );
    return Material(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          children: [
            // The chips sit in their own row; the mode chip shrinks (ellipsis)
            // so longer wordings still leave room for the zoom buttons on a
            // 360 dp phone.
            Expanded(
              child: Row(
                children: [
                  if (dragLabel == null) Flexible(child: shiftChip) else shiftChip,
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
                  else if (conflicts.isNotEmpty)
                    ActionChip(
                      avatar: Icon(Icons.warning_amber, color: scheme.error, size: 18),
                      label: Text(l.conflictsCount(conflicts.length)),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _showConflicts(context, ref),
                    ),
                ],
              ),
            ),
            IconButton(tooltip: l.zoomOut, onPressed: () => onZoom(1 / 1.3), icon: const Icon(Icons.zoom_out)),
            IconButton(tooltip: l.zoomIn, onPressed: () => onZoom(1.3), icon: const Icon(Icons.zoom_in)),
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
  final TripData data;
  const _UnscheduledTray({required this.items, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: SizedBox(
      height: 52 * _textScale(context),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        children: [
          Center(
            child: Padding(padding: const EdgeInsets.only(right: 8), child: Text(context.l10n.unscheduledLabel)),
          ),
          for (final i in items)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ActionChip(
                key: ValueKey('tray-${i.id}'),
                avatar: Icon(itemIcon(i), size: 16, color: kindColor(i.kind)),
                label: Text(i.title),
                tooltip: context.l10n.scheduleOnEllipsis,
                visualDensity: VisualDensity.compact,
                // "Schedule on …" with the details one tap further.
                onPressed: () => showScheduleSheet(context, ref, data, i),
              ),
            ),
        ],
      ),
    ),
  );
}
