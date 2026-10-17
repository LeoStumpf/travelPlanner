// Example trips that show off the planner's concepts. The texts come from
// [DemoTexts], so the UI can pass them in the user's language; names of
// places, hotels and sights stay as they are.
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

/// The translatable texts of the demo trips. Defaults are English.
class DemoTexts {
  final String interrailTitle;
  final String avignonNotes;
  final String sagradaFamilia;
  final String paellaCourse;
  final String flightHomeValencia;
  final String passTitle;
  final String passText;
  final String packingList;
  final List<String> packingItems;
  final String reservationsLink;
  final String freeDaysTitle;
  final String freeDaysText;
  final String sriLankaTitle;
  final String yalaName;
  final String yalaNotes;
  final String flightOut;
  final String trainKandyElla;
  final String flightHomeColombo;
  final String lionRock;
  final String toothTemple;
  final String trainNote;
  final String preparation;
  final List<String> preparationItems;
  final String railwayTimetable;
  final String roughIdea;
  final String roughIdeaText;

  const DemoTexts({
    this.interrailTitle = 'Interrail France & Spain',
    this.avignonNotes = 'Might fit into the free days between Lyon and Barcelona',
    this.sagradaFamilia = 'Sagrada Família (booked)',
    this.paellaCourse = 'Paella cooking class',
    this.flightHomeValencia = 'Flight home Valencia → Home',
    this.passTitle = 'Interrail Pass',
    this.passText = 'Global Pass: 7 travel days within 1 month.\nReservations needed for TGV & Euromed!',
    this.packingList = 'Packing list',
    this.packingItems = const ['Passport', 'Interrail app offline', 'Adapter', 'Swimwear', 'Power bank'],
    this.reservationsLink = 'Interrail reservations',
    this.freeDaysTitle = 'Free days 7–8',
    this.freeDaysText = 'Ideas: Avignon, Montpellier or Carcassonne?',
    this.sriLankaTitle = 'Sri Lanka 2.5 weeks',
    this.yalaName = 'Yala National Park',
    this.yalaNotes = 'Safari early in the morning – between Ella and Mirissa',
    this.flightOut = 'Flight out',
    this.trainKandyElla = 'Train Kandy → Ella',
    this.flightHomeColombo = 'Flight home from Colombo',
    this.lionRock = 'Lion Rock',
    this.toothTemple = 'Temple of the Tooth',
    this.trainNote = 'Reserve 2nd class seats – right side for the view!',
    this.preparation = 'Preparation',
    this.preparationItems = const ['Apply for ETA visa', 'Check vaccinations', 'Mosquito repellent', 'Exchange rupees'],
    this.railwayTimetable = 'Sri Lanka Railways timetable',
    this.roughIdea = 'Rough idea',
    this.roughIdeaText =
        'Cultural triangle → highlands → south/beach.\nThere are free days between Ella and Mirissa – Yala safari?',
  });
}

TripData demoInterrail([DemoTexts t = const DemoTexts()]) {
  final b = _B();
  final trip = Trip(
    id: b.tripId,
    title: t.interrailTitle,
    plannedDays: 14,
    color: 0xFF1F5FD1,
    createdAt: b.now,
  );
  final paris = b.stay('Paris', 48.8566, 2.3522, 0, 3);
  final lyon = b.stay('Lyon', 45.7640, 4.8357, 3, 2);
  final bcn = b.stay('Barcelona', 41.3874, 2.1686, 8, 3);
  final val = b.stay('Valencia', 39.4699, -0.3763, 11, 2);
  b.stay('Avignon', 43.9493, 4.8055, 0, 1, status: ItemStatus.idea, scheduled: false,
      notes: t.avignonNotes);

  b.lodging('Hôtel du Marais', paris, 0, 3, status: ItemStatus.booked);
  b.lodging('Airbnb Croix-Rousse', lyon, 3, 2, status: ItemStatus.option);
  b.lodging('Auberge Vieux Lyon', lyon, 3, 2, status: ItemStatus.option, lat: 45.762, lng: 4.827);
  b.lodging('Hostel Gràcia', bcn, 8, 3);

  b.activity('Louvre', paris, 1, 10 * 60, 14 * 60, lat: 48.8606, lng: 2.3376);
  b.activity(t.sagradaFamilia, bcn, 9, 11 * 60, 12 * 60 + 30,
      fixed: true, status: ItemStatus.booked, lat: 41.4036, lng: 2.1744);
  b.activity(t.paellaCourse, val, 12, 17 * 60, 20 * 60, lat: 39.474, lng: -0.379);

  b.transport('TGV Paris → Lyon', TransportMode.train, paris, lyon, 3, 11 * 60, 13 * 60,
      status: ItemStatus.booked);
  b.transport('Euromed Barcelona → Valencia', TransportMode.train, bcn, val, 11, 10 * 60 + 30, 13 * 60 + 30);
  b.transport(t.flightHomeValencia, TransportMode.plane, val, null, 13, 15 * 60, 18 * 60,
      fixed: true, status: ItemStatus.booked);

  final pass = b.note(t.passTitle, t.passText,
      color: 0xFFFFF59D, pinned: true);
  b.checklist(t.packingList, t.packingItems,
      color: 0xFFC8E6C9, done: {0});
  final link = b.link(t.reservationsLink, 'https://www.interrail.eu/en/plan-your-trip/tips-and-tricks/reservations');
  b.note(t.freeDaysTitle, t.freeDaysText, color: 0xFFBBDEFB);
  b.connect(pass.id, link.id);

  return TripData(trip: trip, items: b.items, cards: b.cards, edges: b.edges);
}

TripData demoSriLanka([DemoTexts t = const DemoTexts()]) {
  final b = _B();
  final trip = Trip(
    id: b.tripId,
    title: t.sriLankaTitle,
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
  b.stay(t.yalaName, 6.3729, 81.5196, 0, 1, status: ItemStatus.idea, scheduled: false, notes: t.yalaNotes);

  b.transport(t.flightOut, TransportMode.plane, null, colombo, 0, 1 * 60, 9 * 60,
      fixed: true, status: ItemStatus.booked);
  b.transport(t.trainKandyElla, TransportMode.train, kandy, ella, 6, 8 * 60 + 45, 15 * 60 + 30);
  b.transport(t.flightHomeColombo, TransportMode.plane, mirissa, null, 17, 21 * 60, 23 * 60 + 30,
      fixed: true, status: ItemStatus.booked);

  b.lodging('Kandy Hills Homestay', kandy, 3, 3, status: ItemStatus.option);
  b.lodging('Tree House Ella', ella, 6, 3, status: ItemStatus.option);
  b.lodging('98 Acres Resort', ella, 6, 3, status: ItemStatus.option, lat: 6.857, lng: 81.06);
  b.activity(t.lionRock, sigiriya, 2, 7 * 60, 11 * 60, lat: 7.9570, lng: 80.7600);
  b.activity(t.toothTemple, kandy, 4, 9 * 60, 11 * 60, lat: 7.2936, lng: 80.6413);

  final train = b.note(t.trainKandyElla, t.trainNote,
      color: 0xFFFFF59D, pinned: true, itemId: kandy.id);
  b.checklist(t.preparation, t.preparationItems,
      color: 0xFFFFCCBC);
  b.link(t.railwayTimetable, 'https://eservices.railway.gov.lk/schedule/searchTrain.action?lang=en');
  b.note(t.roughIdea, t.roughIdeaText,
      color: 0xFFE1BEE7);
  b.connect(train.id, kandy.id);

  return TripData(trip: trip, items: b.items, cards: b.cards, edges: b.edges);
}
