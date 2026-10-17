// In-memory stand-in for MapLibre's offline database.
import 'dart:async';

import 'package:travel_planner/data/offline_maps.dart';
import 'package:travel_planner/domain/map_offline.dart';

class FakeOfflineStore implements OfflineMapStore {
  final regionsById = <int, StoredRegion>{};
  final bytesById = <int, int>{};
  final complete = <int>{};
  final downloaded = <RegionSpec>[];
  var _nextId = 1;

  /// Bytes each finished region stores.
  int bytesPerRegion = 1000;

  /// When set, downloads wait for it after reporting half progress.
  Completer<void>? gate;

  /// Fails the download of the n-th region (1-based) with this message.
  int? failAt;
  final _running = <int, Completer<int>>{};

  /// Throws like the missing plugin in tests.
  bool broken = false;

  @override
  Future<List<StoredRegion>> regions() async {
    if (broken) throw StateError('no plugin');
    return regionsById.values.toList();
  }

  @override
  Future<({int bytes, bool complete})> status(int id) async =>
      (bytes: bytesById[id] ?? 0, complete: complete.contains(id));

  @override
  Future<int> download(
    RegionSpec spec,
    String styleUrl,
    Map<String, dynamic> metadata, {
    required RegionProgress onProgress,
    void Function(int id)? onCreated,
  }) async {
    final id = _nextId++;
    regionsById[id] = StoredRegion(id, metadata);
    downloaded.add(spec);
    onCreated?.call(id);
    final done = Completer<int>();
    _running[id] = done;
    () async {
      onProgress(0.5, bytesPerRegion ~/ 2);
      if (gate != null) await gate!.future;
      if (done.isCompleted) return;
      if (failAt == downloaded.length) {
        done.completeError(const OfflineDownloadFailed('tile server said no'));
        return;
      }
      bytesById[id] = bytesPerRegion;
      complete.add(id);
      onProgress(1, bytesPerRegion);
      done.complete(id);
    }();
    try {
      return await done.future;
    } finally {
      _running.remove(id);
    }
  }

  @override
  Future<void> delete(int id) async {
    regionsById.remove(id);
    bytesById.remove(id);
    complete.remove(id);
    final r = _running.remove(id);
    if (r != null && !r.isCompleted) r.completeError(const OfflineDownloadCancelled());
  }
}
