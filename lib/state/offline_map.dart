import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/offline_maps.dart';
import '../domain/map_offline.dart';

/// The MapLibre offline database; overridden in tests with a fake.
final offlineMapStoreProvider = Provider<OfflineMapStore>((ref) => MaplibreOfflineStore());

/// Asks whether the map server can be reached; overridden in tests.
final mapReachabilityProvider = Provider<Future<bool> Function()>((ref) => canReachMapServer);

/// The offline map of one trip: what is saved, and a running download.
class OfflineMapState {
  /// False until the stored regions were listed once.
  final bool loaded;
  final List<int> regionIds;

  /// Bytes stored for the trip's regions.
  final int bytes;

  /// All regions downloaded completely.
  final bool complete;
  final DateTime? savedAt;

  /// Area the saved map covers (the padded trip area when it was saved).
  final GeoBox? box;

  /// 0..1 while a download runs, otherwise null.
  final double? progress;
  final int downloadedBytes;

  /// The last download failed with this message.
  final String? error;

  const OfflineMapState({
    this.loaded = false,
    this.regionIds = const [],
    this.bytes = 0,
    this.complete = false,
    this.savedAt,
    this.box,
    this.progress,
    this.downloadedBytes = 0,
    this.error,
  });

  bool get downloading => progress != null;
  bool get saved => complete && regionIds.isNotEmpty;

  /// Whether the saved map still covers every place in [places].
  bool covers(GeoBox? places) => box != null && (places == null || box!.contains(places));

  OfflineMapState copyWith({double? Function()? progress, int? downloadedBytes, String? Function()? error}) =>
      OfflineMapState(
        loaded: loaded,
        regionIds: regionIds,
        bytes: bytes,
        complete: complete,
        savedAt: savedAt,
        box: box,
        progress: progress != null ? progress() : this.progress,
        downloadedBytes: downloadedBytes ?? this.downloadedBytes,
        error: error != null ? error() : this.error,
      );
}

/// Kept alive (not auto-disposed), so a download carries on when the user
/// leaves the map or the trip.
class OfflineMapNotifier extends Notifier<OfflineMapState> {
  final String tripId;
  OfflineMapNotifier(this.tripId);

  OfflineMapStore get _store => ref.read(offlineMapStoreProvider);
  int? _runningId;
  bool _cancelled = false;

  @override
  OfflineMapState build() {
    Future.microtask(refresh);
    return const OfflineMapState();
  }

  Future<List<StoredRegion>> _mine() async => [
    for (final r in await _store.regions())
      if (r.belongsTo(tripId)) r,
  ];

  /// Re-reads what is stored. Without the plugin (tests, unsupported
  /// platforms) the trip simply has nothing saved.
  Future<void> refresh() async {
    var next = const OfflineMapState(loaded: true);
    try {
      final mine = await _mine();
      var bytes = 0, complete = mine.isNotEmpty;
      DateTime? savedAt;
      GeoBox? box;
      for (final r in mine) {
        final s = await _store.status(r.id);
        bytes += s.bytes;
        complete &= s.complete;
        savedAt ??= DateTime.tryParse('${r.metadata['savedAt']}');
        box ??= GeoBox.fromList(r.metadata['box']);
      }
      next = OfflineMapState(
        loaded: true,
        regionIds: [for (final r in mine) r.id],
        bytes: bytes,
        complete: complete,
        savedAt: savedAt,
        box: box,
      );
    } catch (_) {
      // Leave it empty.
    }
    if (!ref.mounted) return;
    state = OfflineMapState(
      loaded: next.loaded,
      regionIds: next.regionIds,
      bytes: next.bytes,
      complete: next.complete,
      savedAt: next.savedAt,
      box: next.box,
      progress: state.progress,
      downloadedBytes: state.downloadedBytes,
      error: state.error,
    );
  }

  /// Downloads [plan], replacing what was saved for the trip before. The
  /// regions download one after another; progress is weighted by tiles. The
  /// old map is only removed once the new one is complete, so a failed or
  /// cancelled re-save (typically on a poor connection) keeps it usable.
  Future<void> save(OfflinePlan plan, {DateTime? now}) async {
    if (state.downloading) return;
    _cancelled = false;
    state = state.copyWith(progress: () => 0, downloadedBytes: 0, error: () => null);
    final created = <int>[];
    try {
      final old = await _mine();
      final total = plan.tiles == 0 ? 1 : plan.tiles;
      var doneTiles = 0, doneBytes = 0;
      final metadata = {
        'app': offlineMetadataApp,
        'tripId': tripId,
        'savedAt': (now ?? DateTime.now()).toIso8601String(),
        'box': plan.box.toList(),
      };
      for (final spec in plan.regions) {
        if (_cancelled) throw const OfflineDownloadCancelled();
        final tiles = spec.tiles;
        var lastBytes = 0;
        final id = await _store.download(
          spec,
          mapStyleUrl,
          {...metadata, 'part': spec.part},
          onCreated: (id) {
            created.add(id);
            _runningId = id;
          },
          onProgress: (f, bytes) {
            lastBytes = bytes;
            if (!ref.mounted || _cancelled) return;
            state = state.copyWith(
              progress: () => ((doneTiles + f * tiles) / total).clamp(0.0, 1.0),
              downloadedBytes: doneBytes + bytes,
            );
          },
        );
        if (!created.contains(id)) created.add(id);
        doneTiles += tiles;
        doneBytes += lastBytes;
      }
      if (_cancelled) throw const OfflineDownloadCancelled();
      for (final r in old) {
        try {
          await _store.delete(r.id);
        } catch (_) {}
      }
      if (ref.mounted) state = state.copyWith(progress: () => null);
    } catch (e) {
      // Nothing half-saved stays behind.
      for (final id in created) {
        try {
          await _store.delete(id);
        } catch (_) {}
      }
      if (ref.mounted) {
        state = state.copyWith(progress: () => null, error: () => e is OfflineDownloadCancelled ? null : '$e');
      }
    } finally {
      _runningId = null;
    }
    if (ref.mounted) await refresh();
  }

  /// Stops a running download; what it saved so far is removed.
  Future<void> cancel() async {
    if (!state.downloading) return;
    _cancelled = true;
    final id = _runningId;
    if (id != null) {
      try {
        await _store.delete(id);
      } catch (_) {}
    }
  }

  /// Removes the trip's offline map.
  Future<void> delete() async {
    try {
      for (final r in await _mine()) {
        await _store.delete(r.id);
      }
    } catch (_) {}
    await refresh();
  }
}

final offlineMapProvider = NotifierProvider.family<OfflineMapNotifier, OfflineMapState, String>(OfflineMapNotifier.new);
