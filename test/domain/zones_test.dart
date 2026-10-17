import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/domain/analysis.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/domain/scheduler.dart';
import 'package:travel_planner/domain/time.dart';
import 'package:travel_planner/domain/zones.dart';

final _t0 = DateTime(2026, 1, 1);

/// 1 March 2027: Berlin is on winter time (UTC+1), Colombo is UTC+5:30.
final _march = DateTime(2027, 3, 1);

const berlin = 'Europe/Berlin';
const colombo = 'Asia/Colombo';

PlanItem stay(String id, int start, int end, {String? tz}) => PlanItem(
      id: id,
      tripId: 't',
      kind: ItemKind.stay,
      title: id,
      start: start,
      end: end,
      tz: tz,
      createdAt: _t0,
    );

PlanItem ride(String id, String? from, String? to, int start, int end, {String? tz, String? endTz}) => PlanItem(
      id: id,
      tripId: 't',
      kind: ItemKind.transport,
      title: id,
      mode: TransportMode.plane,
      fromId: from,
      toId: to,
      start: start,
      end: end,
      tz: tz,
      endTz: endTz,
      createdAt: _t0,
    );

Trip trip({String? homeZone, DateTime? start}) =>
    Trip(id: 't', title: 'T', startDate: start ?? _march, homeZone: homeZone, createdAt: _t0);

TripZones zonesOf(List<PlanItem> items, {String? homeZone, DateTime? start}) =>
    TripZones.of(trip(homeZone: homeZone, start: start), items);

/// Frankfurt → flight LH 754 → Colombo, all times local:
/// FRA day 1 21:30 (20:30 UTC) – CMB day 2 10:30 (05:00 UTC) = 8 h 30 min.
List<PlanItem> fraToCmb() => [
      stay('fra', at(0, 14 * 60), at(1, 19 * 60), tz: berlin),
      ride('lh754', 'fra', 'cmb', at(1, 21 * 60 + 30), at(2, 10 * 60 + 30)),
      stay('cmb', at(2, 10 * 60 + 30), at(5, 10 * 60), tz: colombo),
    ];

void main() {
  group('helpers', () {
    test('formatUtcOffset', () {
      expect(formatUtcOffset(0), 'UTC');
      expect(formatUtcOffset(330), 'UTC+5:30');
      expect(formatUtcOffset(60), 'UTC+1');
      expect(formatUtcOffset(-180), 'UTC−3');
      expect(formatUtcOffset(-570), 'UTC−9:30');
    });

    test('known zones and the picker list', () {
      expect(isKnownZone(colombo), isTrue);
      expect(isKnownZone('Mars/Olympus'), isFalse);
      expect(isKnownZone(null), isFalse);
      final names = allZoneNames();
      expect(names, containsAll([colombo, berlin, 'Pacific/Honolulu', 'UTC']));
      expect(names, isNot(contains('US/Eastern')));
      expect(names, isNot(contains('Etc/GMT+3')));
      expect(zoneCity('America/Argentina/Buenos_Aires'), 'Buenos Aires');
    });
  });

  group('TripZones', () {
    test('without any zone everything is the identity (old behaviour)', () {
      final items = [stay('a', at(0, 600), at(2, 600)), ride('r', 'a', null, at(2, 700), at(2, 800))];
      final z = zonesOf(items);
      expect(z.isActive, isFalse);
      expect(z.startZone(items[1]), isNull);
      expect(z.absStart(items[1]), at(2, 700));
      expect(z.absDuration(items[1]), 100);
      expect(z.crossesZones(items[1]), isFalse);
      expect(TripZones.none.absEnd(items[0]), at(2, 600));
    });

    test('flight FRA → CMB: zones from the stays, real duration 8 h 30 min', () {
      final items = fraToCmb();
      final z = zonesOf(items);
      final lh = items[1];
      expect(z.isActive, isTrue);
      expect(z.startZone(lh), berlin);
      expect(z.endZone(lh), colombo);
      expect(z.absStart(lh), at(1, 20 * 60 + 30));
      expect(z.absEnd(lh), at(2, 5 * 60));
      expect(lh.duration, 13 * 60, reason: 'the clock difference');
      expect(z.absDuration(lh), 8 * 60 + 30);
      expect(z.crossesZones(lh), isTrue);
      expect(z.startOffsetLabel(lh), 'UTC+1');
      expect(z.endOffsetLabel(lh), 'UTC+5:30');
      expect(z.crossesZones(items[0]), isFalse);
    });

    test('lodging and activities follow their stay, loose items the home zone', () {
      final cmb = stay('cmb', at(2, 600), at(5, 600), tz: colombo);
      final hotel = PlanItem(
          id: 'h', tripId: 't', kind: ItemKind.accommodation, title: 'h', parentId: 'cmb', createdAt: _t0);
      final loose = PlanItem(id: 'x', tripId: 't', kind: ItemKind.activity, title: 'x', createdAt: _t0);
      final plain = stay('p', at(0, 600), at(1, 600));
      final z = zonesOf([cmb, hotel, loose, plain], homeZone: berlin);
      expect(z.startZone(hotel), colombo);
      expect(z.startZone(loose), berlin);
      expect(z.startZone(plain), berlin);
      expect(z.zoneOfStay(cmb), colombo);
    });

    test('a transport may override its departure and arrival zone', () {
      final items = [...fraToCmb()];
      items[1] = items[1].copyWith(tz: 'UTC', endTz: 'Asia/Kolkata');
      final z = zonesOf(items);
      expect(z.startZone(items[1]), 'UTC');
      expect(z.endZone(items[1]), 'Asia/Kolkata');
    });

    test('daylight saving: a 2-day stay over the switch lasts 47 hours', () {
      // Clocks in Berlin go forward on Sunday 28 March 2027.
      final s = stay('s', at(0, 12 * 60), at(2, 12 * 60));
      final z = zonesOf([s], homeZone: berlin, start: DateTime(2027, 3, 27));
      expect(z.offsetAt(berlin, s.start!), 60);
      expect(z.offsetAt(berlin, s.end!), 120);
      expect(z.absDuration(s), 47 * 60);
    });

    test('converting between zones', () {
      final z = zonesOf(const [], homeZone: berlin);
      // 21:30 in Berlin is 02:00 the next day in Colombo.
      expect(z.convert(at(1, 21 * 60 + 30), berlin, colombo), at(2, 2 * 60));
      expect(z.toLocal(colombo, z.toAbs(berlin, 600)), 600 + 270);
      expect(z.convert(500, null, null), 500);
    });

    test('items without a zone fall back to the home zone and mix correctly', () {
      // Frankfurt has no own zone but the trip is planned from Berlin.
      final items = fraToCmb();
      items[0] = items[0].copyWith(tz: null);
      final z = zonesOf(items, homeZone: berlin);
      expect(z.absDuration(items[1]), 8 * 60 + 30);
    });

    test('TripData.zones is cached and lists the zones in use', () {
      final data = TripData(trip: trip(homeZone: berlin), items: fraToCmb());
      expect(identical(data.zones, data.zones), isTrue);
      expect(data.usedZones, [berlin, colombo]);
    });
  });

  group('analysis with zones', () {
    test('FRA → CMB has no conflicts', () {
      final items = fraToCmb();
      expect(findConflicts(items, zones: zonesOf(items)), isEmpty);
    });

    test('a real overlap the clocks hide is found', () {
      // Leave Frankfurt 10:00 (09:00 UTC) but be in Colombo from 12:00
      // (06:30 UTC) the same day: two and a half hours in two places.
      final items = [
        stay('fra', at(0, 14 * 60), at(1, 10 * 60), tz: berlin),
        stay('cmb', at(1, 12 * 60), at(4, 10 * 60), tz: colombo),
      ];
      expect(findConflicts(items), isEmpty, reason: 'without zones 10:00 < 12:00');
      final c = findConflicts(items, zones: zonesOf(items)).single;
      expect(c.type, ConflictType.staysOverlap);
      expect(c.amount, 150);
      expect(c.itemId, 'cmb');
      // The fix pushes Colombo by a whole day.
      expect(c.fix!.times['cmb'], (at(2, 12 * 60), at(5, 10 * 60)));
    });

    test('flying home: no fake overlap when the clock goes back', () {
      // Leave Colombo 10:00 (04:30 UTC), be in Frankfurt from 09:00 (08:00 UTC).
      final items = [
        stay('cmb', at(2, 12 * 60), at(5, 10 * 60), tz: colombo),
        stay('fra', at(5, 9 * 60), at(7, 10 * 60), tz: berlin),
      ];
      expect(findConflicts(items).single.type, ConflictType.staysOverlap, reason: 'local clocks overlap');
      expect(findConflicts(items, zones: zonesOf(items)), isEmpty);
    });

    test('Tokyo → Honolulu over the date line lands "before" it took off', () {
      const tokyo = 'Asia/Tokyo', honolulu = 'Pacific/Honolulu';
      // Depart Tokyo day 3 21:00 (12:00 UTC), 7 h flight, land Honolulu
      // day 3 09:00 local (19:00 UTC).
      final items = [
        stay('tyo', at(0, 14 * 60), at(3, 18 * 60), tz: tokyo),
        ride('fl', 'tyo', 'hnl', at(3, 21 * 60), at(3, 9 * 60)),
        stay('hnl', at(3, 11 * 60), at(6, 10 * 60), tz: honolulu),
      ];
      final z = zonesOf(items);
      expect(z.absDuration(items[1]), 7 * 60);
      expect(findConflicts(items, zones: z), isEmpty);
      expect(findConflicts(items).map((c) => c.type), contains(ConflictType.staysOverlap));
      expect(stayChain(items, zones: z).map((s) => s.id), ['tyo', 'hnl']);
      expect(missingTransports(items, zones: z), isEmpty);
    });

    test('a departure zone override is compared in the stay\'s local time', () {
      // 23:30 UTC is 00:30 the next day in Frankfurt: a day without a place.
      final items = [...fraToCmb()];
      items[1] = items[1].copyWith(tz: 'UTC', start: at(1, 23 * 60 + 30), end: at(2, 10 * 60 + 30));
      final c = findConflicts(items, zones: zonesOf(items)).single;
      expect(c.type, ConflictType.daysBeforeDeparture);
      expect(c.amount, 1);
      // Fix: stay in Frankfurt until the departure, in Frankfurt time.
      expect(c.fix!.times['fra'], (at(0, 14 * 60), at(2, 30)));
    });

    test('arrival fix uses the destination\'s local time', () {
      // The flight lands in Colombo 10:30, the stay begins only a day later.
      final items = [...fraToCmb()];
      items[2] = items[2].copyWith(start: at(3, 14 * 60));
      final c = findConflicts(items, zones: zonesOf(items)).single;
      expect(c.type, ConflictType.daysAfterArrival);
      expect(c.fix!.times['cmb'], (at(2, 10 * 60 + 30), at(5, 10 * 60)));
    });

    test('suggested transport times: departure local at the origin, arrival local at the destination', () {
      final items = fraToCmb()..removeAt(1);
      final z = zonesOf(items, homeZone: berlin);
      // Leaves Frankfurt 19:00 (18:00 UTC), 3 h → 21:00 UTC = 02:30 in Colombo.
      expect(suggestTransportTimes(items[0], items[1], zones: z), (at(1, 19 * 60), at(2, 2 * 60 + 30)));
      // Only the destination: arrive as Colombo begins, leave 3 h earlier
      // in home (Berlin) time: 05:00 UTC − 3 h = 02:00 UTC = 03:00 Berlin.
      expect(suggestTransportTimes(null, items[1], zones: z), (at(2, 3 * 60), at(2, 10 * 60 + 30)));
      // Without zones as before.
      expect(suggestTransportTimes(items[0], items[1]), (at(1, 19 * 60), at(1, 22 * 60)));
    });
  });

  group('scheduler with zones', () {
    test('push compares on absolute time', () {
      // Frankfurt until 10:00 (09:00 UTC), Colombo from 16:00 (10:30 UTC).
      final items = [
        stay('fra', at(0, 14 * 60), at(2, 10 * 60), tz: berlin),
        stay('cmb', at(2, 16 * 60), at(5, 10 * 60), tz: colombo),
      ];
      // Three hours longer in Frankfurt: 13:00 = 12:00 UTC, after Colombo began.
      final r = Scheduler.resizeEnd(items, 'fra', 180, ShiftMode.push, zones: zonesOf(items));
      expect(r.changedIds, {'fra', 'cmb'});
      expect(r.items.last.start, at(3, 16 * 60));
      // By the clocks 13:00 < 16:00, so nothing would move.
      expect(Scheduler.resizeEnd(items, 'fra', 180, ShiftMode.push).changedIds, {'fra'});
    });

    test('inserting in following mode makes room by absolute overlap', () {
      final cmb = stay('cmb', at(1, 12 * 60), at(4, 10 * 60), tz: colombo);
      final fra = stay('fra', at(0, 14 * 60), at(1, 10 * 60), tz: berlin);
      final r = Scheduler.insert([cmb], fra, ShiftMode.following, zones: zonesOf([cmb, fra]));
      expect(r.items.firstWhere((i) => i.id == 'cmb').start, at(2, 12 * 60));
      expect(Scheduler.insert([cmb], fra, ShiftMode.following).changedIds, {'fra'});
    });

    test('shortening a flight stops one hour after take-off in real time', () {
      const tokyo = 'Asia/Tokyo', honolulu = 'Pacific/Honolulu';
      final items = [
        stay('tyo', at(0, 14 * 60), at(3, 18 * 60), tz: tokyo),
        ride('fl', 'tyo', 'hnl', at(3, 21 * 60), at(3, 9 * 60)),
        stay('hnl', at(3, 11 * 60), at(6, 10 * 60), tz: honolulu),
      ];
      final z = zonesOf(items);
      final r = Scheduler.resizeEnd(items, 'fl', -10 * 60, ShiftMode.single, zones: z);
      final fl = r.items[1];
      // 12:00 UTC + 1 h = 13:00 UTC = 03:00 in Honolulu.
      expect(fl.end, at(3, 3 * 60));
      expect(z.absDuration(fl), 60);
      // Moving the start later stops an hour before landing.
      final s = Scheduler.resizeStart(items, 'fl', 10 * 60, zones: z).items[1];
      expect(z.absDuration(s), 60);
    });

    test('moving a stay keeps local times in its own zone', () {
      final items = fraToCmb();
      final r = Scheduler.move(items, 'fra', minutesPerDay, ShiftMode.following, zones: zonesOf(items));
      expect(r.items.map((i) => i.start), [at(1, 14 * 60), at(2, 21 * 60 + 30), at(3, 10 * 60 + 30)]);
    });
  });

  group('JSON', () {
    test('zone fields round-trip and are optional', () {
      final s = stay('a', 0, 600, tz: colombo);
      expect(PlanItem.fromJson(s.toJson()).tz, colombo);
      final r = ride('r', null, null, 0, 600, tz: berlin, endTz: colombo);
      final back = PlanItem.fromJson(r.toJson());
      expect([back.tz, back.endTz], [berlin, colombo]);
      final t = trip(homeZone: berlin);
      expect(Trip.fromJson(t.toJson()).homeZone, berlin);

      // Rows written before zones existed.
      final old = stay('o', 0, 600).toJson();
      expect(old.containsKey('tz'), isFalse);
      expect(PlanItem.fromJson(old).tz, isNull);
      final oldTrip = trip().toJson()..remove('homeZone');
      expect(Trip.fromJson(oldTrip).homeZone, isNull);
      expect(t.copyWith(homeZone: null).homeZone, isNull);
      expect(t.copyWith(title: 'x').homeZone, berlin);
    });
  });
}
