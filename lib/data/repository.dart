import 'dart:async';
import 'dart:convert';


import '../domain/models.dart';
import 'attachment_store.dart';
import 'db.dart';

class Repository {
  final AppDatabase db;
  final AttachmentStore files;

  Repository(this.db, this.files);

  // --- reading ---------------------------------------------------------------

  Stream<List<Trip>> watchTrips() {
    final q = db.select(db.docs)..where((d) => d.type.equals('trip'));
    return q.watch().map((rows) {
      final trips = [for (final r in rows) Trip.fromJson(_decode(r.json))];
      trips.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return trips;
    });
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

  static Map<String, Object?> _decode(String s) => (jsonDecode(s) as Map).cast<String, Object?>();

  // --- writing ---------------------------------------------------------------

  Future<void> _put(String id, String tripId, String type, Map<String, Object?> json) =>
      db.into(db.docs).insertOnConflictUpdate(DocsCompanion.insert(
        id: id,
        tripId: tripId,
        type: type,
        json: jsonEncode(json),
        updatedAt: DateTime.now().millisecondsSinceEpoch,
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

  Future<void> deleteTrip(String tripId) async {
    final data = await loadTrip(tripId);
    await (db.delete(db.docs)..where((d) => d.tripId.equals(tripId))).go();
    for (final a in data?.attachments ?? const <Attachment>[]) {
      await files.delete(a);
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

  Future<bool> tripExists(String id) async {
    final row = await (db.select(db.docs)..where((d) => d.id.equals(id))).getSingleOrNull();
    return row != null;
  }

  Future<void> close() => db.close();
}
