// Optional time zones on top of the trip-relative minute model (time.dart).
//
// Stored times stay what they always were: minutes from 00:00 of trip day 0,
// read as the *local wall-clock time* of the place the time belongs to. A
// stay in Colombo from "day 2, 14:00" means 14:00 in Colombo. So all day
// logic (nights, days touched, check-in on day n) keeps working on local
// days, and nothing changes for items without a zone.
//
// Which zone a time belongs to:
// * stay           – its own `tz`, else the trip's home zone
// * accommodation, activity – the zone of their stay (parentId), else home
// * transport      – departure: its own `tz`, else the zone of the origin
//                    stay (fromId), else home; arrival: its own `endTz`, else
//                    the zone of the destination stay (toId), else home
// Without any zone a time is "floating" with offset 0, i.e. exactly the old
// behaviour.
//
// To compare times in different zones (a flight FRA → CMB, two consecutive
// stays) they are turned into absolute minutes: minutes since 00:00 UTC of
// the date of trip day 0. [TripZones] does that; scheduler and analysis use
// it wherever two items are compared.
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

bool _initialized = false;

/// Loads the bundled IANA time zone database once (needs no network).
void ensureTimeZones() {
  if (_initialized) return;
  tzdata.initializeTimeZones();
  _initialized = true;
}

final Map<String, tz.Location?> _locations = {};

tz.Location? _location(String name) => _locations.putIfAbsent(name, () {
      ensureTimeZones();
      try {
        return tz.getLocation(name);
      } on tz.LocationNotFoundException {
        return null;
      }
    });

/// Whether [name] is a known IANA zone ("Asia/Colombo").
bool isKnownZone(String? name) => name != null && _location(name) != null;

List<String>? _zoneNames;

/// The IANA zones people pick from ("Europe/Berlin", "Asia/Colombo" …),
/// sorted; legacy aliases like "US/Eastern" or "Etc/GMT+3" are left out.
List<String> allZoneNames() => _zoneNames ??= () {
      ensureTimeZones();
      const regions = {
        'Africa', 'America', 'Antarctica', 'Arctic', 'Asia', 'Atlantic', //
        'Australia', 'Europe', 'Indian', 'Pacific',
      };
      return [
        for (final n in tz.timeZoneDatabase.locations.keys)
          if (regions.contains(n.split('/').first) && n.contains('/')) n,
        'UTC',
      ]..sort();
    }();

/// Offset of zone [name] from UTC in minutes at the UTC instant [utc]
/// (0 for an unknown zone).
int zoneOffsetAt(String name, DateTime utc) {
  final loc = _location(name);
  if (loc == null) return 0;
  return loc.timeZone(utc.millisecondsSinceEpoch).offset.inMinutes;
}

/// "UTC+5:30", "UTC−3", "UTC" – language-neutral enough for any locale.
String formatUtcOffset(int minutes) {
  if (minutes == 0) return 'UTC';
  final sign = minutes > 0 ? '+' : '−';
  final a = minutes.abs();
  final h = a ~/ 60, m = a % 60;
  return 'UTC$sign$h${m == 0 ? '' : ':${m.toString().padLeft(2, '0')}'}';
}

/// The last part of a zone name, readable: "Asia/Ho_Chi_Minh" → "Ho Chi Minh".
String zoneCity(String name) => name.split('/').last.replaceAll('_', ' ');

/// Resolves the zones of a trip's items and converts between local trip
/// minutes and absolute minutes (see the file comment).
class TripZones {
  final String? homeZone;

  /// Date of trip day 0 the offsets are computed for (daylight saving!).
  /// Without a trip start date the reference date passed in, or today.
  final DateTime referenceDate;

  /// Items by id, to look up the stay a time belongs to. Only the zone
  /// fields and links are read, so moved copies of the items still resolve.
  final Map<String, PlanItem> _byId;

  /// False when neither the trip nor any item has a zone: then every offset
  /// is 0 and all conversions are the identity, without touching the
  /// time zone database.
  final bool isActive;

  TripZones._(this.homeZone, this.referenceDate, this._byId, this.isActive);

  /// No zones at all: absolute = local, as before time zones existed.
  static final TripZones none = TripZones._(null, DateTime.utc(2000), const {}, false);

  factory TripZones.of(Trip trip, Iterable<PlanItem> items, {DateTime? referenceDate}) =>
      TripZones.from(homeZone: trip.homeZone, startDate: trip.startDate, items: items, referenceDate: referenceDate);

  factory TripZones.from({
    String? homeZone,
    DateTime? startDate,
    Iterable<PlanItem> items = const [],
    DateTime? referenceDate,
  }) {
    final byId = {for (final i in items) i.id: i};
    final active = homeZone != null || byId.values.any((i) => i.tz != null || i.endTz != null);
    final d = startDate ?? referenceDate ?? DateTime.now();
    return TripZones._(homeZone, DateTime.utc(d.year, d.month, d.day), byId, active);
  }

  /// Own zone of the stay [id] (null when it has none or is unknown).
  String? _stayZone(String? id) => _byId[id]?.tz;

  /// Zone the start time of [i] is given in.
  String? startZone(PlanItem i) {
    if (!isActive) return null;
    return switch (i.kind) {
          ItemKind.stay => i.tz,
          ItemKind.transport => i.tz ?? _stayZone(i.fromId),
          ItemKind.accommodation || ItemKind.activity => _stayZone(i.parentId),
        } ??
        homeZone;
  }

  /// Zone the end time of [i] is given in (differs from [startZone] only
  /// for transports).
  String? endZone(PlanItem i) {
    if (!isActive) return null;
    if (i.kind != ItemKind.transport) return startZone(i);
    return i.endTz ?? _stayZone(i.toId) ?? homeZone;
  }

  /// Zone of a stay as it applies to its times (own, else home).
  String? zoneOfStay(PlanItem stay) => startZone(stay);

  DateTime _instant(int absMinute) => referenceDate.add(Duration(minutes: absMinute));

  /// Offset of [zone] from UTC (minutes) at absolute minute [abs].
  int offsetAtAbs(String? zone, int abs) => zone == null ? 0 : zoneOffsetAt(zone, _instant(abs));

  /// Offset of [zone] from UTC (minutes) at local trip minute [local]. In
  /// the hour skipped by a daylight-saving switch the offset before the
  /// switch is used.
  int offsetAt(String? zone, int local) {
    if (zone == null) return 0;
    final o1 = offsetAtAbs(zone, local);
    final o2 = offsetAtAbs(zone, local - o1);
    if (o1 == o2) return o1;
    final o3 = offsetAtAbs(zone, local - o2);
    return o3 == o2 ? o2 : o1;
  }

  /// Local trip minute [local] in [zone] as absolute minute.
  int toAbs(String? zone, int local) => local - offsetAt(zone, local);

  /// Absolute minute [abs] as local trip minute in [zone].
  int toLocal(String? zone, int abs) => abs + offsetAtAbs(zone, abs);

  /// [local] (given in zone [from]) as local time in zone [to].
  int convert(int local, String? from, String? to) =>
      !isActive || from == to ? local : toLocal(to, toAbs(from, local));

  int absStart(PlanItem i) => isActive ? toAbs(startZone(i), i.start!) : i.start!;
  int absEnd(PlanItem i) => isActive ? toAbs(endZone(i), i.end!) : i.end!;

  /// Real duration of [i] in minutes (a flight's time in the air).
  int absDuration(PlanItem i) => absEnd(i) - absStart(i);

  /// Whether start and end of [i] are in zones with different offsets.
  bool crossesZones(PlanItem i) =>
      isActive && i.isScheduled && offsetAt(startZone(i), i.start!) != offsetAt(endZone(i), i.end!);

  /// "UTC+5:30" for the start / end time of [i], null when floating.
  String? startOffsetLabel(PlanItem i) {
    final z = startZone(i);
    return z == null || i.start == null ? null : formatUtcOffset(offsetAt(z, i.start!));
  }

  String? endOffsetLabel(PlanItem i) {
    final z = endZone(i);
    return z == null || i.end == null ? null : formatUtcOffset(offsetAt(z, i.end!));
  }

  /// Latest local start for [i] that still leaves [minDuration] real
  /// minutes before its end.
  int latestStart(PlanItem i, int minDuration) =>
      isActive ? toLocal(startZone(i), absEnd(i) - minDuration) : i.end! - minDuration;

  /// Earliest local end for [i] that is [minDuration] real minutes after
  /// its start.
  int earliestEnd(PlanItem i, int minDuration) =>
      isActive ? toLocal(endZone(i), absStart(i) + minDuration) : i.start! + minDuration;
}

final _zonesCache = Expando<TripZones>();

extension TripDataZones on TripData {
  /// The zones of this trip (cached per [TripData] instance).
  TripZones get zones => _zonesCache[this] ??= TripZones.of(trip, items);

  /// Zones used anywhere in the trip (home zone first), for suggestions.
  List<String> get usedZones => {
        ?trip.homeZone,
        for (final i in items) ...[?i.tz, ?i.endTz],
      }.toList();
}
