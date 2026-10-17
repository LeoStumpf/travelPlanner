// Offline map regions through MapLibre's offline manager, behind a small
// interface so the state and the UI can be tested without the plugin.
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../domain/map_offline.dart';

/// OpenStreetMap-based vector style, free and without API key.
const mapStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';

/// Whether the map server answers: the plugin reports no style or tile load
/// errors, so the map view asks itself. Any HTTP answer counts as reachable.
Future<bool> canReachMapServer({Duration timeout = const Duration(seconds: 6)}) async {
  try {
    final r = await http.head(Uri.parse(mapStyleUrl)).timeout(timeout);
    return r.statusCode < 500;
  } catch (_) {
    return false;
  }
}

/// A region stored in MapLibre's offline database.
class StoredRegion {
  final int id;
  final Map<String, dynamic> metadata;
  const StoredRegion(this.id, this.metadata);

  /// Regions this app saved for [tripId] (other apps' or tools' regions in
  /// the same database are left alone).
  bool belongsTo(String tripId) => metadata['app'] == offlineMetadataApp && metadata['tripId'] == tripId;
}

const offlineMetadataApp = 'tripboard';

/// Download progress of one region: [fraction] 0..1 and bytes so far.
typedef RegionProgress = void Function(double fraction, int bytes);

abstract class OfflineMapStore {
  Future<List<StoredRegion>> regions();

  /// Bytes stored for region [id] and whether its download is complete.
  Future<({int bytes, bool complete})> status(int id);

  /// Downloads [spec] of [styleUrl] and completes once every resource is
  /// stored. [onCreated] gets the region id right away, so a running
  /// download can be cancelled by [delete]-ing it; the future then fails
  /// with [OfflineDownloadCancelled].
  Future<int> download(
    RegionSpec spec,
    String styleUrl,
    Map<String, dynamic> metadata, {
    required RegionProgress onProgress,
    void Function(int id)? onCreated,
  });

  Future<void> delete(int id);
}

class OfflineDownloadCancelled implements Exception {
  const OfflineDownloadCancelled();
}

class OfflineDownloadFailed implements Exception {
  final String message;
  const OfflineDownloadFailed(this.message);
  @override
  String toString() => message;
}

/// The real store on top of maplibre_gl's global offline functions.
class MaplibreOfflineStore implements OfflineMapStore {
  bool _limitRaised = false;
  final _running = <int, Completer<int>>{};

  @override
  Future<List<StoredRegion>> regions() async => [
    for (final r in await ml.getListOfRegions()) StoredRegion(r.id, r.metadata),
  ];

  @override
  Future<({int bytes, bool complete})> status(int id) async {
    final s = await ml.getOfflineRegionStatus(id);
    return (bytes: s.completedResourceSize, complete: s.isComplete);
  }

  @override
  Future<int> download(
    RegionSpec spec,
    String styleUrl,
    Map<String, dynamic> metadata, {
    required RegionProgress onProgress,
    void Function(int id)? onCreated,
  }) async {
    if (!_limitRaised) {
      // The default (6000 tiles) counts all regions together; several saved
      // trips would hit it. Each trip plans below tileBudget anyway.
      await ml.setOfflineTileCountLimit(100000);
      _limitRaised = true;
    }
    final done = Completer<int>();
    int? id;
    final region = await ml.downloadOfflineRegion(
      ml.OfflineRegionDefinition(
        bounds: ml.LatLngBounds(
          southwest: ml.LatLng(spec.box.south, spec.box.west),
          northeast: ml.LatLng(spec.box.north, spec.box.east),
        ),
        mapStyleUrl: styleUrl,
        minZoom: spec.minZoom.toDouble(),
        maxZoom: spec.maxZoom.toDouble(),
      ),
      metadata: metadata,
      onEvent: (e) {
        if (done.isCompleted) return;
        if (e is ml.InProgress) {
          onProgress((e.progress / 100).clamp(0, 1).toDouble(), e.completedResourceSize);
        } else if (e is ml.Success) {
          // The id is known once downloadOfflineRegion returned; a region
          // that was already cached can succeed before that.
          scheduleMicrotask(() => done.complete(id ?? -1));
        } else if (e is ml.Error) {
          done.completeError(OfflineDownloadFailed(e.cause.message ?? e.cause.code));
        }
      },
    );
    id = region.id;
    _running[region.id] = done;
    onCreated?.call(region.id);
    try {
      final result = await done.future;
      return result < 0 ? region.id : result;
    } finally {
      _running.remove(region.id);
    }
  }

  @override
  Future<void> delete(int id) async {
    final running = _running.remove(id);
    await ml.deleteOfflineRegion(id);
    if (running != null && !running.isCompleted) running.completeError(const OfflineDownloadCancelled());
  }
}
