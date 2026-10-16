// Example trips that show off the planner's concepts.
import 'package:uuid/uuid.dart';

import 'models.dart';
import 'time.dart';

class _B {
  final String tripId = const Uuid().v4();
  final items = <PlanItem>[];
  final cards = <NoteCard>[];
  final edges = <Edge>[];
  final now = DateTime.now();
  int _n = 0;

  DateTime _ts() => now.add(Duration(milliseconds: _n++));

  PlanItem stay(String title, double lat, double lng, int firstDay, int nights,
      {ItemStatus status = ItemStatus.planned, bool scheduled = true, String notes = ''}) {
    final i = PlanItem(
      id: const Uuid().v4(),
      tripId: tripId,
      kind: ItemKind.stay,
      title: title,
      placeName: title,
      lat: lat,
      lng: lng,
      status: status,
      start: scheduled ? at(firstDay, defaultStayArrival) : null,
      end: scheduled ? at(firstDay + nights, defaultStayDeparture) : null,
      notes: notes,
      createdAt: _ts(),
    );
    items.add(i);
    return i;
  }

  PlanItem lodging(String title, PlanItem stay, int checkInDay, int nights,
      {ItemStatus status = ItemStatus.planned, double? lat, double? lng, List<String> links = const []}) {
    final i = PlanItem(
      id: const Uuid().v4(),
      tripId: tripId,
      kind: ItemKind.accommodation,
      title: title,
      parentId: stay.id,
      lat: lat ?? stay.lat! + 0.004,
      lng: lng ?? stay.lng! + 0.004,
      status: status,
      start: at(checkInDay, defaultCheckIn),
      end: at(checkInDay + nights, defaultCheckOut),
      links: links,
      createdAt: _ts(),
    );
    items.add(i);
    return i;
  }

  PlanItem activity(String title, PlanItem stay, int day, int fromMin, int toMin,
      {bool fixed = false, ItemStatus status = ItemStatus.planned, double? lat, double? lng}) {
    final i = PlanItem(
      id: const Uuid().v4(),
      tripId: tripId,
      kind: ItemKind.activity,
      title: title,
      parentId: stay.id,
      lat: lat,
      lng: lng,
      status: status,
      fixed: fixed,
      start: at(day, fromMin),
      end: at(day, toMin),
      createdAt: _ts(),
    );
    items.add(i);
    return i;
  }

  PlanItem transport(String title, TransportMode mode, PlanItem? from, PlanItem? to, int day, int fromMin,
      int toMin,
      {bool fixed = false, ItemStatus status = ItemStatus.planned, int arrivalDayOffset = 0}) {
    final i = PlanItem(
      id: const Uuid().v4(),
      tripId: tripId,
      kind: ItemKind.transport,
      title: title,
      mode: mode,
      fromId: from?.id,
      toId: to?.id,
      status: status,
      fixed: fixed,
      start: at(day, fromMin),
      end: at(day + arrivalDayOffset, toMin),
      createdAt: _ts(),
    );
    items.add(i);
    return i;
  }

  NoteCard note(String title, String text, {int color = 0, bool pinned = false, String? itemId}) {
    final c = NoteCard(
      id: const Uuid().v4(),
      tripId: tripId,
      type: CardType.note,
      title: title,
      text: text,
      color: color,
      pinned: pinned,
      itemId: itemId,
      createdAt: _ts(),
    );
    cards.add(c);
    return c;
  }

  NoteCard checklist(String title, List<String> entries, {int color = 0, Set<int> done = const {}}) {
    final c = NoteCard(
      id: const Uuid().v4(),
      tripId: tripId,
      type: CardType.checklist,
      title: title,
      checklist: [
        for (var k = 0; k < entries.length; k++)
          ChecklistEntry(id: const Uuid().v4(), text: entries[k], done: done.contains(k)),
      ],
      color: color,
      createdAt: _ts(),
    );
    cards.add(c);
    return c;
  }

  NoteCard link(String title, String url, {String? itemId}) {
    final c = NoteCard(
      id: const Uuid().v4(),
      tripId: tripId,
      type: CardType.link,
      title: title,
      url: url,
      itemId: itemId,
      createdAt: _ts(),
    );
    cards.add(c);
    return c;
  }

  void connect(String a, String b, [String label = '']) =>
      edges.add(Edge(id: const Uuid().v4(), tripId: tripId, fromId: a, toId: b, label: label));
}

TripData demoInterrail() {
  final b = _B();
  final trip = Trip(
    id: b.tripId,
    title: 'Interrail Frankreich & Spanien',
    plannedDays: 14,
    color: 0xFF1F5FD1,
    createdAt: b.now,
  );
  final paris = b.stay('Paris', 48.8566, 2.3522, 0, 3);
  final lyon = b.stay('Lyon', 45.7640, 4.8357, 3, 2);
  final bcn = b.stay('Barcelona', 41.3874, 2.1686, 8, 3);
  final val = b.stay('Valencia', 39.4699, -0.3763, 11, 2);
  b.stay('Avignon', 43.9493, 4.8055, 0, 1, status: ItemStatus.idea, scheduled: false,
      notes: 'Passt evtl. in die freien Tage zwischen Lyon und Barcelona');

  b.lodging('Hôtel du Marais', paris, 0, 3, status: ItemStatus.booked);
  b.lodging('Airbnb Croix-Rousse', lyon, 3, 2, status: ItemStatus.option);
  b.lodging('Auberge Vieux Lyon', lyon, 3, 2, status: ItemStatus.option, lat: 45.762, lng: 4.827);
  b.lodging('Hostel Gràcia', bcn, 8, 3);

  b.activity('Louvre', paris, 1, 10 * 60, 14 * 60, lat: 48.8606, lng: 2.3376);
  b.activity('Sagrada Família (gebucht)', bcn, 9, 11 * 60, 12 * 60 + 30,
      fixed: true, status: ItemStatus.booked, lat: 41.4036, lng: 2.1744);
  b.activity('Paella-Kochkurs', val, 12, 17 * 60, 20 * 60, lat: 39.474, lng: -0.379);

  b.transport('TGV Paris → Lyon', TransportMode.train, paris, lyon, 3, 11 * 60, 13 * 60,
      status: ItemStatus.booked);
  b.transport('Euromed Barcelona → Valencia', TransportMode.train, bcn, val, 11, 10 * 60 + 30, 13 * 60 + 30);
  b.transport('Rückflug Valencia → Zuhause', TransportMode.plane, val, null, 13, 15 * 60, 18 * 60,
      fixed: true, status: ItemStatus.booked);

  final pass = b.note('Interrail Pass', 'Global Pass: 7 Reisetage innerhalb 1 Monat.\nReservierungen für TGV & Euromed nötig!',
      color: 0xFFFFF59D, pinned: true);
  b.checklist('Packliste', ['Reisepass', 'Interrail-App offline', 'Adapter', 'Badesachen', 'Powerbank'],
      color: 0xFFC8E6C9, done: {0});
  final link = b.link('Interrail Reservierungen', 'https://www.interrail.eu/de/plan-your-trip/tips-and-tricks/reservations');
  b.note('Freie Tage 7–8', 'Ideen: Avignon, Montpellier oder Carcassonne?', color: 0xFFBBDEFB);
  b.connect(pass.id, link.id);

  return TripData(trip: trip, items: b.items, cards: b.cards, edges: b.edges);
}

TripData demoSriLanka() {
  final b = _B();
  final trip = Trip(
    id: b.tripId,
    title: 'Sri Lanka 2,5 Wochen',
    plannedDays: 18,
    color: 0xFF00876A,
    createdAt: b.now,
  );
  final colombo = b.stay('Colombo', 6.9271, 79.8612, 0, 1);
  final sigiriya = b.stay('Sigiriya', 7.9570, 80.7603, 1, 2);
  final kandy = b.stay('Kandy', 7.2906, 80.6337, 3, 3);
  final ella = b.stay('Ella', 6.8667, 81.0466, 6, 3);
  final mirissa = b.stay('Mirissa', 5.9483, 80.4716, 13, 4);
  b.stay('Galle', 6.0535, 80.2210, 0, 1, status: ItemStatus.idea, scheduled: false);
  b.stay('Yala Nationalpark', 6.3729, 81.5196, 0, 1, status: ItemStatus.idea, scheduled: false,
      notes: 'Safari früh morgens – liegt zwischen Ella und Mirissa');

  b.transport('Hinflug', TransportMode.plane, null, colombo, 0, 1 * 60, 9 * 60,
      fixed: true, status: ItemStatus.booked);
  b.transport('Zug Kandy → Ella', TransportMode.train, kandy, ella, 6, 8 * 60 + 45, 15 * 60 + 30);
  b.transport('Rückflug ab Colombo', TransportMode.plane, mirissa, null, 17, 21 * 60, 23 * 60 + 30,
      fixed: true, status: ItemStatus.booked);

  b.lodging('Kandy Hills Homestay', kandy, 3, 3, status: ItemStatus.option);
  b.lodging('Tree House Ella', ella, 6, 3, status: ItemStatus.option);
  b.lodging('98 Acres Resort', ella, 6, 3, status: ItemStatus.option, lat: 6.857, lng: 81.06);
  b.activity('Löwenfelsen', sigiriya, 2, 7 * 60, 11 * 60, lat: 7.9570, lng: 80.7600);
  b.activity('Zahntempel', kandy, 4, 9 * 60, 11 * 60, lat: 7.2936, lng: 80.6413);

  final train = b.note('Zug Kandy → Ella', 'Plätze 2. Klasse reservieren – rechte Seite für die Aussicht!',
      color: 0xFFFFF59D, pinned: true, itemId: kandy.id);
  b.checklist('Vorbereitung', ['ETA-Visum beantragen', 'Impfungen checken', 'Mückenschutz', 'Rupien tauschen'],
      color: 0xFFFFCCBC);
  b.link('Sri Lanka Railways Fahrplan', 'https://eservices.railway.gov.lk/schedule/searchTrain.action?lang=en');
  b.note('Grobe Idee', 'Kulturdreieck → Hochland → Süden/Strand.\nZwischen Ella und Mirissa sind noch Tage frei – Yala-Safari?',
      color: 0xFFE1BEE7);
  b.connect(train.id, kandy.id);

  return TripData(trip: trip, items: b.items, cards: b.cards, edges: b.edges);
}
