import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/data/offline_maps.dart';
import 'package:travel_planner/domain/demo.dart';
import 'package:travel_planner/domain/map_offline.dart';
import 'package:travel_planner/state/offline_map.dart';

import '../offline_fake.dart';

void main() {
  late FakeOfflineStore store;
  late ProviderContainer container;
  final data = demoInterrail();
  final plan = planOfflineMap(data)!;
  final tripId = data.trip.id;
  final now = DateTime(2026, 10, 17, 9, 30);

  setUp(() {
    store = FakeOfflineStore();
    container = ProviderContainer(overrides: [offlineMapStoreProvider.overrideWithValue(store)]);
  });
  tearDown(() => container.dispose());

  OfflineMapState state() => container.read(offlineMapProvider(tripId));
  OfflineMapNotifier notifier() => container.read(offlineMapProvider(tripId).notifier);

  Future<void> loaded() async {
    state();
    await pumpEventQueue();
  }

  test('nothing saved at first; a missing plugin counts as nothing', () async {
    await loaded();
    expect(state().loaded, isTrue);
    expect(state().saved, isFalse);

    store.broken = true;
    await notifier().refresh();
    expect(state().loaded, isTrue);
    expect(state().regionIds, isEmpty);
  });

  test('save downloads every region with metadata and reports progress', () async {
    await loaded();
    store.gate = Completer();
    final progress = <double>[];
    container.listen(offlineMapProvider(tripId), (_, s) {
      if (s.progress != null) progress.add(s.progress!);
    });
    final saving = notifier().save(plan, now: now);
    await pumpEventQueue();
    expect(state().downloading, isTrue);
    expect(state().progress, greaterThan(0));
    expect(state().downloadedBytes, 500);
    store.gate!.complete();
    await saving;

    expect(store.downloaded.map((r) => r.toString()), plan.regions.map((r) => r.toString()));
    final meta = store.regionsById.values.first.metadata;
    expect(meta['app'], offlineMetadataApp);
    expect(meta['tripId'], tripId);
    expect(meta['part'], 'overview');
    expect(meta['savedAt'], now.toIso8601String());
    expect(meta['box'], plan.box.toList());

    final s = state();
    expect(s.downloading, isFalse);
    expect(s.saved, isTrue);
    expect(s.regionIds, hasLength(plan.regions.length));
    expect(s.bytes, 1000 * plan.regions.length);
    expect(s.savedAt, now);
    expect(s.box, plan.box);
    expect(s.covers(placesBox(data)), isTrue);
    expect(s.covers(const GeoBox(10, 10, 11, 11)), isFalse);
    expect(progress, isNotEmpty);
    expect(progress.last, closeTo(1, 1e-9));
    for (var k = 1; k < progress.length; k++) {
      expect(progress[k], greaterThanOrEqualTo(progress[k - 1]));
    }
  });

  test('saving again replaces the old regions; other trips stay', () async {
    store.regionsById[99] = const StoredRegion(99, {'app': offlineMetadataApp, 'tripId': 'other'});
    store.complete.add(99);
    await loaded();
    await notifier().save(plan, now: now);
    final first = {...state().regionIds};
    await notifier().save(plan, now: now);
    expect(state().regionIds, hasLength(plan.regions.length));
    expect(state().regionIds.toSet().intersection(first), isEmpty);
    expect(store.regionsById.keys, contains(99));
    expect(state().regionIds, isNot(contains(99)));
  });

  test('a failed download cleans up and keeps the message', () async {
    await loaded();
    store.failAt = 2;
    await notifier().save(plan, now: now);
    expect(state().downloading, isFalse);
    expect(state().error, 'tile server said no');
    expect(state().regionIds, isEmpty);
    expect(store.regionsById, isEmpty);

    // The next attempt clears the error.
    store.failAt = null;
    await notifier().save(plan, now: now);
    expect(state().error, isNull);
    expect(state().saved, isTrue);
  });

  test('cancel stops the download and removes what was saved so far', () async {
    await loaded();
    store.gate = Completer();
    final saving = notifier().save(plan, now: now);
    await pumpEventQueue();
    await notifier().cancel();
    await saving;
    expect(state().downloading, isFalse);
    expect(state().error, isNull);
    expect(state().regionIds, isEmpty);
    expect(store.regionsById, isEmpty);
    expect(store.downloaded, hasLength(1));
  });

  test('a failed or cancelled re-save keeps the old map', () async {
    await loaded();
    await notifier().save(plan, now: now);
    final first = [...state().regionIds];

    store.failAt = store.downloaded.length + 2;
    await notifier().save(plan, now: DateTime(2026, 10, 18));
    expect(state().error, 'tile server said no');
    expect(state().saved, isTrue);
    expect(state().regionIds, first);
    expect(state().savedAt, now);

    store.failAt = null;
    store.gate = Completer();
    final saving = notifier().save(plan, now: DateTime(2026, 10, 18));
    await pumpEventQueue();
    await notifier().cancel();
    await saving;
    expect(state().saved, isTrue);
    expect(state().regionIds, first);
    expect(store.regionsById.keys.toSet(), first.toSet());
  });

  test('delete removes the trip\'s regions', () async {
    await loaded();
    await notifier().save(plan, now: now);
    await notifier().delete();
    expect(state().saved, isFalse);
    expect(state().regionIds, isEmpty);
    expect(store.regionsById, isEmpty);
  });

  test('an unfinished region shows as stored but not saved', () async {
    store.regionsById[5] = StoredRegion(5, {'app': offlineMetadataApp, 'tripId': tripId});
    await loaded();
    expect(state().regionIds, [5]);
    expect(state().saved, isFalse);
  });
}
