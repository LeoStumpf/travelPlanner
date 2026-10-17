// The "Today" agenda: what a single trip day looks like while on the road –
// where you are, where you sleep, the next transport and the day's
// programme. Read-only, pure Dart.
import 'analysis.dart';
import 'models.dart';
import 'time.dart';

/// Trip day of the calendar date of [now] (may lie before or after the
/// trip), or null while the trip has no start date. Counted on UTC dates so
/// a daylight-saving switch never shifts the day.
int? tripDayOn(Trip trip, DateTime now) {
  final s = trip.startDate;
  if (s == null) return null;
  return DateTime.utc(now.year, now.month, now.day).difference(DateTime.utc(s.year, s.month, s.day)).inDays;
}

/// [now] in trip minutes (see the time model in models.dart), or null
/// without a start date.
int? tripMinuteAt(Trip trip, DateTime now) {
  final d = tripDayOn(trip, now);
  return d == null ? null : at(d, now.hour * 60 + now.minute);
}

/// Whether the trip is under way at [now]: it has a start date and today
/// lies within the days the timeline shows.
bool isTripRunning(TripData data, DateTime now) {
  final d = tripDayOn(data.trip, now);
  if (d == null) return false;
  final (first, last) = dayRange(data.items, plannedDays: data.trip.plannedDays);
  return d >= first && d <= last;
}

bool _touches(PlanItem i, int day) => i.isScheduled && dayOf(i.start!) <= day && day <= lastDayOf(i.end!);

/// Everything planned for one trip day. Options and ideas without dates are
/// left out; [lodgingOptions] lists the options for the night only while no
/// confirmed bed covers it.
class DayAgenda {
  final int day;

  /// Confirmed stays touching the day (two on a travel day), in order.
  final List<PlanItem> stays;

  /// Confirmed accommodation touching the day: checking out, staying on or
  /// checking in. Earliest check-in first.
  final List<PlanItem> lodging;

  /// Options for the night from this day to the next, when [needsBed].
  final List<PlanItem> lodgingOptions;

  /// True when a stay spans the night after this day but nothing (no
  /// confirmed accommodation, no overnight transport) covers it.
  final bool needsBed;

  /// Transports and activities touching the day, chronological.
  final List<PlanItem> events;

  /// The next transport not yet over: from [DayAgenda]'s reference minute
  /// (now on today, otherwise the start of the day). May be on a later day.
  final PlanItem? nextTransport;

  const DayAgenda({
    required this.day,
    this.stays = const [],
    this.lodging = const [],
    this.lodgingOptions = const [],
    this.needsBed = false,
    this.events = const [],
    this.nextTransport,
  });

  bool get isEmpty => stays.isEmpty && lodging.isEmpty && events.isEmpty && !needsBed;

  /// Whether [lodging] item [i] checks in / out on this day.
  bool checksIn(PlanItem i) => dayOf(i.start!) == day;
  bool checksOut(PlanItem i) => lastDayOf(i.end!) == day;
}

/// The agenda of trip [day]. [now] (trip minutes) picks the next transport
/// on today; on other days the day's start is used.
DayAgenda agendaFor(List<PlanItem> items, int day, {int? now}) {
  bool confirmed(PlanItem i) => i.isScheduled && !i.isOption;
  int byStart(PlanItem a, PlanItem b) => a.start!.compareTo(b.start!);

  final stays = [for (final s in stayChain(items)) if (_touches(s, day)) s];
  final lodging = [
    for (final i in items)
      if (i.kind == ItemKind.accommodation && confirmed(i) && _touches(i, day)) i,
  ]..sort(byStart);
  final events = [
    for (final i in items)
      if ((i.kind == ItemKind.transport || i.kind == ItemKind.activity) && confirmed(i) && _touches(i, day)) i,
  ]..sort(byStart);

  final needsBed = uncoveredNights(items).contains(day);

  final from = now != null && dayOf(now) == day ? now : at(day, 0);
  final transports = [
    for (final i in items)
      if (i.kind == ItemKind.transport && confirmed(i) && i.end! > from) i,
  ]..sort(byStart);

  return DayAgenda(
    day: day,
    stays: stays,
    lodging: lodging,
    lodgingOptions: needsBed ? optionsForNight(items, day) : const [],
    needsBed: needsBed,
    events: events,
    nextTransport: transports.firstOrNull,
  );
}

/// Files that belong to item [itemId]: its own attachments plus those of
/// the notes linked to it (a ticket screenshot on a card about the train).
List<Attachment> ticketsFor(TripData data, String itemId) => [
      ...data.attachmentsOf(itemId),
      for (final c in data.cards)
        if (c.itemId == itemId) ...data.attachmentsOf(c.id),
    ];
