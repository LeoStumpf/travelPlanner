// Read-only analysis of a plan: conflicts, free days, nights without a bed,
// and lane packing for the timeline.
import 'dart:math' as math;

import 'models.dart';
import 'scheduler.dart';
import 'time.dart';

/// A one-tap repair for a conflict: new start/end times for some items.
class ConflictFix {
  final String label;
  final Map<String, (int, int)> times;
  const ConflictFix(this.label, this.times);

  /// [items] with the fix applied; only changed items are returned.
  List<PlanItem> apply(List<PlanItem> items) => [
        for (final i in items)
          if (times[i.id] case (final s, final e)) i.copyWith(start: s, end: e),
      ];
}

class Conflict {
  final String itemId;
  final String? otherId;
  final String message;
  final ConflictFix? fix;
  const Conflict(this.itemId, this.otherId, this.message, [this.fix]);

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
      final pushed = Scheduler.move(items, y.id, _ceilDays(overlap), ShiftMode.push);
      out.add(Conflict(
        y.id,
        x.id,
        '„${y.title}“ beginnt ${_duration(overlap)} bevor „${x.title}“ endet',
        y.fixed
            ? null
            : ConflictFix('„${y.title}“ nach hinten schieben', {
                for (final c in pushed.changed) c.id: (c.start!, c.end!),
              }),
      ));
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
            final s = at(dayOf(p.start!), minuteOfDay(i.start!));
            final e = at(math.max(lastDayOf(p.end!), dayOf(p.start!) + 1), minuteOfDay(i.end!));
            out.add(Conflict(i.id, p.id, '„${i.title}“ passt nicht zu den Tagen in ${p.title}',
                i.fixed ? null : ConflictFix('Nächte an ${p.title} anpassen', {i.id: (s, e)})));
          }
        } else if (i.start! < p.start! || i.end! > p.end!) {
          final dur = i.duration;
          final day = dayOf(i.start!).clamp(dayOf(p.start!), lastDayOf(p.end!));
          var s = at(day, minuteOfDay(i.start!));
          if (s < p.start!) s = p.start!;
          if (s + dur > p.end!) s = math.max(p.start!, p.end! - dur);
          out.add(Conflict(i.id, p.id, '„${i.title}“ liegt außerhalb des Aufenthalts in ${p.title}',
              i.fixed ? null : ConflictFix('In ${p.title} verschieben', {i.id: (s, s + dur)})));
        }
      case ItemKind.transport:
        _transportConflicts(i, byId[i.fromId], byId[i.toId], out);
      case ItemKind.stay:
        break;
    }
  }
  return out;
}

/// The stays on both ends of a transport must meet it on the same day:
/// leaving a place days before the train departs (or arriving days before
/// the next stay begins) leaves you nowhere in between.
void _transportConflicts(PlanItem t, PlanItem? from, PlanItem? to, List<Conflict> out) {
  bool usable(PlanItem? s) => s != null && s.isScheduled && !s.isOption;

  if (usable(from)) {
    final f = from!;
    final lastDay = lastDayOf(f.end!), depDay = dayOf(t.start!);
    final fix = f.fixed || t.start! <= f.start! + 60
        ? null
        : ConflictFix(
            lastDay > depDay ? '„${f.title}“ bis zur Abfahrt kürzen' : '„${f.title}“ bis zur Abfahrt verlängern',
            {f.id: (f.start!, t.start!)},
          );
    if (lastDay > depDay) {
      out.add(Conflict(t.id, f.id, '„${f.title}“ endet nach Abfahrt von „${t.title}“', fix));
    } else if (lastDay < depDay) {
      out.add(Conflict(t.id, f.id,
          'Zwischen „${f.title}“ und Abfahrt von „${t.title}“ ${_lie(depDay - lastDay)} ohne Ort', fix));
    }
  }

  if (usable(to)) {
    final d = to!;
    final firstDay = dayOf(d.start!), arrDay = lastDayOf(t.end!);
    final fix = d.fixed || t.end! >= d.end! - 60
        ? null
        : ConflictFix(
            firstDay < arrDay ? '„${d.title}“ erst ab Ankunft' : '„${d.title}“ ab Ankunft beginnen',
            {d.id: (t.end!, d.end!)},
          );
    if (firstDay < arrDay) {
      out.add(Conflict(t.id, d.id, '„${d.title}“ beginnt vor Ankunft von „${t.title}“', fix));
    } else if (firstDay > arrDay) {
      out.add(Conflict(t.id, d.id,
          'Zwischen Ankunft von „${t.title}“ und „${d.title}“ ${_lie(firstDay - arrDay)} ohne Ort', fix));
    }
  }
}

String _lie(int days) => days == 1 ? 'liegt 1 Tag' : 'liegen $days Tage';

int _ceilDays(int minutes) => ((minutes + minutesPerDay - 1) ~/ minutesPerDay) * minutesPerDay;

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

/// Accommodation options (scheduled, status option) that would cover night
/// [n], earliest check-in first. Offered on a missing-night marker.
List<PlanItem> optionsForNight(List<PlanItem> items, int n) => [
      for (final i in items)
        if (i.kind == ItemKind.accommodation &&
            i.isOption &&
            i.isScheduled &&
            dayOf(i.start!) <= n &&
            n < lastDayOf(i.end!))
          i,
    ]..sort((a, b) => a.start!.compareTo(b.start!));

/// Whether two accommodations compete for the same bed: they share a night,
/// or – while one has no dates yet – they belong to the same stay.
bool _competes(PlanItem a, PlanItem b) {
  if (a.isScheduled && b.isScheduled) {
    return dayOf(a.start!) < lastDayOf(b.end!) && dayOf(b.start!) < lastDayOf(a.end!);
  }
  return a.parentId != null && a.parentId == b.parentId;
}

/// The changes that make accommodation [id] the chosen one: it becomes
/// planned (or booked with [book]); competing planned accommodations fall
/// back to options. Booked ones and ideas are never touched.
/// Returns only changed items.
List<PlanItem> chooseOption(List<PlanItem> items, String id, {bool book = false}) {
  final chosen = items.where((i) => i.id == id).firstOrNull;
  if (chosen == null) return const [];
  final status = book || chosen.status == ItemStatus.booked ? ItemStatus.booked : ItemStatus.planned;
  return [
    if (chosen.status != status) chosen.copyWith(status: status),
    if (chosen.kind == ItemKind.accommodation)
      for (final o in items)
        if (o.id != id &&
            o.kind == ItemKind.accommodation &&
            o.status == ItemStatus.planned &&
            _competes(chosen, o))
          o.copyWith(status: ItemStatus.option),
  ];
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
