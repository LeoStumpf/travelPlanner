import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/data/attachment_store.dart';
import 'package:travel_planner/data/db.dart';
import 'package:travel_planner/data/geocoding.dart';
import 'package:travel_planner/data/repository.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/state/providers.dart';
import 'package:travel_planner/ui/editor/item_editor_page.dart';
import 'package:travel_planner/ui/editor/place_search.dart';

import '../l10n_test_utils.dart';

/// Answers searches with [results], or fails like an offline device.
class FakeGeocoder extends Geocoder {
  List<PlaceResult> results = const [];
  bool offline = false;
  String expanded = '';
  final queries = <String>[];
  final expands = <String>[];

  @override
  Future<List<PlaceResult>> search(String query, {String lang = 'en'}) async {
    queries.add(query);
    if (offline) throw const SocketException('offline');
    return results;
  }

  @override
  Future<String> expand(String link) async {
    expands.add(link);
    if (offline) throw const SocketException('offline');
    return expanded;
  }
}

void main() {
  late Repository repo;
  late FakeGeocoder geocoder;
  late ProviderContainer container;

  Trip trip(String id, String title) => Trip(id: id, title: title, startDate: DateTime(2026, 3, 1), createdAt: DateTime(2026));
  PlanItem item(String id, String tripId, String title, {String? place, double? lat, double? lng}) => PlanItem(
        id: id,
        tripId: tripId,
        kind: ItemKind.stay,
        title: title,
        placeName: place,
        lat: lat,
        lng: lng,
        status: ItemStatus.planned,
        start: 0,
        end: 2 * 24 * 60,
        createdAt: DateTime(2026),
      );

  setUp(() {
    repo = Repository(AppDatabase(NativeDatabase.memory()), AttachmentStore(Directory.systemTemp));
    geocoder = FakeGeocoder();
    container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(repo),
      geocoderProvider.overrideWithValue(geocoder),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await repo.close();
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pumpAndSettle();
  }

  Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
        await repo.putTripData(TripData(
          trip: trip('lk', 'Sri Lanka'),
          items: [item('kandy', 'lk', 'Kandy', place: 'Kandy, Central Province, Sri Lanka', lat: 7.2906, lng: 80.6337)],
          cards: const [],
          edges: const [],
        ));
        await repo.putTripData(TripData(
          trip: trip('it', 'Italien'),
          items: [
            item('rome', 'it', 'Rom', place: 'Rom, Latium, Italien', lat: 41.9, lng: 12.5),
            item('nowhere', 'it', 'Irgendwo'),
          ],
          cards: const [],
          edges: const [],
        ));
        await repo.putTripData(TripData(
          trip: trip('old', 'Gelöscht'),
          items: [item('oslo', 'old', 'Oslo', place: 'Oslo, Norwegen', lat: 59.9, lng: 10.7)],
          cards: const [],
          edges: const [],
        ));
        await repo.trashTrip('old');
      });

  /// Opens the place search from a button; [result] holds what it returns.
  Future<List<PlaceResult?>> open(WidgetTester tester, {String initial = ''}) async {
    final result = <PlaceResult?>[];
    await seed(tester);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: testApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result.add(await searchPlace(context, initial: initial)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await settle(tester);
    return result;
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const ValueKey('place-query')), text);
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);
  }

  testWidgets('lists recently used places of all trips, not of trashed ones', (tester) async {
    final result = await open(tester);
    expect(find.text('Zuletzt verwendet'), findsOneWidget);
    expect(find.text('Kandy'), findsOneWidget);
    expect(find.text('Central Province, Sri Lanka · Sri Lanka'), findsOneWidget);
    expect(find.text('Rom'), findsOneWidget);
    expect(find.text('Oslo'), findsNothing);
    expect(find.text('Irgendwo'), findsNothing);
    expect(find.textContaining('Tipp:'), findsOneWidget);

    await tester.tap(find.text('Kandy'));
    await settle(tester);
    expect(result.single!.label, 'Kandy, Central Province, Sri Lanka');
    expect(result.single!.lat, 7.2906);
    expect(geocoder.queries, isEmpty);
  });

  testWidgets('shows "Keine Treffer" and offers to save without coordinates', (tester) async {
    final result = await open(tester);
    await type(tester, 'Xyzzyville');
    expect(geocoder.queries, ['Xyzzyville']);
    expect(find.byKey(const ValueKey('place-no-results')), findsOneWidget);
    expect(find.text('Keine Treffer für „Xyzzyville“'), findsOneWidget);

    await tester.tap(find.text('„Xyzzyville“ ohne Koordinaten speichern'));
    await settle(tester);
    expect(result.single!.name, 'Xyzzyville');
    expect(result.single!.hasLocation, isFalse);
  });

  testWidgets('online results come without the empty state', (tester) async {
    geocoder.results = const [PlaceResult('Galle', 'Sri Lanka', 6.03, 80.22)];
    final result = await open(tester);
    await type(tester, 'Galle');
    expect(find.widgetWithText(ListTile, 'Galle'), findsOneWidget);
    expect(find.byKey(const ValueKey('place-no-results')), findsNothing);
    await tester.tap(find.widgetWithText(ListTile, 'Galle'));
    await settle(tester);
    expect(result.single!.label, 'Galle, Sri Lanka');
  });

  testWidgets('offline: explains it and still offers matching recent places', (tester) async {
    geocoder.offline = true;
    await open(tester);
    await type(tester, 'kan');
    expect(find.text('Suche nicht möglich (offline?)'), findsOneWidget);
    expect(find.byKey(const ValueKey('place-no-results')), findsNothing);
    expect(find.text('Kandy'), findsOneWidget);
    expect(find.text('Rom'), findsNothing);
    expect(find.byKey(const ValueKey('place-without-coordinates')), findsOneWidget);
  });

  testWidgets('a pasted Google Maps link gives the place without searching', (tester) async {
    geocoder.offline = true;
    final result = await open(tester);
    await type(tester, 'https://www.google.com/maps/place/Sigiriya/@7.95,80.75,15z/data=!3d7.9570!4d80.7603');
    expect(find.text('Sigiriya'), findsOneWidget);
    expect(find.text('Aus dem Link · 7.95700, 80.76030'), findsOneWidget);
    expect(find.byKey(const ValueKey('place-without-coordinates')), findsNothing);
    expect(find.text('Zuletzt verwendet'), findsNothing);
    expect(geocoder.queries, isEmpty);

    await tester.tap(find.byKey(const ValueKey('place-from-input')));
    await settle(tester);
    expect(result.single!.name, 'Sigiriya');
    expect((result.single!.lat, result.single!.lng), (7.9570, 80.7603));
  });

  testWidgets('typed coordinates are offered as they are', (tester) async {
    final result = await open(tester);
    await type(tester, '48.8584, 2.2945');
    expect(find.text('Diese Koordinaten übernehmen'), findsOneWidget);
    expect(geocoder.queries, isEmpty);
    await tester.tap(find.byKey(const ValueKey('place-from-input')));
    await settle(tester);
    expect(result.single!.lat, 48.8584);
    expect(result.single!.lng, 2.2945);
  });

  testWidgets('a map link without coordinates says so', (tester) async {
    await open(tester);
    await type(tester, 'https://www.openstreetmap.org/node/123');
    expect(find.text('Der Link enthält keine Koordinaten'), findsOneWidget);
  });

  testWidgets('short links are expanded online and explained offline', (tester) async {
    geocoder.offline = true;
    await open(tester);
    await type(tester, 'https://maps.app.goo.gl/abc');
    expect(find.text('Kurzlinks brauchen eine Verbindung'), findsOneWidget);

    geocoder.offline = false;
    geocoder.expanded = 'https://www.google.com/maps/place/Ella/@6.8667,81.0466,14z';
    await type(tester, 'https://maps.app.goo.gl/abcd');
    expect(geocoder.expands, ['https://maps.app.goo.gl/abc', 'https://maps.app.goo.gl/abcd']);
    expect(find.text('Ella'), findsOneWidget);
    expect(find.byKey(const ValueKey('place-from-input')), findsOneWidget);
  });

  testWidgets('a link naming a place only searches for that name', (tester) async {
    geocoder.results = const [PlaceResult('Temple of the Tooth', 'Kandy', 7.29, 80.64)];
    await open(tester);
    await type(tester, 'https://maps.google.com/?q=Temple+of+the+Tooth');
    expect(geocoder.queries, ['Temple of the Tooth']);
    expect(find.text('Temple of the Tooth'), findsOneWidget);
  });

  testWidgets('the editor keeps a place saved without coordinates', (tester) async {
    final data = TripData(trip: trip('x', 'X'), items: const [], cards: const [], edges: const []);
    await tester.runAsync(() => repo.putTripData(data));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: testApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openItemEditor(context, data, newKind: ItemKind.stay),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('place-tile')));
    await settle(tester);
    await type(tester, 'Hütte am See');
    await tester.tap(find.byKey(const ValueKey('place-without-coordinates')));
    await settle(tester);

    expect(find.text('Hütte am See'), findsWidgets);
    expect(find.text('Ohne Koordinaten – nicht auf der Karte'), findsOneWidget);
    // Clearing removes the name, too.
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('place-tile')), matching: find.byIcon(Icons.clear)));
    await tester.pump();
    expect(find.text('Ort auf der Karte festlegen'), findsOneWidget);
  });
}
