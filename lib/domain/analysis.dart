// Read-only analysis of a plan: conflicts, free days, nights without a bed,
// and lane packing for the timeline.
import 'models.dart';
import 'time.dart';

class Conflict {
  final String itemId;
  final String? otherId;
  final String message;
  const Conflict(this.itemId, this.otherId, this.message);

  bool involves(String id) => itemId == id || otherId == id;

  @override
  String toString() => 'Conflict($itemId, $otherId, $message)';
}

class DayGap {
  /// First and last free day (inclusive).
  final int firstDay;
  final int lastDay;
  final String? afterItemId;
  const DayGap(this.firstDay, this.lastDay, this.afterItemId);
  int get days => lastDay - firstDay + 1;

  @override
  bool operator ==(Object other) =>
      other is DayGap && other.firstDay == firstDay && other.lastDay == lastDay;
  @override
  int get hashCode => Object.hash(firstDay, lastDay);
  @override
  String toString() => 'DayGap($firstDay..$lastDay)';
}

/// The confirmed (non-option, scheduled) stays in chronological order.
List<PlanItem> stayChain(Iterable<PlanItem> items) => [
      for (final i in items)
        if (i.kind == ItemKind.stay && i.isScheduled && !i.isOption) i,
    ]..sort((a, b) => a.start!.compareTo(b.start!));

List<Conflict> findConflicts(List<PlanItem> items) {
  final byId = {for (final i in items) i.id: i};
  final out = <Conflict>[];

  // Overlapping stays: you can't be in two places at once.
  final chain = stayChain(items);
  for (var a = 0; a < chain.length; a++) {
    for (var b = a + 1; b < chain.length; b++) {
      final x = chain[a], y = chain[b];
      if (y.start! >= x.end!) break;
      final overlap = x.end! - y.start!;
      out.add(Conflict(y.id, x.id,
          '„${y.title}“ beginnt ${_duration(overlap)} bevor „${x.title}“ endet'));
    }
  }

  for (final i in items) {
    if (!i.isScheduled || i.isOption) continue;
    switch (i.kind) {
      case ItemKind.accommodation:
      case ItemKind.activity:
        final p = byId[i.parentId];
        if (p == null || !p.isScheduled) break;
        if (i.kind == ItemKind.accommodation) {
          // Nights must lie within the days of the stay.
          if (dayOf(i.start!) < dayOf(p.start!) || lastDayOf(i.end!) > lastDayOf(p.end!)) {
            out.add(Conflict(i.id, p.id, '„${i.title}“ passt nicht zu den Tagen in ${p.title}'));
          }
        } else if (i.start! < p.start! || i.end! > p.end!) {
          out.add(Conflict(i.id, p.id, '„${i.title}“ liegt außerhalb des Aufenthalts in ${p.title}'));
        }
      case ItemKind.transport:
        final from = byId[i.fromId];
        final to = byId[i.toId];
        if (from != null && from.isScheduled && !from.isOption && lastDayOf(from.end!) > dayOf(i.start!)) {
          out.add(Conflict(i.id, from.id, '„${from.title}“ endet nach Abfahrt von „${i.title}“'));
        }
        if (to != null && to.isScheduled && !to.isOption && dayOf(to.start!) < lastDayOf(i.end!)) {
          out.add(Conflict(i.id, to.id, '„${to.title}“ beginnt vor Ankunft von „${i.title}“'));
        }
      case ItemKind.stay:
        break;
    }
  }
  return out;
}

String _duration(int minutes) {
  final days = minutes ~/ minutesPerDay;
  final hours = (minutes % minutesPerDay) ~/ 60;
  if (days > 0) return hours > 0 ? '${pluralDays(days)} ${hours}h' : pluralDays(days);
  return '${hours}h';
}

/// Whole free days between stays (and up to [plannedDays] at the end).
List<DayGap> findGaps(List<PlanItem> items, {int? plannedDays}) {
  final chain = stayChain(items);
  final out = <DayGap>[];
  var lastBusyDay = -1;
  String? lastId;
  for (final s in chain) {
    final first = dayOf(s.start!);
    if (first - lastBusyDay > 1) out.add(DayGap(lastBusyDay + 1, first - 1, lastId));
    final last = lastDayOf(s.end!);
    if (last > lastBusyDay) {
      lastBusyDay = last;
      lastId = s.id;
    }
  }
  if (plannedDays != null && plannedDays - 1 > lastBusyDay) {
    out.add(DayGap(lastBusyDay + 1, plannedDays - 1, lastId));
  }
  return out;
}

/// Night indices n (from day n to n+1) inside the trip's stays that have no
/// confirmed accommodation and no overnight transport.
List<int> uncoveredNights(List<PlanItem> items) {
  final chain = stayChain(items);
  if (chain.isEmpty) return const [];
  final covered = <int>{};
  for (final i in items) {
    if (!i.isScheduled || i.isOption) continue;
    if (i.kind == ItemKind.accommodation || i.kind == ItemKind.transport) {
      for (var n = dayOf(i.start!); n < lastDayOf(i.end!); n++) {
        covered.add(n);
      }
    }
  }
  final out = <int>{};
  for (final s in chain) {
    for (var n = dayOf(s.start!); n < lastDayOf(s.end!); n++) {
      if (!covered.contains(n)) out.add(n);
    }
  }
  return out.toList()..sort();
}

/// First and last day to show on the timeline.
(int, int) dayRange(List<PlanItem> items, {int? plannedDays}) {
  var first = 0;
  var last = (plannedDays ?? 1) - 1;
  for (final i in items) {
    if (!i.isScheduled) continue;
    if (dayOf(i.start!) < first) first = dayOf(i.start!);
    if (lastDayOf(i.end!) > last) last = lastDayOf(i.end!);
  }
  return (first, last);
}

/// Assigns each interval a row so that overlapping intervals don't share one.
/// Returns item id -> row and the number of rows.
(Map<String, int>, int) packLanes(List<PlanItem> items) {
  final sorted = [for (final i in items) if (i.isScheduled) i]
    ..sort((a, b) => a.start!.compareTo(b.start!));
  final rowEnds = <int>[];
  final rows = <String, int>{};
  for (final i in sorted) {
    var row = rowEnds.indexWhere((end) => end <= i.start!);
    if (row == -1) {
      row = rowEnds.length;
      rowEnds.add(i.end!);
    } else {
      rowEnds[row] = i.end!;
    }
    rows[i.id] = row;
  }
  return (rows, rowEnds.isEmpty ? 1 : rowEnds.length);
}
