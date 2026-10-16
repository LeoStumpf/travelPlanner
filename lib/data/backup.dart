import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import 'repository.dart';

/// ZIP backup of one trip: `trip.json` plus all attachment files.
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
        'trip': d.trip.toJson(),
        'items': [for (final i in d.items) i.toJson()],
        'cards': [for (final c in d.cards) c.toJson()],
        'edges': [for (final e in d.edges) e.toJson()],
        'attachments': [for (final a in d.attachments) a.toJson()],
      };

  static TripData fromJson(Map<String, Object?> j) {
    List<Map<String, Object?>> list(String k) =>
        [for (final e in (j[k] as List? ?? const [])) (e as Map).cast<String, Object?>()];
    return TripData(
      trip: Trip.fromJson((j['trip'] as Map).cast<String, Object?>()),
      items: [for (final e in list('items')) PlanItem.fromJson(e)],
      cards: [for (final e in list('cards')) NoteCard.fromJson(e)],
      edges: [for (final e in list('edges')) Edge.fromJson(e)],
      attachments: [for (final e in list('attachments')) Attachment.fromJson(e)],
    );
  }

  /// Imports a ZIP. If the trip already exists it is imported as a copy with
  /// fresh ids. Returns the id of the imported trip.
  static Future<String> importZip(Repository repo, Uint8List bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final tripFile = archive.findFile('trip.json');
    if (tripFile == null) throw const FormatException('Keine trip.json im Archiv');
    final original = fromJson((jsonDecode(utf8.decode(tripFile.content)) as Map).cast<String, Object?>());
    final data = await repo.tripExists(original.trip.id)
        ? withFreshIds(original, titleSuffix: ' (Kopie)')
        : original;

    // withFreshIds keeps the order, so index k maps back to the ZIP entry.
    final atts = <Attachment>[];
    for (var k = 0; k < data.attachments.length; k++) {
      final a = data.attachments[k];
      final f = archive.findFile('files/${original.attachments[k].relPath}');
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
    await repo.putTripData(TripData(
      trip: data.trip,
      items: data.items,
      cards: data.cards,
      edges: data.edges,
      attachments: atts,
    ));
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
