import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/domain/itinerary.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/domain/time.dart';

import '../share_fixture.dart';

void main() {
  final it = buildItinerary(sharedTrip());
  List<String> ids(Iterable<PlanItem> items) => [for (final i in items) i.id];
  List<(String, EntryRole)> entries(int day) => [for (final e in it.days[day].entries) (e.item.id, e.role)];

  test('only planned and booked scheduled items are shared', () {
    expect(isShared(sharedTrip().item('temple')!), isTrue);
    expect(isShared(sharedTrip().item('option')!), isFalse);
    expect(isShared(sharedTrip().item('idea')!), isFalse);
    expect(isShared(sharedTrip().item('later')!), isFalse);
    expect(ids(it.items).toSet(), {'colombo', 'kandy', 'hotel', 'train', 'temple'});
  });

  test('covers every day from the first to the last shared item', () {
    expect([for (final d in it.days) d.day], [0, 1, 2, 3, 4]);
    expect(it.dayCount, 5);
    expect(ids(it.stays), ['colombo', 'kandy']);
  });

  test('planned length adds empty days at the end', () {
    final data = sharedTrip();
    final longer = TripData(trip: data.trip.copyWith(plannedDays: 7), items: data.items);
    final days = buildItinerary(longer).days;
    expect(days.length, 7);
    expect(days.last.isEmpty, isTrue);
  });

  test('stays touching each day, two on the travel day', () {
    expect(ids(it.days[1].stays), ['colombo']);
    expect(ids(it.days[2].stays), ['colombo', 'kandy']);
  });

  test('accommodation appears with check-in and check-out, nights in between', () {
    expect(entries(0), [('hotel', EntryRole.checkIn)]);
    expect(it.days[0].night?.id, 'hotel');
    expect(it.days[0].checksIntoNight, isTrue);
    expect(entries(1), isEmpty);
    expect(it.days[1].night?.id, 'hotel');
    expect(it.days[1].checksIntoNight, isFalse);
    expect(it.days[1].isEmpty, isFalse);
  });

  test('a travel day is chronological: check-out before the train', () {
    expect(entries(2), [('hotel', EntryRole.checkOut), ('train', EntryRole.transport)]);
    expect(it.days[2].entries.first.minute, at(2, 11 * 60));
  });

  test('nights without a confirmed bed are flagged, options do not count', () {
    expect(it.days[2].needsBed, isTrue);
    expect(it.days[3].needsBed, isTrue);
    expect(it.days[2].night, isNull);
    expect(it.days[4].needsBed, isFalse);
  });

  test('same-minute entries: check-out, transport, activity, check-in', () {
    expect(EntryRole.values, [EntryRole.checkOut, EntryRole.transport, EntryRole.activity, EntryRole.checkIn]);
  });

  test('notes linked to a shared item go with it, the rest into the notes section', () {
    expect([for (final c in it.cardsByItem['temple']!) c.id], ['c1']);
    expect([for (final c in it.notes) c.id], ['c2']); // the empty image card is left out
  });

  test('notes on options, ideas and unscheduled items stay private', () {
    final data = sharedTrip();
    NoteCard card(String id, String? itemId) =>
        NoteCard(id: id, tripId: 't', type: CardType.note, text: 'Text $id', itemId: itemId, createdAt: DateTime(2026));
    final cards = [...data.cards, card('o', 'option'), card('i', 'idea'), card('l', 'later'), card('g', 'gone')];
    final it = buildItinerary(TripData(trip: data.trip, items: data.items, cards: cards));
    expect([for (final c in it.notes) c.id], ['c2', 'g']);
    expect(it.cardsByItem.keys, ['temple']);
  });

  test('an overnight transport is listed on its departure day only', () {
    final data = sharedTrip();
    final night = data.item('train')!.copyWith(start: at(1, 22 * 60), end: at(2, 6 * 60));
    final items = [for (final i in data.items) i.id == 'train' ? night : i];
    final days = buildItinerary(TripData(trip: data.trip, items: items)).days;
    expect(days[1].entries.map((e) => e.item.id), contains('train'));
    expect(days[2].entries.map((e) => e.item.id), isNot(contains('train')));
  });

  test('an empty trip still has its first day', () {
    final empty = buildItinerary(TripData(trip: sharedTrip().trip));
    expect(empty.days.length, 1);
    expect(empty.days.single.isEmpty, isTrue);
    expect(empty.stays, isEmpty);
  });
}
