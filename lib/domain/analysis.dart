// Read-only analysis of a plan: conflicts, free days, nights without a bed,
// and lane packing for the timeline.
//
// Functions taking [TripZones] compare items in different time zones on
// absolute time; without zones they behave as before (zones.dart).
import 'dart:math' as math;

import 'models.dart';
import 'scheduler.dart';
import 'time.dart';
import 'zones.dart';

/// What a [ConflictFix] does; the UI turns it into a label.
enum ConflictFixType {
  /// Push the later stay back until it no longer overlaps.
  pushLater,

  /// Move an accommodation's nights into the days of its stay.
  fitNightsToStay,

  /// Move an activity into its stay.
  moveIntoStay,

  /// Let the stay before a transport end at the departure (shorter / longer).
  shortenToDeparture,
  extendToDeparture,

  /// Let the stay after a transport start at the arrival (later / earlier).
  startLaterAtArrival,
  startEarlierAtArrival,
}

/// A one-tap repair for a conflict: new start/end times for some items.
class ConflictFix {
  final ConflictFixType type;

  /// Title of the item the fix changes (or, for [ConflictFixType.fitNightsToStay]
  /// and [ConflictFixType.moveIntoStay], of the stay it aligns with).
  final String subject;
  final Map<String, (int, int)> times;
  const ConflictFix(this.type, this.subject, this.times);

  /// [items] with the fix applied; only changed items are returned.
  List<PlanItem> apply(List<PlanItem> items) => [
        for (final i in items)
          if (times[i.id] case (final s, final e)) i.copyWith(start: s, end: e),
      ];
}

/// Kinds of conflicts. Item = the conflict's [Conflict.itemId], other = its
/// [Conflict.otherId].
enum ConflictType {
  /// Stay (item) begins [Conflict.amount] minutes before stay (other) ends.
  staysOverlap,

  /// Accommodation (item) has nights outside the days of its stay (other).
  lodgingOutsideStay,

  /// Activity (item) lies outside its stay (other).
  activityOutsideStay,

  /// Stay (other) ends after transport (item) departs.
  stayEndsAfterDeparture,

  /// [Conflict.amount] days without a place between stay (other) and the
  /// departure of transport (item).
  daysBeforeDeparture,

  /// Stay (other) begins before transport (item) arrives.
  stayStartsBeforeArrival,

  /// [Conflict.amount] days without a place between the arrival of transport
  /// (item) and stay (other).
  daysAfterArrival,
}

/// A problem in the plan. Carries a type and the values the UI needs to
/// describe it, so the domain stays language-neutral.
class Conflict {
  final String itemId;
  final String? otherId;
  final ConflictType type;
  final String itemTitle;
  final String otherTitle;

  /// Overlap in minutes ([ConflictType.staysOverlap]) or days without a
  /// place ([ConflictType.daysBeforeDeparture], [ConflictType.daysAfterArrival]).
  final int amount;
  final ConflictFix? fix;
  const Conflict(this.itemId, this.otherId, this.type,
      {required this.itemTitle, required this.otherTitle, this.amount = 0, this.fix});

  bool involves(String id) => itemId == id || otherId == id;

  @override
  String toString() => 'Conflict($itemId, $otherId, ${type.name}, $amount)';
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

/// The confirmed (non-option, scheduled) stays in chronological order
/// (absolute time with [zones]).
List<PlanItem> stayChain(Iterable<PlanItem> items, {TripZones? zones}) {
  final z = zones ?? TripZones.none;
  return [
    for (final i in items)
      if (i.kind == ItemKind.stay && i.isScheduled && !i.isOption) i,
  ]..sort((a, b) => z.absStart(a).compareTo(z.absStart(b)));
}

List<Conflict> findConflicts(List<PlanItem> items, {TripZones? zones}) {
  final z = zones ?? TripZones.none;
  final byId = {for (final i in items) i.id: i};
  final out = <Conflict>[];

  // Overlapping stays: you can't be in two places at once – judged on
  // absolute time, so leaving Colombo at 10:00 and reaching Frankfurt at
  // 08:00 the same day is fine.
  final chain = stayChain(items, zones: z);
  for (var a = 0; a < chain.length; a++) {
    for (var b = a + 1; b < chain.length; b++) {
      final x = chain[a], y = chain[b];
      if (z.absStart(y) >= z.absEnd(x)) break;
      final overlap = z.absEnd(x) - z.absStart(y);
      final pushed = Scheduler.move(items, y.id, _ceilDays(overlap), ShiftMode.push, zones: z);
      out.add(Conflict(
        y.id,
        x.id,
        ConflictType.staysOverlap,
        itemTitle: y.title,
        otherTitle: x.title,
        amount: overlap,
        fix: y.fixed
            ? null
            : ConflictFix(ConflictFixType.pushLater, y.title, {
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
            out.add(Conflict(i.id, p.id, ConflictType.lodgingOutsideStay,
                itemTitle: i.title,
                otherTitle: p.title,
                fix: i.fixed ? null : ConflictFix(ConflictFixType.fitNightsToStay, p.title, {i.id: (s, e)})));
          }
        } else if (i.start! < p.start! || i.end! > p.end!) {
          final dur = i.duration;
          final day = dayOf(i.start!).clamp(dayOf(p.start!), lastDayOf(p.end!));
          var s = at(day, minuteOfDay(i.start!));
          if (s < p.start!) s = p.start!;
          if (s + dur > p.end!) s = math.max(p.start!, p.end! - dur);
          out.add(Conflict(i.id, p.id, ConflictType.activityOutsideStay,
              itemTitle: i.title,
              otherTitle: p.title,
              fix: i.fixed ? null : ConflictFix(ConflictFixType.moveIntoStay, p.title, {i.id: (s, s + dur)})));
        }
      case ItemKind.transport:
        _transportConflicts(i, byId[i.fromId], byId[i.toId], z, out);
      case ItemKind.stay:
        break;
    }
  }
  return out;
}

/// The stays on both ends of a transport must meet it on the same day:
/// leaving a place days before the train departs (or arriving days before
/// the next stay begins) leaves you nowhere in between. Departure and
/// arrival are compared in the local time of the stay they meet (the same
/// zone unless the transport overrides it).
void _transportConflicts(PlanItem t, PlanItem? from, PlanItem? to, TripZones z, List<Conflict> out) {
  bool usable(PlanItem? s) => s != null && s.isScheduled && !s.isOption;

  if (usable(from)) {
    final f = from!;
    final dep = z.convert(t.start!, z.startZone(t), z.zoneOfStay(f));
    final lastDay = lastDayOf(f.end!), depDay = dayOf(dep);
    final fix = f.fixed || dep <= f.start! + 60
        ? null
        : ConflictFix(
            lastDay > depDay ? ConflictFixType.shortenToDeparture : ConflictFixType.extendToDeparture,
            f.title,
            {f.id: (f.start!, dep)},
          );
    if (lastDay > depDay) {
      out.add(Conflict(t.id, f.id, ConflictType.stayEndsAfterDeparture,
          itemTitle: t.title, otherTitle: f.title, fix: fix));
    } else if (lastDay < depDay) {
      out.add(Conflict(t.id, f.id, ConflictType.daysBeforeDeparture,
          itemTitle: t.title, otherTitle: f.title, amount: depDay - lastDay, fix: fix));
    }
  }

  if (usable(to)) {
    final d = to!;
    final arr = z.convert(t.end!, z.endZone(t), z.zoneOfStay(d));
    final firstDay = dayOf(d.start!), arrDay = lastDayOf(arr);
    final fix = d.fixed || arr >= d.end! - 60
        ? null
        : ConflictFix(
            firstDay < arrDay ? ConflictFixType.startLaterAtArrival : ConflictFixType.startEarlierAtArrival,
            d.title,
            {d.id: (arr, d.end!)},
          );
    if (firstDay < arrDay) {
      out.add(Conflict(t.id, d.id, ConflictType.stayStartsBeforeArrival,
          itemTitle: t.title, otherTitle: d.title, fix: fix));
    } else if (firstDay > arrDay) {
      out.add(Conflict(t.id, d.id, ConflictType.daysAfterArrival,
          itemTitle: t.title, otherTitle: d.title, amount: firstDay - arrDay, fix: fix));
    }
  }
}

int _ceilDays(int minutes) => ((minutes + minutesPerDay - 1) ~/ minutesPerDay) * minutesPerDay;

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

/// The changes for the "booked" toggle of item [id]. Booking goes through
/// [chooseOption], so a booked accommodation also wins its nights; un-booking
/// makes the item planned. Returns only changed items.
List<PlanItem> setBooked(List<PlanItem> items, String id, bool booked) {
  final item = items.where((i) => i.id == id).firstOrNull;
  if (item == null) return const [];
  if (booked) return chooseOption(items, id, book: true);
  return [if (item.status == ItemStatus.booked) item.copyWith(status: ItemStatus.planned)];
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

/// Two consecutive confirmed stays with no transport from [from] to [to].
class TransportGap {
  final PlanItem from;
  final PlanItem to;
  const TransportGap(this.from, this.to);

  /// Suggested departure/arrival for a new transport filling the gap.
  (int, int) get suggestedTimes => suggestTransportTimes(from, to)!;

  @override
  bool operator ==(Object other) => other is TransportGap && other.from.id == from.id && other.to.id == to.id;
  @override
  int get hashCode => Object.hash(from.id, to.id);
  @override
  String toString() => 'TransportGap(${from.id} → ${to.id})';
}

/// Default length of a suggested transport.
const defaultTransportMinutes = 3 * 60;

/// Pairs of consecutive stays in [stayChain] that no transport connects
/// (fromId = earlier, toId = later stay). Any transport counts, also an
/// option or one without dates: then the leg is already being planned.
List<TransportGap> missingTransports(List<PlanItem> items, {TripZones? zones}) {
  final chain = stayChain(items, zones: zones);
  final linked = {
    for (final i in items)
      if (i.kind == ItemKind.transport && i.fromId != null && i.toId != null) (i.fromId, i.toId),
  };
  return [
    for (var k = 0; k + 1 < chain.length; k++)
      if (!linked.contains((chain[k].id, chain[k + 1].id))) TransportGap(chain[k], chain[k + 1]),
  ];
}

/// Departure and arrival for a new transport from [from] to [to]: it leaves
/// when [from] ends and takes [defaultTransportMinutes], arriving no later
/// than [to] begins when that leaves room. With only [to] it arrives as
/// [to] begins. Null when neither end has dates. With [zones] the
/// departure is in [from]'s local time and the arrival in [to]'s.
(int, int)? suggestTransportTimes(PlanItem? from, PlanItem? to, {TripZones? zones}) {
  final z = zones ?? TripZones.none;
  final f = from?.isScheduled == true ? from : null;
  final t = to?.isScheduled == true ? to : null;
  // Zones of the new transport's ends: those of the stays, else home.
  final depZone = from != null ? z.zoneOfStay(from) : z.homeZone;
  final arrZone = to != null ? z.zoneOfStay(to) : z.homeZone;
  if (f != null) {
    final s = z.absEnd(f);
    final next = t == null ? null : z.absStart(t);
    final e = next != null && next > s ? math.min(s + defaultTransportMinutes, next) : s + defaultTransportMinutes;
    return (f.end!, z.isActive ? z.toLocal(arrZone, e) : e);
  }
  if (t != null) {
    final s = z.absStart(t) - defaultTransportMinutes;
    return (z.isActive ? z.toLocal(depZone, s) : s, t.start!);
  }
  return null;
}

/// The stays right before and after [stayId] in [stayChain] (null at the
/// ends or when the stay is not part of the chain).
(PlanItem?, PlanItem?) neighbourStays(List<PlanItem> items, String stayId, {TripZones? zones}) {
  final chain = stayChain(items, zones: zones);
  final k = chain.indexWhere((s) => s.id == stayId);
  if (k < 0) return (null, null);
  return (k > 0 ? chain[k - 1] : null, k + 1 < chain.length ? chain[k + 1] : null);
}
