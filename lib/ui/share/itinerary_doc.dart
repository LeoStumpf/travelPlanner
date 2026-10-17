// The itinerary (lib/domain/itinerary.dart) in words: a small document model
// that the plain-text export and the PDF (itinerary_pdf.dart) both render,
// plus the wording of calendar events (ics.dart).
import '../../domain/itinerary.dart';
import '../../domain/models.dart';
import '../../domain/time.dart';
import '../../domain/zones.dart';
import '../common/l10n.dart';

/// One line of a day: "09:15–12:40  Train: Colombo → Kandy".
class DocEntry {
  final ItemKind kind;
  final String time;
  final String title;

  /// Shown as a tag after the title ("booked").
  final String? tag;

  /// Facts under the title: place, stations, numbers, booking reference.
  final List<String> details;

  /// Free text: the item's notes, linked notes, links.
  final List<String> notes;

  const DocEntry({
    required this.kind,
    required this.time,
    required this.title,
    this.tag,
    this.details = const [],
    this.notes = const [],
  });
}

class DocDay {
  /// "Wed, Mar 12 (day 3)" or "Day 3".
  final String heading;

  /// "Colombo → Kandy"; empty when no place is planned.
  final String places;
  final List<DocEntry> entries;

  /// Lines after the entries: the night's bed, a missing bed, a free day.
  final List<String> remarks;

  const DocDay({required this.heading, this.places = '', this.entries = const [], this.remarks = const []});
}

class DocNote {
  final String title;
  final List<String> lines;
  const DocNote(this.title, this.lines);
}

class ItineraryDoc {
  final String title;

  /// Dates and length: "Mar 10 – Mar 24, 2027 · 15 days".
  final String subtitle;

  /// Hint shown when the trip has no start date, else null.
  final String? dateHint;
  final List<String> route;
  final List<DocDay> days;
  final List<DocNote> notes;
  final String footer;

  const ItineraryDoc({
    required this.title,
    required this.subtitle,
    this.dateHint,
    this.route = const [],
    this.days = const [],
    this.notes = const [],
    required this.footer,
  });
}

/// Words the itinerary of one trip in language [l].
class ItineraryWriter {
  final AppLocalizations l;
  final TripData data;
  final Itinerary itinerary;
  late final TripZones _zones = data.zones;

  ItineraryWriter(this.l, this.data) : itinerary = buildItinerary(data);

  DateTime? get _start => data.trip.startDate;

  String _day(int d) => l.day(_start, d);

  /// [minute] as clock time, with the day when it is not on [day].
  String _clock(int minute, int day) =>
      dayOf(minute) == day ? formatClock(minute) : '${formatClock(minute)} (${_day(dayOf(minute))})';

  ItineraryDoc document({required DateTime now}) {
    final it = itinerary;
    final length = l.days(it.dayCount);
    final subtitle = _start == null
        ? length
        : '${l.date(dateOfDay(_start!, it.firstDay))} – ${l.date(dateOfDay(_start!, it.lastDay))} · $length';
    return ItineraryDoc(
      title: data.trip.title,
      subtitle: subtitle,
      dateHint: _start == null ? l.shareNoStartDate : null,
      route: [
        for (final s in it.stays)
          l.shareStayLine(
            _placeTitle(s),
            l.nights(nightsIn(s.start!, s.end!)),
            _day(dayOf(s.start!)),
            _day(lastDayOf(s.end!)),
          ),
      ],
      days: [for (final d in it.days) _dayDoc(d)],
      notes: [for (final c in it.notes) _note(c)],
      footer: l.shareGeneratedBy(l.date(now)),
    );
  }

  String _placeTitle(PlanItem s) => s.title.trim().isEmpty ? (s.placeName ?? '') : s.title.trim();

  DocDay _dayDoc(ItineraryDay d) {
    final remarks = <String>[
      if (d.night != null && !d.checksIntoNight) l.shareNight(d.night!.title),
      if (d.needsBed) l.shareNoBed,
    ];
    final entries = [for (final e in d.entries) entry(e, d.day)];
    if (entries.isEmpty && remarks.isEmpty) remarks.add(l.shareFreeDay);
    return DocDay(
      heading: _start == null ? l.dayNumber(d.day + 1) : l.day(_start, d.day, withDayNumber: true),
      places: d.stays.map(_placeTitle).join(' → '),
      entries: entries,
      remarks: remarks,
    );
  }

  /// One entry of trip day [day].
  DocEntry entry(ItineraryEntry e, int day) {
    final i = e.item;
    final tag = i.status == ItemStatus.booked ? l.shareBooked : null;
    switch (e.role) {
      case EntryRole.checkOut:
        return DocEntry(kind: i.kind, time: formatClock(i.end!), title: l.shareCheckOut(i.title));
      case EntryRole.checkIn:
        final n = nightsIn(i.start!, i.end!);
        return DocEntry(
          kind: i.kind,
          time: formatClock(i.start!),
          title: l.shareCheckIn(i.title),
          tag: tag,
          details: [
            ?_text(i.placeName),
            if (n > 0) l.shareNightsUntil(l.nights(n), _day(lastDayOf(i.end!))),
          ],
          notes: _notes(i),
        );
      case EntryRole.transport:
        return DocEntry(
          kind: i.kind,
          time: '${formatClock(i.start!)}–${_clock(i.end!, day)}',
          title: i.mode == null ? i.title : '${l.mode(i.mode!)}: ${i.title}',
          tag: tag,
          details: transportDetails(i),
          notes: _notes(i),
        );
      case EntryRole.activity:
        return DocEntry(
          kind: i.kind,
          time: i.duration <= 0 ? formatClock(i.start!) : '${formatClock(i.start!)}–${_clock(i.end!, day)}',
          title: i.title,
          tag: tag,
          details: [?_text(i.placeName)],
          notes: _notes(i),
        );
    }
  }

  /// Stations, number, seat, booking reference and – across zones – the
  /// offsets and the real duration.
  List<String> transportDetails(PlanItem i) {
    final dep = _text(i.departureStation), arr = _text(i.arrivalStation);
    return [
      if (dep != null || arr != null) '${dep ?? '?'} → ${arr ?? '?'}',
      if (_text(i.transportNumber) case final n?) '${l.transportNumberLabel}: $n',
      if (_text(i.seat) case final s?) '${l.seatLabel}: $s',
      if (_text(i.bookingRef) case final b?) '${l.bookingRefLabel}: $b',
      if (_zones.crossesZones(i))
        '${_zones.startOffsetLabel(i)} → ${_zones.endOffsetLabel(i)} · '
            '${l.shareDuration(l.duration(_zones.absDuration(i), withMinutes: true))}',
    ];
  }

  String? _text(String? s) => s == null || s.trim().isEmpty ? null : s.trim();

  /// The item's notes and links, then its linked notes.
  List<String> _notes(PlanItem i) => [
        for (final line in i.notes.trim().split('\n'))
          if (line.trim().isNotEmpty) line.trimRight(),
        ...i.links,
        for (final c in itinerary.cardsByItem[i.id] ?? const <NoteCard>[]) ..._cardLines(c, withTitle: true),
      ];

  DocNote _note(NoteCard c) => DocNote(c.title.trim(), _cardLines(c, withTitle: false));

  List<String> _cardLines(NoteCard c, {required bool withTitle}) {
    final lines = <String>[
      for (final line in c.text.trim().split('\n'))
        if (line.trim().isNotEmpty) line.trimRight(),
      for (final e in c.checklist) '[${e.done ? 'x' : ' '}] ${e.text}',
      if (c.type == CardType.link && c.url != null) c.url!,
    ];
    if (!withTitle || c.title.trim().isEmpty) return lines;
    return lines.isEmpty ? [c.title.trim()] : ['${c.title.trim()}: ${lines.first}', ...lines.skip(1)];
  }

  /// The event title of item [i] in the calendar: for transports with the
  /// mode, for accommodation the hotel name.
  String eventSummary(PlanItem i) => switch (i.kind) {
        ItemKind.transport when i.mode != null => '${l.mode(i.mode!)}: ${i.title}',
        _ => i.title,
      };

  /// The event description of [i]: the details and notes of its entry.
  String eventDescription(PlanItem i) {
    final details = switch (i.kind) {
      ItemKind.transport => transportDetails(i),
      ItemKind.accommodation || ItemKind.activity => [?_text(i.placeName)],
      ItemKind.stay => <String>[],
    };
    return [
      ...details,
      if (i.status == ItemStatus.booked) l.status(ItemStatus.booked),
      ..._notes(i),
    ].join('\n');
  }
}

/// The document as plain text for messengers and email.
String itineraryText(ItineraryDoc doc, AppLocalizations l) {
  final b = StringBuffer()
    ..writeln(doc.title)
    ..writeln(doc.subtitle);
  if (doc.dateHint != null) b.writeln(doc.dateHint);
  if (doc.route.isNotEmpty) {
    b
      ..writeln()
      ..writeln(l.shareRoute.toUpperCase());
    for (final r in doc.route) {
      b.writeln('• $r');
    }
  }
  b
    ..writeln()
    ..writeln(l.shareDayByDay.toUpperCase());
  for (final d in doc.days) {
    b
      ..writeln()
      ..writeln(d.places.isEmpty ? d.heading : '${d.heading} – ${d.places}');
    for (final e in d.entries) {
      b.writeln('  ${e.time}  ${e.title}${e.tag == null ? '' : ' (${e.tag})'}');
      for (final x in [...e.details, ...e.notes]) {
        b.writeln('      $x');
      }
    }
    for (final r in d.remarks) {
      b.writeln('  $r');
    }
  }
  if (doc.notes.isNotEmpty) {
    b
      ..writeln()
      ..writeln(l.notesLabel.toUpperCase());
    for (final n in doc.notes) {
      b.writeln('• ${n.title.isEmpty ? (n.lines.firstOrNull ?? '') : n.title}');
      for (final x in n.title.isEmpty ? n.lines.skip(1) : n.lines) {
        b.writeln('  $x');
      }
    }
  }
  b
    ..writeln()
    ..writeln(doc.footer);
  return b.toString();
}

/// A file name for the trip ("Sri Lanka 2027"), without characters file
/// systems dislike.
String shareFileName(Trip trip, String extension) {
  final safe = trip.title.replaceAll(RegExp(r'[^\w\- äöüÄÖÜß]'), '_').trim();
  return '${safe.isEmpty ? 'trip' : safe}.$extension';
}
