// Timeline helpers: label room for narrow blocks and placing unscheduled
// items on a chosen day. Pure Dart.

import 'analysis.dart';
import 'models.dart';
import 'scheduler.dart';
import 'time.dart';
import 'zones.dart';

/// Default length of an activity placed via "Schedule on …".
const defaultActivityMinutes = 2 * 60;

/// Start of an activity placed via "Schedule on …".
const defaultActivityStart = 10 * 60;

/// Free minutes from each item's start until the next item in the same row
/// (per [rows] from [packLanes]) starts; null for the last one in its row.
/// Lets a narrow block spill its title into the empty space after it.
Map<String, int?> labelRoom(List<PlanItem> items, Map<String, int> rows) {
  final byRow = <int, List<PlanItem>>{};
  for (final i in items) {
    if (!i.isScheduled) continue;
    byRow.putIfAbsent(rows[i.id] ?? 0, () => []).add(i);
  }
  final room = <String, int?>{};
  for (final row in byRow.values) {
    row.sort((a, b) => a.start!.compareTo(b.start!));
    for (var k = 0; k < row.length; k++) {
      room[row[k].id] = k + 1 < row.length ? row[k + 1].start! - row[k].start! : null;
    }
  }
  return room;
}

/// The trip day an unscheduled [item] most likely belongs on: for a place
/// the first free day between places (else the departure day of the last
/// one), the first (full) day of its place for lodging and activities, the
/// departure day of a transport's origin, else day 0.
int suggestedDay(PlanItem item, List<PlanItem> items, {int? plannedDays, TripZones? zones}) {
  PlanItem? scheduled(String? id) => items.where((i) => i.id == id && i.isScheduled).firstOrNull;
  switch (item.kind) {
    case ItemKind.stay:
      final gap = findGaps(items, plannedDays: plannedDays).firstOrNull;
      if (gap != null) return gap.firstDay;
      final chain = stayChain(items, zones: zones);
      return chain.isEmpty ? 0 : lastDayOf(chain.last.end!);
    case ItemKind.accommodation:
      final stay = scheduled(item.parentId);
      return stay == null ? 0 : dayOf(stay.start!);
    case ItemKind.activity:
      final stay = scheduled(item.parentId);
      if (stay == null) return 0;
      final first = dayOf(stay.start!);
      // Arrival day is mostly travelling; prefer the first full day.
      return lastDayOf(stay.end!) > first ? first + 1 : first;
    case ItemKind.transport:
      final from = scheduled(item.fromId);
      if (from != null) return lastDayOf(from.end!);
      final to = scheduled(item.toId);
      return to == null ? 0 : dayOf(to.start!);
  }
}

/// Kind-specific start/end for placing [item] on trip [day]:
/// - place: arrive 14:00, two nights (fewer if the next place starts sooner),
/// - lodging: check-in 15:00 until check-out 11:00 at the end of its place
///   (at least one night),
/// - activity: 10:00–12:00,
/// - transport: leaving its origin place if that ends on [day], else
///   10:00–13:00.
(int, int) defaultSlotOn(PlanItem item, int day, List<PlanItem> items, {TripZones? zones}) {
  PlanItem? scheduled(String? id) => items.where((i) => i.id == id && i.isScheduled).firstOrNull;
  switch (item.kind) {
    case ItemKind.stay:
      final next = [
        for (final s in stayChain(items, zones: zones))
          if (s.id != item.id && dayOf(s.start!) > day) dayOf(s.start!),
      ];
      var nights = 2;
      if (next.isNotEmpty) {
        final until = next.reduce((a, b) => a < b ? a : b) - day;
        if (until < nights) nights = until < 1 ? 1 : until;
      }
      return (at(day, defaultStayArrival), at(day + nights, defaultStayDeparture));
    case ItemKind.accommodation:
      final stay = scheduled(item.parentId);
      final last = stay == null ? day + 1 : lastDayOf(stay.end!);
      return (at(day, defaultCheckIn), at(last > day ? last : day + 1, defaultCheckOut));
    case ItemKind.activity:
      return (at(day, defaultActivityStart), at(day, defaultActivityStart + defaultActivityMinutes));
    case ItemKind.transport:
      final from = scheduled(item.fromId);
      if (from != null && lastDayOf(from.end!) == day) {
        final t = suggestTransportTimes(from, scheduled(item.toId), zones: zones);
        if (t != null) return t;
      }
      return (at(day, defaultStayDeparture), at(day, defaultStayDeparture + defaultTransportMinutes));
  }
}

/// Places the unscheduled item [id] on [day] with [defaultSlotOn] and makes
/// room according to [mode].
ScheduleResult scheduleOn(List<PlanItem> items, String id, int day, ShiftMode mode, {TripZones? zones}) {
  final item = items.where((i) => i.id == id).firstOrNull;
  if (item == null) return ScheduleResult(items, const {});
  final (start, end) = defaultSlotOn(item, day, items, zones: zones);
  return Scheduler.reschedule(items, id, start, end, mode, zones: zones);
}
