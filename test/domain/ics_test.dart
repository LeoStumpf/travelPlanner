import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/domain/ics.dart';
import 'package:travel_planner/domain/models.dart';

import '../share_fixture.dart';

/// Unfolds the content lines of [ics] (RFC 5545 §3.1).
List<String> _lines(String ics) => ics.replaceAll('\r\n ', '').split('\r\n')..removeLast();

/// The VEVENT blocks of [ics] by UID prefix (item id).
Map<String, List<String>> _events(String ics) {
  final out = <String, List<String>>{};
  List<String>? cur;
  for (final l in _lines(ics)) {
    if (l == 'BEGIN:VEVENT') cur = [];
    if (cur != null) cur.add(l);
    if (l == 'END:VEVENT') {
      final uid = cur!.firstWhere((x) => x.startsWith('UID:'));
      out[uid.substring(4).split('@').first] = cur;
      cur = null;
    }
  }
  return out;
}

void main() {
  final now = DateTime.utc(2026, 10, 17, 12, 30);

  test('needs a start date', () {
    expect(() => buildIcs(sharedTrip(), now: now), throwsStateError);
  });

  test('a calendar with one event per planned or booked item', () {
    final ics = buildIcs(sharedTrip(startDate: DateTime(2027, 3, 10)), now: now);
    expect(ics, startsWith('BEGIN:VCALENDAR\r\nVERSION:2.0\r\n'));
    expect(ics, endsWith('END:VCALENDAR\r\n'));
    expect(_lines(ics), contains('X-WR-CALNAME:Sri Lanka'));
    expect(_events(ics).keys.toSet(), {'colombo', 'kandy', 'hotel', 'train', 'temple'});
    expect(calendarItems(sharedTrip()).map((i) => i.id), ['colombo', 'hotel', 'train', 'kandy', 'temple']);
  });

  test('without zones times are floating local times', () {
    final e = _events(buildIcs(sharedTrip(startDate: DateTime(2027, 3, 10)), now: now));
    expect(e['train'], containsAll(['DTSTART:20270312T113000', 'DTEND:20270312T143000', 'STATUS:CONFIRMED']));
    expect(e['temple'], containsAll(['DTSTART:20270313T090000', 'DTEND:20270313T110000', 'STATUS:TENTATIVE']));
    expect(e['train'], contains('DTSTAMP:20261017T123000Z'));
  });

  test('stays are all-day events with an exclusive end, not blocking time', () {
    final e = _events(buildIcs(sharedTrip(startDate: DateTime(2027, 3, 10)), now: now));
    expect(e['colombo'], containsAll(['DTSTART;VALUE=DATE:20270310', 'DTEND;VALUE=DATE:20270313', 'TRANSP:TRANSPARENT']));
    expect(e['hotel'], contains('TRANSP:TRANSPARENT'));
    expect(e['train'], contains('TRANSP:OPAQUE'));
  });

  test('with a zone the times are UTC', () {
    // Colombo is UTC+5:30 all year.
    final e = _events(buildIcs(sharedTrip(startDate: DateTime(2027, 3, 10), stayZone: 'Asia/Colombo'), now: now));
    expect(e['train'], containsAll(['DTSTART:20270312T060000Z', 'DTEND:20270312T090000Z']));
    expect(e['temple'], contains('DTSTART:20270313T033000Z'));
  });

  test('daylight saving is taken into account through the start date', () {
    // Berlin: CET (UTC+1) until Mar 28 2027, then CEST (UTC+2).
    final winter = _events(buildIcs(sharedTrip(startDate: DateTime(2027, 1, 10), homeZone: 'Europe/Berlin'), now: now));
    final summer = _events(buildIcs(sharedTrip(startDate: DateTime(2027, 7, 10), homeZone: 'Europe/Berlin'), now: now));
    expect(winter['temple'], contains('DTSTART:20270113T080000Z'));
    expect(summer['temple'], contains('DTSTART:20270713T070000Z'));
  });

  test('summary, location, geo and description', () {
    final data = sharedTrip(startDate: DateTime(2027, 3, 10));
    final items = [
      for (final i in data.items) i.id == 'temple' ? i.copyWith(lat: 7.2936, lng: 80.6413) : i,
    ];
    final ics = buildIcs(
      TripData(trip: data.trip, items: items),
      now: now,
      summary: (i) => 'S:${i.title}',
      describe: (i) => i.id == 'train' ? 'Seat 42; car 3, window\nPNR42' : '',
    );
    final e = _events(ics);
    expect(e['temple'], containsAll(['SUMMARY:S:Temple of the Tooth', 'LOCATION:Sri Dalada Maligawa', 'GEO:7.2936;80.6413']));
    expect(e['temple']!.where((l) => l.startsWith('DESCRIPTION')), isEmpty);
    expect(e['train'], contains('LOCATION:Colombo Fort'));
    expect(e['train'], contains(r'DESCRIPTION:Seat 42\; car 3\, window\nPNR42'));
    expect(e['hotel'], contains('LOCATION:Galle Road 2'));
    // A stay's place is the fallback for what belongs to it.
    final withPlace = [
      for (final i in data.items)
        if (i.id == 'kandy') i.copyWith(placeName: 'Kandy, Sri Lanka') else if (i.id == 'temple') i.copyWith(placeName: null) else i,
    ];
    final e2 = _events(buildIcs(TripData(trip: data.trip, items: withPlace), now: now));
    expect(e2['temple'], contains('LOCATION:Kandy, Sri Lanka'.replaceAll(',', r'\,')));
  });

  test('default description is the item notes', () {
    final e = _events(buildIcs(sharedTrip(startDate: DateTime(2027, 3, 10)), now: now));
    expect(e['temple'], contains('DESCRIPTION:Bring a scarf'));
  });

  group('text encoding', () {
    test('escapes backslash, semicolon, comma and newlines', () {
      expect(icsEscape(r'a\b;c,d' '\nе'), r'a\\b\;c\,d\nе');
    });

    test('folds long lines at 75 octets without splitting characters', () {
      final line = 'SUMMARY:${'ä' * 60}';
      final folded = icsFold(line);
      final parts = folded.split('\r\n');
      expect(parts.length, greaterThan(1));
      for (final p in parts) {
        expect(utf8.encode(p).length, lessThanOrEqualTo(75));
      }
      expect(parts.skip(1).every((p) => p.startsWith(' ')), isTrue);
      expect(folded.replaceAll('\r\n ', ''), line);
      expect(icsFold('SHORT:x'), 'SHORT:x');
    });
  });
}
