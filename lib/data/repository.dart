import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../domain/models.dart';
import '../domain/places.dart';
import 'attachment_store.dart';
import 'db.dart';
import 'doc_migrations.dart';

/// A trip in the trash and when it was put there.
class TrashedTrip {
  final Trip trip;
  final DateTime deletedAt;
  const TrashedTrip(this.trip, this.deletedAt);

  /// When [Repository.purgeTrash] removes it for good.
  DateTime get purgeAt => deletedAt.add(Repository.trashRetention);
}

class Repository {
  /// How long deleted trips stay in the trash.
  static const trashRetention = Duration(days: 30);

  /// Marks a trashed trip: one extra row per trip, so the trip itself stays
  /// untouched and restoring is just removing the marker.
  static const _trashType = 'trashed';
  static String _trashId(String tripId) => 'trash:$tripId';

  final AppDatabase db;
  final AttachmentStore files;

  Repository(this.db, this.files);

  // --- reading ---------------------------------------------------------------

  Stream<List<DocRow>> _watchTripsAndMarkers() =>
      (db.select(db.docs)..where((d) => d.type.isIn(['trip', _trashType]))).watch();

  /// Trips that are not in the trash, newest first.
  Stream<List<Trip>> watchTrips() => _watchTripsAndMarkers().map((rows) {
        final trashed = {for (final r in rows) if (r.type == _trashType) r.tripId};
        final trips = [
          for (final r in rows)
            if (r.type == 'trip' && !trashed.contains(r.tripId)) Trip.fromJson(_decode(r.json)),
        ];
        trips.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return trips;
      });

  /// Trips in the trash, most recently deleted first.
  Stream<List<TrashedTrip>> watchTrash() => _watchTripsAndMarkers().map(_trashed);

  Future<List<TrashedTrip>> loadTrash() async =>
      _trashed(await (db.select(db.docs)..where((d) => d.type.isIn(['trip', _trashType]))).get());

  List<TrashedTrip> _trashed(List<DocRow> rows) {
    final trips = {for (final r in rows) if (r.type == 'trip') r.tripId: r};
    final list = [
      for (final r in rows)
        if (r.type == _trashType && trips[r.tripId] != null)
          TrashedTrip(
            Trip.fromJson(_decode(trips[r.tripId]!.json)),
            DateTime.parse(_decode(r.json)['deletedAt'] as String),
          ),
    ];
    list.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return list;
  }

  Stream<TripData?> watchTrip(String tripId) {
    final q = db.select(db.docs)..where((d) => d.tripId.equals(tripId));
    return q.watch().map(_assemble);
  }

  Future<TripData?> loadTrip(String tripId) async {
    final q = db.select(db.docs)..where((d) => d.tripId.equals(tripId));
    return _assemble(await q.get());
  }

  TripData? _assemble(List<DocRow> rows) {
    Trip? trip;
    final items = <PlanItem>[];
    final cards = <NoteCard>[];
    final edges = <Edge>[];
    final attachments = <Attachment>[];
    for (final r in rows) {
      final j = _decode(r.json);
      switch (r.type) {
        case 'trip':
          trip = Trip.fromJson(j);
        case 'item':
          items.add(PlanItem.fromJson(j));
        case 'card':
          cards.add(NoteCard.fromJson(j));
        case 'edge':
          edges.add(Edge.fromJson(j));
        case 'attachment':
          attachments.add(Attachment.fromJson(j));
      }
    }
    if (trip == null) return null;
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    cards.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return TripData(trip: trip, items: items, cards: cards, edges: edges, attachments: attachments);
  }

  /// Every located item of the trips outside the trash, with its trip's
  /// title and when it was last saved: the place search's "recently used".
  Future<List<PlaceUse>> loadPlaceUses() async {
    final rows = await (db.select(db.docs)..where((d) => d.type.isIn(['trip', 'item', _trashType]))).get();
    final trashed = {for (final r in rows) if (r.type == _trashType) r.tripId};
    final titles = {
      for (final r in rows)
        if (r.type == 'trip' && !trashed.contains(r.tripId)) r.tripId: Trip.fromJson(_decode(r.json)).title,
    };
    final uses = <PlaceUse>[];
    for (final r in rows) {
      final title = titles[r.tripId];
      if (r.type != 'item' || title == null) continue;
      final item = PlanItem.fromJson(_decode(r.json));
      if (item.hasLocation) uses.add(PlaceUse(item, title, DateTime.fromMillisecondsSinceEpoch(r.updatedAt)));
    }
    return uses;
  }

  static Map<String, Object?> _decode(String s) => (jsonDecode(s) as Map).cast<String, Object?>();

  // --- writing ---------------------------------------------------------------

  Future<void> _put(String id, String tripId, String type, Map<String, Object?> json) =>
      db.into(db.docs).insertOnConflictUpdate(DocsCompanion.insert(
        id: id,
        tripId: tripId,
        type: type,
        json: jsonEncode(json),
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        docVersion: const Value(currentDocVersion),
      ));

  Future<void> saveTrip(Trip t) => _put(t.id, t.id, 'trip', t.toJson());
  Future<void> saveItem(PlanItem i) => _put(i.id, i.tripId, 'item', i.toJson());
  Future<void> saveCard(NoteCard c) => _put(c.id, c.tripId, 'card', c.toJson());
  Future<void> saveEdge(Edge e) => _put(e.id, e.tripId, 'edge', e.toJson());
  Future<void> saveAttachment(Attachment a) => _put(a.id, a.tripId, 'attachment', a.toJson());

  Future<void> saveItems(Iterable<PlanItem> items) => db.transaction(() async {
        for (final i in items) {
          await saveItem(i);
        }
      });

  Future<void> _delete(String id) => (db.delete(db.docs)..where((d) => d.id.equals(id))).go();

  Future<void> deleteEdge(String id) => _delete(id);

  Future<void> deleteAttachment(Attachment a) async {
    await _delete(a.id);
    await files.delete(a);
  }

  /// Deletes an item and unlinks everything that referenced it.
  Future<void> deleteItem(TripData data, String id) => db.transaction(() async {
        await _delete(id);
        for (final i in data.items) {
          if (i.parentId == id || i.fromId == id || i.toId == id) {
            await saveItem(i.copyWith(
              parentId: i.parentId == id ? null : i.parentId,
              fromId: i.fromId == id ? null : i.fromId,
              toId: i.toId == id ? null : i.toId,
            ));
          }
        }
        await _unlinkOwner(data, id);
        for (final c in data.cards) {
          if (c.itemId == id) await saveCard(c.copyWith(itemId: null));
        }
      });

  Future<void> deleteCard(TripData data, String id) => db.transaction(() async {
        await _delete(id);
        await _unlinkOwner(data, id);
      });

  Future<void> _unlinkOwner(TripData data, String ownerId) async {
    for (final e in data.edges) {
      if (e.fromId == ownerId || e.toId == ownerId) await _delete(e.id);
    }
    for (final a in data.attachmentsOf(ownerId)) {
      await deleteAttachment(a);
    }
  }

  /// Moves a trip to the trash. Its documents and files stay as they are.
  Future<void> trashTrip(String tripId, {DateTime? now}) => _put(
        _trashId(tripId),
        tripId,
        _trashType,
        {'deletedAt': (now ?? DateTime.now()).toIso8601String()},
      );

  /// Takes a trip out of the trash.
  Future<void> restoreFromTrash(String tripId) => _delete(_trashId(tripId));

  /// Deletes trips that have been in the trash longer than [trashRetention].
  /// Called on app start. Returns how many trips were removed.
  Future<int> purgeTrash({DateTime? now}) async {
    final limit = (now ?? DateTime.now()).subtract(trashRetention);
    var n = 0;
    for (final t in await loadTrash()) {
      if (t.deletedAt.isBefore(limit)) {
        await deleteTrip(t.trip.id);
        n++;
      }
    }
    return n;
  }

  /// Deletes a trip for good, including its attachment files.
  Future<void> deleteTrip(String tripId) async {
    final data = await loadTrip(tripId);
    await (db.delete(db.docs)..where((d) => d.tripId.equals(tripId))).go();
    for (final a in data?.attachments ?? const <Attachment>[]) {
      await files.deletePermanently(a);
    }
  }

  /// All stored documents of a trip, for undo.
  Future<List<DocRow>> snapshotTrip(String tripId) =>
      (db.select(db.docs)..where((d) => d.tripId.equals(tripId))).get();

  /// Puts a trip back to [rows] exactly (documents and attachment files).
  Future<void> restoreTrip(String tripId, List<DocRow> rows) async {
    final current = await snapshotTrip(tripId);
    final keep = {for (final r in rows) r.id};
    await db.transaction(() async {
      await (db.delete(db.docs)..where((d) => d.tripId.equals(tripId))).go();
      await db.batch((b) => b.insertAll(db.docs, rows));
    });
    for (final r in current) {
      if (r.type == 'attachment' && !keep.contains(r.id)) {
        await files.delete(Attachment.fromJson(_decode(r.json)));
      }
    }
    for (final r in rows) {
      if (r.type == 'attachment') await files.restore(Attachment.fromJson(_decode(r.json)));
    }
  }

  /// Writes a complete trip (used by import and the demo data).
  Future<void> putTripData(TripData d) => db.transaction(() async {
        await saveTrip(d.trip);
        for (final i in d.items) {
          await saveItem(i);
        }
        for (final c in d.cards) {
          await saveCard(c);
        }
        for (final e in d.edges) {
          await saveEdge(e);
        }
        for (final a in d.attachments) {
          await saveAttachment(a);
        }
      });

  /// Replaces a trip completely with [d] in one transaction (restoring a
  /// backup), which also takes it out of the trash. The attachment files of
  /// [d] must already be written; files of the old state that [d] no longer
  /// uses are deleted afterwards. If writing fails, the old state stays.
  Future<void> replaceTripData(TripData d) async {
    final old = await loadTrip(d.trip.id);
    await db.transaction(() async {
      await (db.delete(db.docs)..where((r) => r.tripId.equals(d.trip.id))).go();
      await putTripData(d);
    });
    final keep = {for (final a in d.attachments) a.relPath};
    for (final a in old?.attachments ?? const <Attachment>[]) {
      if (!keep.contains(a.relPath)) await files.deletePermanently(a);
    }
  }

  Future<bool> tripExists(String id) async {
    final row = await (db.select(db.docs)..where((d) => d.id.equals(id))).getSingleOrNull();
    return row != null;
  }

  Future<void> close() => db.close();
}
