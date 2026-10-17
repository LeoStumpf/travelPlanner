import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:travel_planner/data/attachment_store.dart';
import 'package:travel_planner/data/db.dart';
import 'package:travel_planner/data/repository.dart';
import 'package:travel_planner/domain/demo.dart';
import 'package:travel_planner/domain/map_offline.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/state/offline_map.dart';
import 'package:travel_planner/state/providers.dart';
import 'package:travel_planner/ui/common/l10n.dart';
import 'package:travel_planner/ui/map/map_view.dart';
import 'package:travel_planner/ui/map/places_list.dart';

import '../l10n_test_utils.dart';
import '../offline_fake.dart';

void main() {
  late Repository repo;
  late FakeOfflineStore store;
  late ProviderContainer container;
  late bool online;
  late int probes;
  final demo = demoInterrail();

  setUpAll(() => initializeDateFormatting('de'));

  setUp(() {
    repo = Repository(AppDatabase(NativeDatabase.memory()), AttachmentStore(Directory.systemTemp));
    store = FakeOfflineStore();
    online = false;
    probes = 0;
    container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(repo),
      nativeMapProvider.overrideWithValue(false),
      offlineMapStoreProvider.overrideWithValue(store),
      mapReachabilityProvider.overrideWithValue(() async {
        probes++;
        return online;
      }),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await repo.close();
  });

  Future<void> pumpMap(WidgetTester tester) async {
    await tester.runAsync(() => repo.putTripData(demo));
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: testApp(
        home: Scaffold(
          body: Consumer(builder: (context, ref, _) {
            final data = ref.watch(tripDataProvider(demo.trip.id)).value;
            return data == null ? const Text('loading') : TripMapView(data: data, active: true);
          }),
        ),
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump();
    await tester.pump();
  }

  /// Unmounts the map so its style timer doesn't outlive the test.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  PlanItem byTitle(String t) => demo.items.firstWhere((i) => i.title == t);

  test('the place list groups lodging and activities under their stay', () {
    final rows = PlacesList.ordered(demo);
    expect(rows.where((r) => r.$1.kind == ItemKind.transport), isEmpty);
    expect(rows.length, demo.items.where((i) => i.kind != ItemKind.transport).length);
    final paris = rows.indexWhere((r) => r.$1.title == 'Paris');
    final louvre = rows.indexWhere((r) => r.$1.title == 'Louvre');
    expect(rows[paris].$2, 0);
    expect(rows[louvre].$2, 1);
    expect(louvre, greaterThan(paris));
    for (var k = paris + 1; k < louvre; k++) {
      expect(rows[k].$2, 1, reason: 'only Paris\'s children between Paris and the Louvre');
    }
  });

  testWidgets('offline without a saved map: banner and the places as a list', (tester) async {
    await pumpMap(tester);
    expect(find.byKey(const ValueKey('map-unavailable')), findsOneWidget);
    expect(find.text(de.mapUnavailableTitle), findsOneWidget);
    expect(find.text(de.mapUnavailableOffline), findsOneWidget);
    // Stays in route order with their lodging and activities below.
    expect(find.text('1. ${byTitle('Paris').title}'), findsOneWidget);
    expect(find.byKey(ValueKey('place-${byTitle('Louvre').id}')), findsOneWidget);
    // The panel covers the map buttons, so it links the offline map itself.
    expect(find.widgetWithText(TextButton, de.offlineMapTitle), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('tapping a place opens its sheet', (tester) async {
    await pumpMap(tester);
    await tester.tap(find.byKey(ValueKey('place-${byTitle('Louvre').id}')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Louvre')), findsOneWidget);
    expect(container.read(tripUiProvider).selectedId, byTitle('Louvre').id);
    await unmount(tester);
  });

  testWidgets('online but the style never loads: falls back after the timeout', (tester) async {
    online = true;
    await pumpMap(tester);
    expect(find.byKey(const ValueKey('map-unavailable')), findsNothing);
    await tester.pump(mapStyleTimeout + const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('map-unavailable')), findsOneWidget);
    expect(find.text(de.mapUnavailableFailed), findsOneWidget);

    // Try again rebuilds the map and asks the server again.
    final before = probes;
    await tester.tap(find.text(de.mapRetry));
    await tester.pump();
    await tester.pump();
    expect(probes, before + 1);
    expect(find.byKey(const ValueKey('map-unavailable')), findsNothing);
    await tester.pump(mapStyleTimeout + const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('map-unavailable')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('saving the map offline: estimate, progress, size and delete', (tester) async {
    online = true;
    await pumpMap(tester);
    final plan = planOfflineMap(demo)!;

    await tester.tap(find.byKey(const ValueKey('offline-map-button')));
    await tester.pumpAndSettle();
    expect(find.text(de.offlineMapTitle), findsOneWidget);
    expect(find.text(de.offlineMapEstimate(plan.tiles, formatBytes(plan.estimatedBytes, de.localeName))), findsOneWidget);

    store.gate = Completer();
    store.bytesPerRegion = 2 * 1024 * 1024;
    await tester.tap(find.text(de.offlineMapSave));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('offline-progress')), findsOneWidget);
    expect(find.text(de.cancel), findsOneWidget);
    expect(find.textContaining('1,0 MB'), findsOneWidget);

    store.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text(de.offlineMapSaved), findsOneWidget);
    final s = container.read(offlineMapProvider(demo.trip.id));
    expect(find.text(de.offlineMapSavedInfo(de.dateTime(s.savedAt!), formatBytes(s.bytes, de.localeName))), findsOneWidget);
    expect(find.text(de.offlineMapSaveAgain), findsOneWidget);
    expect(find.byIcon(Icons.offline_pin), findsWidgets);

    await tester.tap(find.text(de.offlineMapDelete));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, de.delete).last);
    await tester.pumpAndSettle();
    expect(store.regionsById, isEmpty);
    expect(find.text(de.offlineMapSave), findsOneWidget);

    Navigator.of(tester.element(find.text(de.offlineMapTitle))).pop();
    await tester.pumpAndSettle();
    await tester.pump(mapStyleTimeout);
    await unmount(tester);
  });

  testWidgets('offline, the sheet explains that saving needs a connection', (tester) async {
    await pumpMap(tester);
    await tester.tap(find.widgetWithText(TextButton, de.offlineMapTitle));
    await tester.pumpAndSettle();
    expect(find.text(de.offlineMapNeedsConnection), findsOneWidget);
    final save = tester.widget<ButtonStyleButton>(
      find.ancestor(of: find.text(de.offlineMapSave), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)),
    );
    expect(save.onPressed, isNull);
    await unmount(tester);
  });

  testWidgets('coming back online reloads the map by itself', (tester) async {
    await pumpMap(tester);
    expect(find.byKey(const ValueKey('map-unavailable')), findsOneWidget);
    online = true;
    // The app returns to the foreground.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('map-unavailable')), findsNothing);
    await tester.pump(mapStyleTimeout + const Duration(seconds: 1));
    await unmount(tester);
  });
}
