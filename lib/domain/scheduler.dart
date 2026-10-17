// Ripple scheduling: moving or stretching one part of the plan moves what
// comes after it, while fixed items (booked tours, the flight home) stay put.
//
// Terminology
// * root      – a scheduled, non-option item without an anchor (normally a
//               stay; also unattached activities/transports). Roots form the
//               trip's sequence and are what ripples.
// * children  – items anchored to another item (lodging/activities via
//               parentId, transports via their destination). They always
//               travel with their anchor unless they are fixed.
//
// Items move by local minutes (a day later is a day later in any zone), but
// order and overlaps are judged on absolute time (zones.dart), so a flight
// that lands "earlier" in local time still comes after its departure.
import 'models.dart';
import 'time.dart';
import 'zones.dart';

enum ShiftMode {
  /// Everything after the changed item moves by the same amount.
  following,

  /// Only push what would overlap; free days in between absorb the change.
  push,

  /// Only the item itself (and its children) moves.
  single,
}

class ScheduleResult {
  final List<PlanItem> items;
  final Set<String> changedIds;
  const ScheduleResult(this.items, this.changedIds);

  List<PlanItem> get changed => [for (final i in items) if (changedIds.contains(i.id)) i];
}

class Scheduler {
  final Map<String, PlanItem> _byId;
  final Map<String, List<String>> _children = {};
  final List<PlanItem> _original;
  final Map<String, PlanItem> _updated = {};
  final Set<String> _added = {};
  final TripZones _zones;

  Scheduler._(List<PlanItem> items, TripZones? zones)
      : _original = items,
        _zones = zones ?? TripZones.none,
        _byId = {for (final i in items) i.id: i} {
    for (final i in items) {
      final a = i.anchorId;
      if (a != null && _byId.containsKey(a) && a != i.id) {
        _children.putIfAbsent(a, () => []).add(i.id);
      }
    }
  }

  /// Moves item [id] by [delta] minutes.
  static ScheduleResult move(List<PlanItem> items, String id, int delta, ShiftMode mode, {TripZones? zones}) {
    final s = Scheduler._(items, zones);
    final target = s._byId[id];
    if (target == null || !target.isScheduled || delta == 0) return s._result();

    final followers = s._followersOf(target);
    s._moveWithChildren(target, delta, isTarget: true);
    if (s._isRoot(target)) {
      switch (mode) {
        case ShiftMode.following:
          for (final f in followers) {
            if (!f.fixed) s._moveWithChildren(f, delta);
          }
        case ShiftMode.push:
          if (delta > 0) s._pushFrom(s._absEnd(s._current(target.id)), followers);
        case ShiftMode.single:
          break;
      }
    }
    return s._result();
  }

  /// Moves the end of item [id] by [delta] minutes (longer / shorter stay).
  static ScheduleResult resizeEnd(List<PlanItem> items, String id, int delta, ShiftMode mode, {TripZones? zones}) {
    final s = Scheduler._(items, zones);
    final target = s._byId[id];
    if (target == null || !target.isScheduled || delta == 0) return s._result();

    final newEnd = (target.end! + delta).clamp(s._zones.earliestEnd(target, 60), 1 << 40);
    final effective = newEnd - target.end!;
    if (effective == 0) return s._result();
    s._set(target.copyWith(end: newEnd));

    if (s._isRoot(target)) {
      final followers = s._followersOf(target);
      switch (mode) {
        case ShiftMode.following:
          for (final f in followers) {
            if (!f.fixed) s._moveWithChildren(f, effective);
          }
        case ShiftMode.push:
          if (effective > 0) s._pushFrom(s._absEnd(s._current(target.id)), followers);
        case ShiftMode.single:
          break;
      }
    }
    return s._result();
  }

  /// Moves the start of item [id] by [delta] minutes (arrive earlier/later).
  /// Only the item changes; overlaps show up as conflicts.
  static ScheduleResult resizeStart(List<PlanItem> items, String id, int delta, {TripZones? zones}) {
    final s = Scheduler._(items, zones);
    final target = s._byId[id];
    if (target == null || !target.isScheduled || delta == 0) return s._result();
    final latest = s._zones.latestStart(target, 60);
    final newStart = target.start! + delta < latest ? target.start! + delta : latest;
    if (newStart != target.start) s._set(target.copyWith(start: newStart));
    return s._result();
  }

  /// Sets new start/end for [id] (e.g. from the editor) and ripples.
  static ScheduleResult reschedule(
    List<PlanItem> items,
    String id,
    int newStart,
    int newEnd,
    ShiftMode mode, {
    TripZones? zones,
  }) {
    final item = items.where((i) => i.id == id).firstOrNull;
    if (item == null) return ScheduleResult(items, const {});
    if (!item.isScheduled) {
      final placed = item.copyWith(start: newStart, end: newEnd);
      return insert([for (final i in items) if (i.id != id) i], placed, mode, zones: zones);
    }
    final moved = move(items, id, newStart - item.start!, mode, zones: zones);
    final afterMove = moved.items.firstWhere((i) => i.id == id);
    final resized = resizeEnd(moved.items, id, newEnd - afterMove.end!, mode, zones: zones);
    return ScheduleResult(resized.items, {...moved.changedIds, ...resized.changedIds});
  }

  /// Adds [newItem] and makes room for it after its start.
  static ScheduleResult insert(List<PlanItem> items, PlanItem newItem, ShiftMode mode, {TripZones? zones}) {
    final s = Scheduler._([...items, newItem], zones);
    s._added.add(newItem.id);
    if (!newItem.isScheduled || !s._isRoot(newItem)) return s._result();

    final followers = s._followersOf(newItem, inclusive: true);
    switch (mode) {
      case ShiftMode.following:
        final first = followers.where((f) => !f.fixed).firstOrNull;
        if (first != null) {
          final overlap = s._absEnd(newItem) - s._absStart(first);
          if (overlap > 0) {
            final shift = _ceilDays(overlap);
            for (final f in followers) {
              if (!f.fixed) s._moveWithChildren(f, shift);
            }
          }
        }
      case ShiftMode.push:
        s._pushFrom(s._absEnd(newItem), followers);
      case ShiftMode.single:
        break;
    }
    return s._result();
  }

  // ---------------------------------------------------------------------------

  PlanItem _current(String id) => _updated[id] ?? _byId[id]!;

  void _set(PlanItem item) => _updated[item.id] = item;

  int _absStart(PlanItem i) => _zones.absStart(i);
  int _absEnd(PlanItem i) => _zones.absEnd(i);

  bool _isRoot(PlanItem item) {
    final a = item.anchorId;
    return item.isScheduled && !item.isOption && (a == null || !_byId.containsKey(a));
  }

  /// Roots that start after [target], ordered by their original start.
  /// With [inclusive], items starting at the same moment count as well
  /// (used when inserting in front of them).
  List<PlanItem> _followersOf(PlanItem target, {bool inclusive = false}) {
    final t = _absStart(target);
    final list = [
      for (final i in _original)
        if (i.id != target.id && _isRoot(i) && (_absStart(i) > t || (inclusive && _absStart(i) == t))) i,
    ]..sort((a, b) => _absStart(a).compareTo(_absStart(b)));
    return list;
  }

  void _moveWithChildren(PlanItem item, int delta, {bool isTarget = false}) {
    final visited = <String>{};
    void visit(String id, bool direct) {
      if (!visited.add(id)) return;
      final cur = _current(id);
      if (!direct && cur.fixed) return;
      if (cur.isScheduled) _set(cur.shiftedBy(delta));
      for (final c in _children[id] ?? const <String>[]) {
        visit(c, false);
      }
    }

    visit(item.id, isTarget);
  }

  /// Pushes followers that would overlap the region ending at absolute
  /// minute [cursorEnd], in whole days so their time of day stays the same.
  void _pushFrom(int cursorEnd, List<PlanItem> followers) {
    var cursor = cursorEnd;
    for (final f in followers) {
      final cur = _current(f.id);
      if (cur.fixed) {
        if (_absEnd(cur) > cursor) cursor = _absEnd(cur);
        continue;
      }
      final overlap = cursor - _absStart(cur);
      if (overlap <= 0) break;
      final shift = _ceilDays(overlap);
      _moveWithChildren(cur, shift);
      cursor = _absEnd(_current(f.id));
    }
  }

  static int _ceilDays(int minutes) =>
      ((minutes + minutesPerDay - 1) ~/ minutesPerDay) * minutesPerDay;

  ScheduleResult _result() {
    final changed = <String>{
      ..._added,
      for (final e in _updated.entries)
        if (_byId[e.key]!.start != e.value.start || _byId[e.key]!.end != e.value.end) e.key,
    };
    final items = [
      for (final i in _original) _updated[i.id] ?? i,
    ];
    return ScheduleResult(items, changed);
  }
}
