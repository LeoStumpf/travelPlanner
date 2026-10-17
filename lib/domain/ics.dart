// Calendar export (iCalendar, RFC 5545) of the shared plan: one event per
// planned or booked item. Needs the trip's start date – trip days have no
// calendar position without it. Pure Dart; texts come from the caller.
//
// Times: an item whose zone is known (see zones.dart) gets a UTC time, so
// the calendar shows it right wherever the phone is. Without a zone the
// time is "floating" (no zone, RFC 5545 §3.3.5) – 14:00 stays 14:00, which
// is exactly how the app shows it. Stays become all-day events spanning
// the days of the place.
import 'dart:convert';

import 'itinerary.dart';
import 'models.dart';
import 'time.dart';
import 'zones.dart';

/// Items that go into the calendar, chronological.
List<PlanItem> calendarItems(TripData data) =>
    [for (final i in data.items) if (isShared(i)) i]..sort((a, b) => a.start!.compareTo(b.start!));

/// The trip as an .ics file. [summary] and [describe] word an item's event
/// title and description (default: its title, its notes). Throws a
/// [StateError] without a start date.
String buildIcs(
  TripData data, {
  required DateTime now,
  String Function(PlanItem)? summary,
  String Function(PlanItem)? describe,
}) {
  final start = data.trip.startDate;
  if (start == null) throw StateError('The calendar export needs a trip start date');
  final zones = TripZones.of(data.trip, data.items);
  final day0 = DateTime(start.year, start.month, start.day);
  final utc0 = DateTime.utc(start.year, start.month, start.day);

  String localStamp(int minute) {
    final d = dateOfDay(day0, dayOf(minute));
    final m = minuteOfDay(minute);
    return '${_date(d)}T${_two(m ~/ 60)}${_two(m % 60)}00';
  }

  String utcStamp(DateTime t) =>
      '${_date(t)}T${_two(t.hour)}${_two(t.minute)}${_two(t.second)}Z';

  /// "DTSTART:…" for a timed item; UTC when the zone is known.
  String moment(String name, int local, String? zone, int abs) =>
      zone == null ? '$name:${localStamp(local)}' : '$name:${utcStamp(utc0.add(Duration(minutes: abs)))}';

  final out = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Tripboard//Travel Planner//EN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'X-WR-CALNAME:${icsEscape(data.trip.title)}',
  ];
  final stamp = utcStamp(now.toUtc());
  for (final i in calendarItems(data)) {
    out
      ..add('BEGIN:VEVENT')
      // Stable per item, so importing an updated plan again replaces the
      // events instead of duplicating them.
      ..add('UID:${i.id}@tripboard')
      ..add('DTSTAMP:$stamp');
    if (i.kind == ItemKind.stay) {
      out
        ..add('DTSTART;VALUE=DATE:${_date(dateOfDay(day0, dayOf(i.start!)))}')
        ..add('DTEND;VALUE=DATE:${_date(dateOfDay(day0, lastDayOf(i.end!) + 1))}');
    } else {
      final absStart = zones.absStart(i);
      // Never end before the start (a bad import); calendars reject that.
      final absEnd = zones.absEnd(i) < absStart ? absStart : zones.absEnd(i);
      final end = i.end! < i.start! && zones.endZone(i) == null ? i.start! : i.end!;
      out
        ..add(moment('DTSTART', i.start!, zones.startZone(i), absStart))
        ..add(moment('DTEND', end, zones.endZone(i), absEnd));
    }
    out.add('SUMMARY:${icsEscape(summary?.call(i) ?? i.title)}');
    final location = _location(data, i);
    if (location != null) out.add('LOCATION:${icsEscape(location)}');
    if (i.hasLocation) out.add('GEO:${i.lat};${i.lng}');
    final description = describe?.call(i) ?? i.notes;
    if (description.trim().isNotEmpty) out.add('DESCRIPTION:${icsEscape(description.trim())}');
    out
      ..add('STATUS:${i.status == ItemStatus.booked ? 'CONFIRMED' : 'TENTATIVE'}')
      // Places and hotels span days; they should not mark the time as busy.
      ..add('TRANSP:${i.kind == ItemKind.stay || i.kind == ItemKind.accommodation ? 'TRANSPARENT' : 'OPAQUE'}')
      ..add('END:VEVENT');
  }
  out.add('END:VCALENDAR');
  return '${out.map(icsFold).join('\r\n')}\r\n';
}

/// Where an item takes place: its own place, a transport's departure
/// station or origin, else the place of the stay it belongs to.
String? _location(TripData data, PlanItem i) {
  String? nonEmpty(String? s) => s == null || s.trim().isEmpty ? null : s.trim();
  if (i.kind == ItemKind.transport) {
    final from = data.item(i.fromId);
    return nonEmpty(i.departureStation) ?? nonEmpty(i.placeName) ?? nonEmpty(from?.placeName) ?? nonEmpty(from?.title);
  }
  final parent = data.item(i.parentId);
  return nonEmpty(i.placeName) ?? nonEmpty(parent?.placeName);
}

String _two(int n) => n.toString().padLeft(2, '0');
String _date(DateTime d) => '${d.year.toString().padLeft(4, '0')}${_two(d.month)}${_two(d.day)}';

/// Escapes a TEXT value (RFC 5545 §3.3.11).
String icsEscape(String s) => s
    .replaceAll('\\', '\\\\')
    .replaceAll(';', '\\;')
    .replaceAll(',', '\\,')
    .replaceAll(RegExp(r'\r\n|\r|\n'), '\\n');

/// Folds a content line to at most 75 octets per line (RFC 5545 §3.1),
/// never splitting a UTF-8 character.
String icsFold(String line) {
  if (utf8.encode(line).length <= 75) return line;
  final parts = <String>[];
  final buf = StringBuffer();
  var octets = 0;
  var limit = 75;
  for (final rune in line.runes) {
    final ch = String.fromCharCode(rune);
    final n = utf8.encode(ch).length;
    if (octets + n > limit) {
      parts.add(buf.toString());
      buf.clear();
      octets = 0;
      limit = 74; // continuation lines start with a space
    }
    buf.write(ch);
    octets += n;
  }
  parts.add(buf.toString());
  return parts.join('\r\n ');
}
