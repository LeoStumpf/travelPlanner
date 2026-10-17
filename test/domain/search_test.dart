import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/domain/search.dart';

final _t0 = DateTime(2026, 1, 1);

TripData _trip(String id, String title, {List<PlanItem> items = const [], List<NoteCard> cards = const [],
        List<Attachment> attachments = const [], int age = 0}) =>
    TripData(
      trip: Trip(id: id, title: title, createdAt: _t0.add(Duration(days: age))),
      items: items,
      cards: cards,
      attachments: attachments,
    );

PlanItem _item(String id, String trip, String title,
        {ItemKind kind = ItemKind.activity, String? place, String notes = '', List<String> links = const [],
        String? bookingRef, String? station, String? number, int? start}) =>
    PlanItem(
      id: id,
      tripId: trip,
      kind: kind,
      title: title,
      placeName: place,
      notes: notes,
      links: links,
      bookingRef: bookingRef,
      departureStation: station,
      transportNumber: number,
      start: start,
      end: start == null ? null : start + 60,
      createdAt: _t0,
    );

NoteCard _card(String id, String trip,
        {CardType type = CardType.note, String title = '', String text = '', String? url, List<String> entries = const []}) =>
    NoteCard(
      id: id,
      tripId: trip,
      type: type,
      title: title,
      text: text,
      url: url,
      checklist: [for (final (k, e) in entries.indexed) ChecklistEntry(id: '$id-$k', text: e)],
      createdAt: _t0,
    );

void main() {
  group('folding and terms', () {
    test('lower case without accents, same length', () {
      expect(foldForSearch('Café Größe ÅRHUS'), 'cafe große arhus');
      expect(foldForSearch('Café').length, 'Café'.length);
    });

    test('query words are folded and split on whitespace', () {
      expect(searchTerms('  Tuk-Tuk   Kändy '), ['tuk-tuk', 'kandy']);
      expect(searchTerms('   '), isEmpty);
    });

    test('match ranges point into the original text and merge overlaps', () {
      expect(matchRanges('Café Central', ['cafe']), [(0, 4)]);
      expect(matchRanges('banana', ['an', 'nan']), [(1, 5)]);
      expect(matchRanges('Zug nach Zürich', ['zu']), [(0, 2), (9, 11)]);
      expect(matchRanges('nothing', ['x']), isEmpty);
    });

    test('snippets cut long text before the match at a word boundary', () {
      const text = 'Wir treffen uns morgens am Eingang, danach geht es mit dem Bus zum Tempel der Zahnreliquie.';
      final s = searchSnippet(text, ['tempel']);
      expect(s, startsWith('…'));
      expect(s, contains('Tempel der Zahnreliquie.'));
      expect(s.indexOf('Tempel'), lessThanOrEqualTo(26));
      expect(searchSnippet('Line one\nline two', ['two']), 'Line one line two');
    });
  });

  group('searchTrip', () {
    final data = _trip('a', 'Sri Lanka', items: [
      _item('kandy', 'a', 'Kandy', kind: ItemKind.stay, place: 'Kandy, Sri Lanka', start: 2000),
      _item('temple', 'a', 'Temple of the Tooth', place: 'Kandy', notes: 'Cover shoulders and knees', start: 2500),
      _item('train', 'a', 'Train to Ella',
          kind: ItemKind.transport, bookingRef: 'PNR X7Q2', station: 'Kandy Station', number: 'IC 1009', start: 3000),
      _item('cafe', 'a', 'Café Chill', links: ['https://cafechill.lk/menu']),
    ], cards: [
      _card('pack', 'a', type: CardType.checklist, title: 'Packing', entries: ['Sunscreen', 'Power adapter']),
      _card('link', 'a', type: CardType.link, url: 'https://example.com/ella-rock'),
      _card('img', 'a', type: CardType.image),
    ], attachments: [
      Attachment(
          id: 'f1', tripId: 'a', ownerId: 'train', fileName: 'ticket-ella.pdf', relPath: 'x', mime: 'application/pdf', createdAt: _t0),
    ]);

    List<String> ids(String q) => [for (final h in searchTrip(data, q)) h.id];

    test('finds titles, places, notes, links, ticket details, checklists, urls and files', () {
      expect(ids('tooth'), ['temple']);
      expect(searchTrip(data, 'shoulders').single.field, SearchField.notes);
      expect(searchTrip(data, 'menu').single.field, SearchField.link);
      expect(searchTrip(data, 'x7q2').single.field, SearchField.bookingRef);
      expect(searchTrip(data, 'IC 1009').single.field, SearchField.transportNumber);
      final entry = searchTrip(data, 'adapter').single;
      expect((entry.id, entry.field, entry.text), ('pack', SearchField.checklistEntry, 'Power adapter'));
      expect(searchTrip(data, 'ella-rock').single.id, 'link');
      expect(searchTrip(data, 'ticket-ella').single.field, SearchField.attachment);
    });

    test('is case and accent insensitive', () {
      expect(ids('CAFE'), ['cafe']);
      expect(ids('café'), ['cafe']);
    });

    test('every word must match, but not in the same field', () {
      expect(ids('temple knees'), ['temple']);
      expect(ids('temple ella'), isEmpty);
    });

    test('title matches rank first, then items in plan order, then cards', () {
      // "Kandy": the stay by title, temple by place, train by station.
      expect(ids('kandy'), ['kandy', 'temple', 'train']);
      expect(ids('ella'), ['train', 'link']);
      final first = searchTrip(data, 'kandy').first;
      expect(first.field, SearchField.title);
    });

    test('equal hits keep their stored order, also in long result lists', () {
      // Above 32 elements List.sort is a quicksort and would shuffle ties.
      final many = _trip('m', 'Many', items: [
        for (var k = 0; k < 40; k++) _item('i$k', 'm', 'Spot $k', notes: 'beach'),
      ], cards: [
        for (var k = 0; k < 40; k++) _card('c$k', 'm', title: 'Card $k', text: 'beach'),
      ]);
      expect([for (final h in searchTrip(many, 'beach')) h.id],
          [for (var k = 0; k < 40; k++) 'i$k', for (var k = 0; k < 40; k++) 'c$k']);
    });

    test('shows the field with the most query words', () {
      final h = searchTrip(data, 'kandy station').single;
      expect(h.id, 'train');
      expect(h.field, SearchField.departureStation);
      expect(h.text, 'Kandy Station');
    });

    test('empty query finds nothing', () {
      expect(searchTrip(data, ' '), isEmpty);
    });

    test('untitled cards are named after their content', () {
      expect(cardTitle(_card('x', 'a', url: 'https://a.b')), 'https://a.b');
      expect(cardTitle(_card('x', 'a', text: '\nFirst line\nsecond')), 'First line');
      expect(cardTitle(_card('x', 'a', entries: ['', 'Milk'])), 'Milk');
      expect(cardTitle(_card('x', 'a')), '');
    });

    test('cardMatches backs the notes grid search', () {
      final c = _card('x', 'a', title: 'Restaurants', text: 'Ministry of Crab');
      expect(cardMatches(c, searchTerms('crab ministry')), isTrue);
      expect(cardMatches(c, searchTerms('crab pizza')), isFalse);
      expect(cardMatches(c, const []), isTrue);
    });
  });

  group('searchTrips', () {
    final older = _trip('old', 'Interrail', items: [_item('z', 'old', 'Zürich HB', place: 'Zürich')], age: 0);
    final newer = _trip('new', 'Sri Lanka', items: [_item('k', 'new', 'Kandy')], cards: [_card('n', 'new', text: 'Zürich stopover?')], age: 5);
    final none = _trip('none', 'Zurich weekend', age: 3);

    test('groups hits by trip in the given order', () {
      final r = searchTrips([newer, none, older], 'zurich');
      expect([for (final g in r) g.trip.id], ['new', 'none', 'old']);
      expect([for (final h in r.first.hits) h.id], ['n']);
      expect(r[1].titleMatches, isTrue);
      expect(r[1].hits, isEmpty);
      expect(r[2].titleMatches, isFalse);
    });

    test('moves the open trip to the front', () {
      final r = searchTrips([newer, none, older], 'zurich', firstTripId: 'old');
      expect([for (final g in r) g.trip.id], ['old', 'new', 'none']);
    });

    test('leaves out trips without hits', () {
      expect([for (final g in searchTrips([newer, none, older], 'kandy')) g.trip.id], ['new']);
      expect(searchTrips([newer, older], 'nothing here'), isEmpty);
      expect(searchTrips([newer, older], ''), isEmpty);
    });
  });
}
