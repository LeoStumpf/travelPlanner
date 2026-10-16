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
import 'models.dart';
import 'time.dart';

enum ShiftMode {
  /// Everything after the changed item moves by the same amount.
  following,

  /// Only push what would overlap; free days in between absorb the change.
  push,

  /// Only the item itself (and its children) moves.
  single,
}

extension ShiftModeX on ShiftMode {
  String get label => switch (this) {
        ShiftMode.following => 'Alles danach mitschieben',
        ShiftMode.push => 'Nur schieben, wenn nötig',
        ShiftMode.single => 'Nur dieses Element',
      };

  String get shortLabel => switch (this) {
        ShiftMode.following => 'Alles danach',
        ShiftMode.push => 'Puffer nutzen',
        ShiftMode.single => 'Nur dieses',
      };
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

  Scheduler._(List<PlanItem> items)
      : _original = items,
        _byId = {for (final i in items) i.id: i} {
    for (final i in items) {
      final a = i.anchorId;
      if (a != null && _byId.containsKey(a) && a != i.id) {
        _children.putIfAbsent(a, () => []).add(i.id);
      }
    }
  }

  /// Moves item [id] by [delta] minutes.
  static ScheduleResult move(List<PlanItem> items, String id, int delta, ShiftMode mode) {
    final s = Scheduler._(items);
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
          if (delta > 0) s._pushFrom(target.end! + delta, followers);
        case ShiftMode.single:
          break;
      }
    }
    return s._result();
  }

  /// Moves the end of item [id] by [delta] minutes (longer / shorter stay).
  static ScheduleResult resizeEnd(List<PlanItem> items, String id, int delta, ShiftMode mode) {
    final s = Scheduler._(items);
    final target = s._byId[id];
    if (target == null || !target.isScheduled || delta == 0) return s._result();

    final newEnd = (target.end! + delta).clamp(target.start! + 60, 1 << 40);
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
          if (effective > 0) s._pushFrom(newEnd, followers);
        case ShiftMode.single:
          break;
      }
    }
    return s._result();
  }

  /// Sets new start/end for [id] (e.g. from the editor) and ripples.
  static ScheduleResult reschedule(
    List<PlanItem> items,
    String id,
    int newStart,
    int newEnd,
    ShiftMode mode,
  ) {
    final item = items.where((i) => i.id == id).firstOrNull;
    if (item == null) return ScheduleResult(items, const {});
    if (!item.isScheduled) {
      final placed = item.copyWith(start: newStart, end: newEnd);
      return insert([for (final i in items) if (i.id != id) i], placed, mode);
    }
    final moved = move(items, id, newStart - item.start!, mode);
    final afterMove = moved.items.firstWhere((i) => i.id == id);
    final resized = resizeEnd(moved.items, id, newEnd - afterMove.end!, mode);
    return ScheduleResult(resized.items, {...moved.changedIds, ...resized.changedIds});
  }

  /// Adds [newItem] and makes room for it after its start.
  static ScheduleResult insert(List<PlanItem> items, PlanItem newItem, ShiftMode mode) {
    final s = Scheduler._([...items, newItem]);
    s._added.add(newItem.id);
    if (!newItem.isScheduled || !s._isRoot(newItem)) return s._result();

    final followers = s._followersOf(newItem, inclusive: true);
    switch (mode) {
      case ShiftMode.following:
        final first = followers.where((f) => !f.fixed).firstOrNull;
        if (first != null) {
          final overlap = newItem.end! - first.start!;
          if (overlap > 0) {
            final shift = _ceilDays(overlap);
            for (final f in followers) {
              if (!f.fixed) s._moveWithChildren(f, shift);
            }
          }
        }
      case ShiftMode.push:
        s._pushFrom(newItem.end!, followers);
      case ShiftMode.single:
        break;
    }
    return s._result();
  }

  // ---------------------------------------------------------------------------

  PlanItem _current(String id) => _updated[id] ?? _byId[id]!;

  void _set(PlanItem item) => _updated[item.id] = item;

  bool _isRoot(PlanItem item) {
    final a = item.anchorId;
    return item.isScheduled && !item.isOption && (a == null || !_byId.containsKey(a));
  }

  /// Roots that start after [target], ordered by their original start.
  /// With [inclusive], items starting at the same moment count as well
  /// (used when inserting in front of them).
  List<PlanItem> _followersOf(PlanItem target, {bool inclusive = false}) {
    final list = [
      for (final i in _original)
        if (i.id != target.id &&
            _isRoot(i) &&
            (i.start! > target.start! || (inclusive && i.start! == target.start!)))
          i,
    ]..sort((a, b) => a.start!.compareTo(b.start!));
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

  /// Pushes followers that would overlap the region ending at [cursorEnd],
  /// in whole days so their time of day stays the same.
  void _pushFrom(int cursorEnd, List<PlanItem> followers) {
    var cursor = cursorEnd;
    for (final f in followers) {
      final cur = _current(f.id);
      if (cur.fixed) {
        if (cur.end! > cursor) cursor = cur.end!;
        continue;
      }
      final overlap = cursor - cur.start!;
      if (overlap <= 0) break;
      final shift = _ceilDays(overlap);
      _moveWithChildren(cur, shift);
      cursor = _current(f.id).end!;
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
