// A small trip for the sharing tests (itinerary, text/PDF, ICS):
// Colombo day 0–2 with a booked hotel, a booked train to Kandy on day 2,
// Kandy day 2–4 without a bed, a temple visit on day 3. Options, ideas and
// unscheduled items must not show up anywhere.
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/domain/time.dart';

final _t0 = DateTime(2026, 1, 1);

PlanItem _item(String id, ItemKind kind, String title,
        {int? start,
        int? end,
        ItemStatus status = ItemStatus.planned,
        String? parentId,
        String? fromId,
        String? toId,
        TransportMode? mode,
        String? placeName,
        String notes = '',
        String? tz}) =>
    PlanItem(
      id: id,
      tripId: 't',
      kind: kind,
      title: title,
      start: start,
      end: end,
      status: status,
      parentId: parentId,
      fromId: fromId,
      toId: toId,
      mode: mode,
      placeName: placeName,
      notes: notes,
      tz: tz,
      createdAt: _t0,
    );

TripData sharedTrip({DateTime? startDate, String? homeZone, String? stayZone}) => TripData(
      trip: Trip(id: 't', title: 'Sri Lanka', startDate: startDate, homeZone: homeZone, createdAt: _t0),
      items: [
        _item('colombo', ItemKind.stay, 'Colombo', start: at(0, 14 * 60), end: at(2, 10 * 60), tz: stayZone),
        _item('kandy', ItemKind.stay, 'Kandy', start: at(2, 14 * 60), end: at(4, 10 * 60), tz: stayZone),
        _item('hotel', ItemKind.accommodation, 'Hotel Galle Face',
            start: at(0, 15 * 60),
            end: at(2, 11 * 60),
            status: ItemStatus.booked,
            parentId: 'colombo',
            placeName: 'Galle Road 2'),
        _item('train', ItemKind.transport, 'Colombo → Kandy',
                start: at(2, 11 * 60 + 30),
                end: at(2, 14 * 60 + 30),
                status: ItemStatus.booked,
                fromId: 'colombo',
                toId: 'kandy',
                mode: TransportMode.train)
            .copyWith(departureStation: 'Colombo Fort', arrivalStation: 'Kandy', transportNumber: 'IC 1009', seat: 'Car 3, seat 42', bookingRef: 'PNR42'),
        _item('temple', ItemKind.activity, 'Temple of the Tooth',
            start: at(3, 9 * 60), end: at(3, 11 * 60), parentId: 'kandy', placeName: 'Sri Dalada Maligawa', notes: 'Bring a scarf'),
        // Never shared:
        _item('option', ItemKind.accommodation, 'Kandy Hills',
            start: at(2, 15 * 60), end: at(4, 11 * 60), status: ItemStatus.option, parentId: 'kandy'),
        _item('idea', ItemKind.activity, 'Spice garden', start: at(3, 14 * 60), end: at(3, 15 * 60), status: ItemStatus.idea),
        _item('later', ItemKind.activity, 'Elephant orphanage'),
      ],
      cards: [
        NoteCard(id: 'c1', tripId: 't', type: CardType.note, title: 'Tickets', text: 'Buy at the gate', itemId: 'temple', createdAt: _t0),
        NoteCard(
          id: 'c2',
          tripId: 't',
          type: CardType.checklist,
          title: 'Packing',
          checklist: const [ChecklistEntry(id: 'e1', text: 'Sun cream', done: true), ChecklistEntry(id: 'e2', text: 'Adapter')],
          createdAt: _t0,
        ),
        NoteCard(id: 'c3', tripId: 't', type: CardType.image, createdAt: _t0), // nothing readable
      ],
    );
