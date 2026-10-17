import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:travel_planner/data/attachment_store.dart';
import 'package:travel_planner/data/db.dart';
import 'package:travel_planner/data/location.dart';
import 'package:travel_planner/data/repository.dart';
import 'package:travel_planner/domain/demo.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/state/offline_map.dart';
import 'package:travel_planner/state/providers.dart';
import 'package:travel_planner/ui/common/item_sheet.dart';
import 'package:travel_planner/ui/common/navigation.dart';
import 'package:travel_planner/ui/map/map_view.dart';

import '../l10n_test_utils.dart';
import '../offline_fake.dart';

/// Answers [locate] with [result] and counts what the map asks for.
class FakeLocation implements LocationSource {
  LocateResult result = const LocateResult.at(48.85, 2.35);
  int locates = 0, appSettings = 0, locationSettings = 0;
  final updates = StreamController<(double, double)>.broadcast();

  /// When set, [locate] waits for it (a slow fix).
  Completer<LocateResult>? pending;

  @override
  Future<LocateResult> locate() async {
    locates++;
    return pending?.future ?? result;
  }

  @override
  Stream<(double, double)> watch() => updates.stream;

  @override
  Future<void> openAppSettings() async => appSettings++;

  @override
  Future<void> openLocationSettings() async => locationSettings++;
}

void main() {
  late Repository repo;
  late FakeLocation location;
  late ProviderContainer container;
  late List<Uri> launched;
  late Set<String> handledSchemes;
  final demo = demoInterrail();
  final idea = PlanItem(
    id: 'idea',
    tripId: demo.trip.id,
    kind: ItemKind.activity,
    title: 'Somewhere nice',
    status: ItemStatus.idea,
    createdAt: DateTime(2026),
  );
  final data = TripData(trip: demo.trip, items: [...demo.items, idea], cards: demo.cards, edges: demo.edges);

  setUpAll(() => initializeDateFormatting('de'));

  setUp(() {
    repo = Repository(AppDatabase(NativeDatabase.memory()), AttachmentStore(Directory.systemTemp));
    location = FakeLocation();
    launched = [];
    handledSchemes = {'geo', 'https'};
    container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(repo),
      nativeMapProvider.overrideWithValue(false),
      offlineMapStoreProvider.overrideWithValue(FakeOfflineStore()),
      mapReachabilityProvider.overrideWithValue(() async => true),
      locationSourceProvider.overrideWithValue(location),
      externalLauncherProvider.overrideWithValue((uri) async {
        launched.add(uri);
        return handledSchemes.contains(uri.scheme);
      }),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await location.updates.close();
    await repo.close();
  });

  PlanItem byTitle(String t) => data.items.firstWhere((i) => i.title == t);

  /// The map (or, with [sheetFor], a button opening that item's sheet).
  Future<void> pump(WidgetTester tester, {bool active = true, String? sheetFor}) async {
    await tester.runAsync(() => repo.putTripData(data));
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: testApp(
        home: Scaffold(
          body: Consumer(builder: (context, ref, _) {
            final d = ref.watch(tripDataProvider(data.trip.id)).value;
            if (d == null) return const Text('loading');
            if (sheetFor != null) {
              return TextButton(
                onPressed: () => showItemSheet(context, ref, d.trip.id, sheetFor),
                child: const Text('open'),
              );
            }
            return TripMapView(data: d, active: active);
          }),
        ),
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump();
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) => tester.pumpWidget(const SizedBox());

  Future<void> tapMyLocation(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('my-location-button')));
    await tester.pump();
    await tester.pump();
    // Lets a snackbar slide in.
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('my location', () {
    testWidgets('shows the position and follows it while the map is showing', (tester) async {
      await pump(tester);
      expect(find.byTooltip(de.myLocation), findsOneWidget);
      expect(find.byIcon(Icons.location_searching), findsOneWidget);
      await tapMyLocation(tester);
      expect(location.locates, 1);
      expect(find.byIcon(Icons.my_location), findsOneWidget);
      expect(location.updates.hasListener, isTrue);
      expect(find.byType(SnackBar), findsNothing);

      // Another view: no more updates; back on the map: following again.
      await pump(tester, active: false);
      expect(location.updates.hasListener, isFalse);
      await pump(tester);
      expect(location.updates.hasListener, isTrue);
      await unmount(tester);
      expect(location.updates.hasListener, isFalse);
    });

    testWidgets('stops following while the app is in the background', (tester) async {
      await pump(tester);
      await tapMyLocation(tester);
      expect(location.updates.hasListener, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(location.updates.hasListener, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(location.updates.hasListener, isTrue);
      await unmount(tester);
    });

    testWidgets('a fix arriving after switching views does not start following', (tester) async {
      final pending = Completer<LocateResult>();
      location.pending = pending;
      await pump(tester);
      await tapMyLocation(tester);
      await pump(tester, active: false);
      pending.complete(const LocateResult.at(48.85, 2.35));
      await tester.pump();
      await tester.pump();
      expect(location.updates.hasListener, isFalse);
      await unmount(tester);
    });

    testWidgets('location switched off: says so and links the system settings', (tester) async {
      location.result = const LocateResult.failed(LocateFailure.serviceDisabled);
      await pump(tester);
      await tapMyLocation(tester);
      expect(find.text(de.locationServiceOff), findsOneWidget);
      await tester.tap(find.widgetWithText(SnackBarAction, de.locationSettings));
      await tester.pump();
      expect(location.locationSettings, 1);
      expect(location.appSettings, 0);
      expect(find.byIcon(Icons.location_searching), findsOneWidget);
      expect(location.updates.hasListener, isFalse);
      await unmount(tester);
    });

    testWidgets('permission declined: explains, and asks again on the next tap', (tester) async {
      location.result = const LocateResult.failed(LocateFailure.denied);
      await pump(tester);
      await tapMyLocation(tester);
      expect(find.text(de.locationDenied), findsOneWidget);
      expect(find.byType(SnackBarAction), findsNothing);
      location.result = const LocateResult.at(52.52, 13.4);
      await tapMyLocation(tester);
      expect(location.locates, 2);
      expect(find.byIcon(Icons.my_location), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('permission blocked for good: links the app settings', (tester) async {
      location.result = const LocateResult.failed(LocateFailure.deniedForever);
      await pump(tester);
      await tapMyLocation(tester);
      expect(find.text(de.locationDeniedForever), findsOneWidget);
      await tester.tap(find.widgetWithText(SnackBarAction, de.locationSettings));
      await tester.pump();
      expect(location.appSettings, 1);
      await unmount(tester);
    });

    testWidgets('no fix: says the position is unavailable', (tester) async {
      location.result = const LocateResult.failed(LocateFailure.unavailable);
      await pump(tester);
      await tapMyLocation(tester);
      expect(find.text(de.locationUnavailable), findsOneWidget);
      await unmount(tester);
    });
  });

  group('navigation', () {
    Future<void> openSheet(WidgetTester tester, String id) async {
      await pump(tester, sheetFor: id);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('the item sheet hands the place to a maps app', (tester) async {
      final louvre = byTitle('Louvre');
      await openSheet(tester, louvre.id);
      final button = find.byKey(const ValueKey('item-navigation'));
      await tester.scrollUntilVisible(button, 100, scrollable: find.byType(Scrollable).last);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      expect(find.descendant(of: button, matching: find.text(de.navigation)), findsOneWidget);
      await tester.tap(button);
      await tester.pump();
      expect(launched, [Uri.parse('geo:${louvre.lat},${louvre.lng}?q=${louvre.lat},${louvre.lng}(Louvre)')]);
    });

    testWidgets('without a maps app it falls back to Google Maps, then gives up', (tester) async {
      await openSheet(tester, byTitle('Louvre').id);
      final button = find.byKey(const ValueKey('item-navigation'));
      await tester.scrollUntilVisible(button, 100, scrollable: find.byType(Scrollable).last);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      handledSchemes = {'https'};
      await tester.tap(button);
      await tester.pump();
      expect(launched.map((u) => u.scheme), ['geo', 'https']);
      expect(launched.last.host, 'www.google.com');

      launched.clear();
      handledSchemes = {};
      await tester.tap(button);
      await tester.pump();
      expect(launched, hasLength(2));
      expect(find.text(de.noNavigationApp), findsOneWidget);
    });

    testWidgets('no navigation for an item without any place', (tester) async {
      await openSheet(tester, idea.id);
      expect(find.text(idea.title), findsWidgets);
      // The view buttons next to it are there, navigation isn't.
      await tester.scrollUntilVisible(find.text(de.edit), 100, scrollable: find.byType(Scrollable).last);
      expect(find.byKey(const ValueKey('item-navigation')), findsNothing);
    });
  });
}
