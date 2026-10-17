import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/domain/models.dart';

void main() {
  final created = DateTime(2026, 10, 17);
  final base = PlanItem(
    id: 't1',
    tripId: 'trip',
    kind: ItemKind.transport,
    title: 'ICE',
    mode: TransportMode.train,
    createdAt: created,
  );

  test('details round-trip through JSON', () {
    final i = base.copyWith(
      departureStation: 'Frankfurt Hbf',
      arrivalStation: 'Köln Hbf',
      transportNumber: 'ICE 123',
      seat: 'Wagen 5, Platz 61',
      bookingRef: 'ABC123',
    );
    final back = PlanItem.fromJson((jsonDecode(jsonEncode(i.toJson())) as Map).cast<String, Object?>());
    expect(back.departureStation, 'Frankfurt Hbf');
    expect(back.arrivalStation, 'Köln Hbf');
    expect(back.transportNumber, 'ICE 123');
    expect(back.seat, 'Wagen 5, Platz 61');
    expect(back.bookingRef, 'ABC123');
    expect(back.hasTransportDetails, isTrue);
  });

  test('JSON written before the fields existed still reads, without details', () {
    final old = base.toJson();
    for (final k in ['departureStation', 'arrivalStation', 'transportNumber', 'seat', 'bookingRef']) {
      expect(old.containsKey(k), isFalse, reason: 'empty details are not written');
    }
    final back = PlanItem.fromJson(old);
    expect(back.hasTransportDetails, isFalse);
    expect(back.mode, TransportMode.train);
  });

  test('copyWith keeps details unless replaced, null clears them', () {
    final i = base.copyWith(bookingRef: 'X1', seat: '42');
    expect(i.copyWith(title: 'Other').bookingRef, 'X1');
    final cleared = i.copyWith(bookingRef: null);
    expect(cleared.bookingRef, isNull);
    expect(cleared.seat, '42');
    expect(cleared.copyWith(seat: null).hasTransportDetails, isFalse);
  });
}
