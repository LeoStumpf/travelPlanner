// Trip reminders: local notifications ahead of departures, check-ins and
// check-outs. This file decides *what* to remind of and *when*; the
// platform scheduling lives in lib/data/reminder_scheduler.dart and the
// wording in the UI. Pure Dart.
//
// Reminders need real dates, so a trip without a start date has none.
// Times of items with a known zone (zones.dart) become exact instants; a
// floating time (no zone anywhere) is read as wall-clock time of the
// phone, which is how the app shows it too.
import 'models.dart';
import 'time.dart';
import 'zones.dart';

enum ReminderType { departure, checkIn, checkOut }

/// Lead times offered in the settings, in minutes.
const reminderLeadChoices = [15, 30, 60, 120, 180, 360, 1440, 2880];

/// Default lead time of a newly enabled trip: two hours.
const defaultReminderLead = 120;

/// At most this many reminders are scheduled at once (the nearest ones),
/// well below the platform limits (iOS: 64, Android: 500 alarms per app).
const maxScheduledReminders = 60;

/// Per-trip reminder settings. Kept on the device (shared preferences),
/// not in the trip: alarms are a matter of the phone, and a trip shared
/// with or imported from fellow travellers should not ring on theirs.
class ReminderSettings {
  final bool enabled;

  /// Minutes before the event, one reminder each ("1 day and 2 h before").
  /// Sorted, longest first, never empty.
  final List<int> leads;
  final bool departures;
  final bool checkIns;
  final bool checkOuts;

  const ReminderSettings({
    this.enabled = false,
    this.leads = const [defaultReminderLead],
    this.departures = true,
    this.checkIns = true,
    this.checkOuts = true,
  });

  static const off = ReminderSettings();

  ReminderSettings copyWith({
    bool? enabled,
    List<int>? leads,
    bool? departures,
    bool? checkIns,
    bool? checkOuts,
  }) =>
      ReminderSettings(
        enabled: enabled ?? this.enabled,
        leads: leads == null ? this.leads : _normalizeLeads(leads),
        departures: departures ?? this.departures,
        checkIns: checkIns ?? this.checkIns,
        checkOuts: checkOuts ?? this.checkOuts,
      );

  /// Adds or removes [lead]; the last lead time cannot be removed.
  ReminderSettings toggleLead(int lead) {
    if (!leads.contains(lead)) return copyWith(leads: [...leads, lead]);
    if (leads.length == 1) return this;
    return copyWith(leads: [for (final l in leads) if (l != lead) l]);
  }

  bool covers(ReminderType t) => switch (t) {
        ReminderType.departure => departures,
        ReminderType.checkIn => checkIns,
        ReminderType.checkOut => checkOuts,
      };

  Map<String, Object?> toJson() => {
        'enabled': enabled,
        'leads': leads,
        if (!departures) 'departures': false,
        if (!checkIns) 'checkIns': false,
        if (!checkOuts) 'checkOuts': false,
      };

  /// Lenient: anything unreadable falls back to the defaults.
  factory ReminderSettings.fromJson(Object? j) {
    if (j is! Map) return off;
    final leads = [for (final l in (j['leads'] as List?) ?? const []) if (l is int && l > 0) l];
    return ReminderSettings(
      enabled: j['enabled'] == true,
      leads: leads.isEmpty ? const [defaultReminderLead] : _normalizeLeads(leads),
      departures: j['departures'] != false,
      checkIns: j['checkIns'] != false,
      checkOuts: j['checkOuts'] != false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderSettings &&
      other.enabled == enabled &&
      _sameList(other.leads, leads) &&
      other.departures == departures &&
      other.checkIns == checkIns &&
      other.checkOuts == checkOuts;

  @override
  int get hashCode => Object.hash(enabled, Object.hashAll(leads), departures, checkIns, checkOuts);
}

List<int> _normalizeLeads(List<int> leads) => leads.toSet().toList()..sort((a, b) => b.compareTo(a));

bool _sameList(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// One notification to schedule.
class Reminder {
  final String tripId;
  final String itemId;
  final ReminderType type;

  /// Minutes before [eventAt] it fires.
  final int lead;

  /// When the departure / check-in / check-out happens, and when the
  /// notification fires (both UTC).
  final DateTime eventAt;
  final DateTime fireAt;

  /// Local trip minute of the event (as the app shows it).
  final int eventMinute;

  const Reminder({
    required this.tripId,
    required this.itemId,
    required this.type,
    required this.lead,
    required this.eventAt,
    required this.fireAt,
    required this.eventMinute,
  });

  /// Stable notification id, so rescheduling replaces rather than doubles.
  int get id => reminderId(itemId, type, lead);

  /// "tripId/itemId" – which trip and item a tap on the notification opens.
  String get payload => '$tripId/$itemId';

  @override
  String toString() => 'Reminder(${type.name} $itemId -${lead}m @ $fireAt)';
}

/// Stable 31-bit id (FNV-1a) for the reminder of [itemId], [type], [lead].
int reminderId(String itemId, ReminderType type, int lead) {
  var h = 0x811c9dc5;
  for (final c in '$itemId|${type.name}|$lead'.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h & 0x7fffffff;
}

/// Splits a [Reminder.payload] into trip and item id.
(String, String)? parseReminderPayload(String? payload) {
  final i = payload?.indexOf('/') ?? -1;
  if (payload == null || i <= 0 || i == payload.length - 1) return null;
  return (payload.substring(0, i), payload.substring(i + 1));
}

/// The real instant of local trip minute [minute] given in [zone], or null
/// without a start date. A floating time (no zone) is the phone's wall clock.
DateTime? instantOf(Trip trip, TripZones zones, int minute, String? zone) {
  final s = trip.startDate;
  if (s == null) return null;
  if (zone == null) {
    final d = dateOfDay(s, dayOf(minute));
    final m = minuteOfDay(minute);
    return DateTime(d.year, d.month, d.day, m ~/ 60, m % 60).toUtc();
  }
  return DateTime.utc(s.year, s.month, s.day).add(Duration(minutes: zones.toAbs(zone, minute)));
}

/// Only what is decided on gets a reminder: planned or booked, scheduled.
bool _remindable(PlanItem i) =>
    i.isScheduled && (i.status == ItemStatus.planned || i.status == ItemStatus.booked);

/// Every reminder of trip [data] under [settings] that fires after [now],
/// in firing order. Empty while disabled or without a start date.
List<Reminder> remindersFor(TripData data, ReminderSettings settings, DateTime now) {
  final trip = data.trip;
  if (!settings.enabled || trip.startDate == null) return const [];
  final zones = data.zones;
  final nowUtc = now.toUtc();
  final out = <Reminder>[];

  void add(PlanItem i, ReminderType type, int minute, String? zone) {
    if (!settings.covers(type)) return;
    final event = instantOf(trip, zones, minute, zone)!;
    if (!event.isAfter(nowUtc)) return;
    for (final lead in settings.leads) {
      final fire = event.subtract(Duration(minutes: lead));
      if (!fire.isAfter(nowUtc)) continue;
      out.add(Reminder(
        tripId: trip.id,
        itemId: i.id,
        type: type,
        lead: lead,
        eventAt: event,
        fireAt: fire,
        eventMinute: minute,
      ));
    }
  }

  for (final i in data.items) {
    if (!_remindable(i)) continue;
    switch (i.kind) {
      case ItemKind.transport:
        add(i, ReminderType.departure, i.start!, zones.startZone(i));
      case ItemKind.accommodation:
        add(i, ReminderType.checkIn, i.start!, zones.startZone(i));
        add(i, ReminderType.checkOut, i.end!, zones.endZone(i));
      case ItemKind.stay || ItemKind.activity:
        break;
    }
  }
  return out..sort(_byFire);
}

int _byFire(Reminder a, Reminder b) {
  final c = a.fireAt.compareTo(b.fireAt);
  return c != 0 ? c : a.id.compareTo(b.id);
}

/// The reminders of all [trips] with their settings, nearest first, capped
/// at [limit] so the platform's alarm limits are never hit.
List<Reminder> upcomingReminders(
  Iterable<(TripData, ReminderSettings)> trips,
  DateTime now, {
  int limit = maxScheduledReminders,
}) {
  final all = [for (final (d, s) in trips) ...remindersFor(d, s, now)]..sort(_byFire);
  return all.length > limit ? all.sublist(0, limit) : all;
}
