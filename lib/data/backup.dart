import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import 'doc_migrations.dart';
import 'repository.dart';

/// ZIP backups: one trip (`trip.json` plus all attachment files) or all
/// trips at once (see [exportAll]).
class Backup {
  static const formatVersion = 1;

  static Future<Uint8List> exportTrip(Repository repo, String tripId) async {
    final data = await repo.loadTrip(tripId);
    if (data == null) throw StateError('Reise nicht gefunden');
    final archive = Archive();
    archive.addFile(ArchiveFile.string('trip.json', jsonEncode(toJson(data))));
    for (final a in data.attachments) {
      final f = repo.files.fileFor(a);
      if (await f.exists()) {
        archive.addFile(ArchiveFile.bytes('files/${a.relPath}', await f.readAsBytes()));
      }
    }
    return ZipEncoder().encodeBytes(archive);
  }

  static Map<String, Object?> toJson(TripData d) => {
        'format': 'travel_planner',
        'version': formatVersion,
        'docVersion': currentDocVersion,
        'trip': d.trip.toJson(),
        'items': [for (final i in d.items) i.toJson()],
        'cards': [for (final c in d.cards) c.toJson()],
        'edges': [for (final e in d.edges) e.toJson()],
        'attachments': [for (final a in d.attachments) a.toJson()],
      };

  /// Backups written before the doc version existed count as version 1.
  static TripData fromJson(Map<String, Object?> j) {
    final from = (j['docVersion'] as num?)?.toInt() ?? 1;
    Map<String, Object?> doc(String type, Object? e) => migrateDoc(type, (e as Map).cast<String, Object?>(), from);
    List<Map<String, Object?>> list(String k, String type) =>
        [for (final e in (j[k] as List? ?? const [])) doc(type, e)];
    return TripData(
      trip: Trip.fromJson(doc('trip', j['trip'])),
      items: [for (final e in list('items', 'item')) PlanItem.fromJson(e)],
      cards: [for (final e in list('cards', 'card')) NoteCard.fromJson(e)],
      edges: [for (final e in list('edges', 'edge')) Edge.fromJson(e)],
      attachments: [for (final e in list('attachments', 'attachment')) Attachment.fromJson(e)],
    );
  }

  /// ZIP backup of all trips that are not in the trash: `backup.json` lists
  /// the trips, each one lies in `trips/<id>/` exactly like a single-trip ZIP.
  static Future<Uint8List> exportAll(Repository repo) async {
    final trips = await repo.watchTrips().first;
    final archive = Archive();
    final ids = <String>[];
    for (final t in trips) {
      final data = await repo.loadTrip(t.id);
      if (data == null) continue;
      ids.add(t.id);
      final dir = 'trips/${t.id}/';
      archive.addFile(ArchiveFile.string('${dir}trip.json', jsonEncode(toJson(data))));
      for (final a in data.attachments) {
        final f = repo.files.fileFor(a);
        if (await f.exists()) {
          archive.addFile(ArchiveFile.bytes('${dir}files/${a.relPath}', await f.readAsBytes()));
        }
      }
    }
    archive.addFile(ArchiveFile.string(
      'backup.json',
      jsonEncode({
        'format': 'travel_planner_all',
        'version': formatVersion,
        'createdAt': DateTime.now().toIso8601String(),
        'trips': ids,
      }),
    ));
    return ZipEncoder().encodeBytes(archive);
  }

  /// Imports a single-trip ZIP. If the trip already exists it is imported as
  /// a copy with fresh ids. Returns the id of the imported trip.
  static Future<String> importZip(Repository repo, Uint8List bytes) async {
    final ids = await importAny(repo, bytes);
    return ids.first;
  }

  /// Imports a single-trip or an all-trips ZIP and returns the ids of the
  /// imported trips.
  ///
  /// Trips that already exist become copies with fresh ids, unless [replace]
  /// is set (restoring a backup): then the existing trip is overwritten with
  /// the state from the ZIP, including a trip that is in the trash.
  static Future<List<String>> importAny(Repository repo, Uint8List bytes, {bool replace = false}) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final manifest = archive.findFile('backup.json');
    if (manifest == null) {
      if (archive.findFile('trip.json') == null) {
        throw const FormatException('Kein Tripboard-Backup (keine trip.json im Archiv)');
      }
      return [await _importTrip(repo, archive, '', replace: replace)];
    }
    final m = (jsonDecode(utf8.decode(manifest.content)) as Map).cast<String, Object?>();
    if (m['format'] != 'travel_planner_all') throw const FormatException('Unbekanntes Backup-Format');
    final ids = <String>[];
    for (final id in (m['trips'] as List? ?? const [])) {
      final dir = 'trips/$id/';
      if (archive.findFile('${dir}trip.json') == null) continue;
      ids.add(await _importTrip(repo, archive, dir, replace: replace));
    }
    return ids;
  }

  /// Imports the trip stored under [dir] (`''` or `trips/<id>/`) of [archive].
  static Future<String> _importTrip(Repository repo, Archive archive, String dir, {required bool replace}) async {
    final tripFile = archive.findFile('${dir}trip.json')!;
    final original = fromJson((jsonDecode(utf8.decode(tripFile.content)) as Map).cast<String, Object?>());
    final exists = await repo.tripExists(original.trip.id);
    final data = exists && !replace ? withFreshIds(original, titleSuffix: ' (Kopie)') : original;

    // withFreshIds keeps the order, so index k maps back to the ZIP entry.
    final atts = <Attachment>[];
    for (var k = 0; k < data.attachments.length; k++) {
      final a = data.attachments[k];
      final f = archive.findFile('${dir}files/${original.attachments[k].relPath}');
      if (f == null) continue;
      atts.add(await repo.files.addBytes(
        tripId: a.tripId,
        ownerId: a.ownerId,
        bytes: f.content,
        fileName: a.fileName,
        id: a.id,
        createdAt: a.createdAt,
      ));
    }
    final result = TripData(
      trip: data.trip,
      items: data.items,
      cards: data.cards,
      edges: data.edges,
      attachments: atts,
    );
    // Replacing swaps old and new state in one transaction, so a failure
    // halfway never leaves the trip deleted.
    if (exists && replace) {
      await repo.replaceTripData(result);
    } else {
      await repo.putTripData(result);
    }
    return data.trip.id;
  }

  /// Copy of [d] with new ids everywhere (references remapped).
  static TripData withFreshIds(TripData d, {String titleSuffix = ''}) {
    const uuid = Uuid();
    final ids = <String, String>{};
    String map(String id) => ids.putIfAbsent(id, () => uuid.v4());
    String? mapN(String? id) => id == null ? null : (ids[id] ?? id);

    final tripId = map(d.trip.id);
    for (final i in d.items) {
      map(i.id);
    }
    for (final c in d.cards) {
      map(c.id);
    }
    for (final a in d.attachments) {
      map(a.id);
    }

    final trip = Trip(
      id: tripId,
      title: '${d.trip.title}$titleSuffix',
      startDate: d.trip.startDate,
      plannedDays: d.trip.plannedDays,
      color: d.trip.color,
      createdAt: DateTime.now(),
    );
    final items = [
      for (final i in d.items)
        PlanItem.fromJson({
          ...i.toJson(),
          'id': ids[i.id],
          'tripId': tripId,
          'parentId': mapN(i.parentId),
          'fromId': mapN(i.fromId),
          'toId': mapN(i.toId),
        }),
    ];
    final cards = [
      for (final c in d.cards)
        NoteCard.fromJson({
          ...c.toJson(),
          'id': ids[c.id],
          'tripId': tripId,
          'itemId': mapN(c.itemId),
          'imageAttachmentId': mapN(c.imageAttachmentId),
        }),
    ];
    final edges = [
      for (final e in d.edges)
        Edge(id: uuid.v4(), tripId: tripId, fromId: mapN(e.fromId)!, toId: mapN(e.toId)!, label: e.label),
    ];
    final atts = [
      for (final a in d.attachments)
        Attachment(
          id: ids[a.id]!,
          tripId: tripId,
          ownerId: mapN(a.ownerId)!,
          fileName: a.fileName,
          relPath: '${ids[a.id]}${_ext(a.relPath)}',
          mime: a.mime,
          createdAt: a.createdAt,
        ),
    ];
    return TripData(trip: trip, items: items, cards: cards, edges: edges, attachments: atts);
  }

  static String _ext(String path) {
    final i = path.lastIndexOf('.');
    return i < 0 ? '' : path.substring(i);
  }
}
