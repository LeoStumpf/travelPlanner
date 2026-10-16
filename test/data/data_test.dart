import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/data/attachment_store.dart';
import 'package:travel_planner/data/backup.dart';
import 'package:travel_planner/data/db.dart';
import 'package:travel_planner/data/geocoding.dart';
import 'package:travel_planner/data/link_preview.dart';
import 'package:travel_planner/data/repository.dart';
import 'package:travel_planner/domain/demo.dart';
import 'package:travel_planner/domain/models.dart';

void main() {
  late Directory tmp;
  late Repository repo;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('tp_test');
    repo = Repository(AppDatabase(NativeDatabase.memory()), AttachmentStore(tmp));
  });

  tearDown(() async {
    await repo.close();
    await tmp.delete(recursive: true);
  });

  test('repository stores and streams a trip', () async {
    final demo = demoInterrail();
    await repo.putTripData(demo);
    final loaded = await repo.loadTrip(demo.trip.id);
    expect(loaded!.trip.title, demo.trip.title);
    expect(loaded.items.length, demo.items.length);
    expect(loaded.cards.length, demo.cards.length);
    expect(loaded.edges.length, demo.edges.length);
    expect(await repo.watchTrips().first, hasLength(1));
  });

  test('deleting a stay unlinks its children and edges', () async {
    final demo = demoSriLanka();
    await repo.putTripData(demo);
    final kandy = demo.items.firstWhere((i) => i.title == 'Kandy');
    await repo.deleteItem(demo, kandy.id);
    final after = (await repo.loadTrip(demo.trip.id))!;
    expect(after.item(kandy.id), isNull);
    expect(after.items.where((i) => i.parentId == kandy.id || i.fromId == kandy.id), isEmpty);
    expect(after.edges.where((e) => e.toId == kandy.id), isEmpty);
    expect(after.cards.where((c) => c.itemId == kandy.id), isEmpty);
  });

  test('backup round trip including attachments, imported as copy when existing', () async {
    final demo = demoInterrail();
    await repo.putTripData(demo);
    final train = demo.items.firstWhere((i) => i.kind == ItemKind.transport);
    final att = await repo.files.addBytes(
      tripId: demo.trip.id,
      ownerId: train.id,
      bytes: Uint8List.fromList([1, 2, 3, 4]),
      fileName: 'ticket.pdf',
    );
    await repo.saveAttachment(att);

    final zip = await Backup.exportTrip(repo, demo.trip.id);
    final newId = await Backup.importZip(repo, zip);
    expect(newId, isNot(demo.trip.id));

    final copy = (await repo.loadTrip(newId))!;
    expect(copy.trip.title, '${demo.trip.title} (Kopie)');
    expect(copy.items.length, demo.items.length);
    expect(copy.attachments, hasLength(1));
    final copiedTrain = copy.items.firstWhere((i) => i.title == train.title);
    expect(copy.attachments.single.ownerId, copiedTrain.id);
    expect(await repo.files.fileFor(copy.attachments.single).readAsBytes(), [1, 2, 3, 4]);
    // References are remapped to the new ids.
    final ids = copy.items.map((i) => i.id).toSet();
    for (final i in copy.items) {
      for (final ref in [i.parentId, i.fromId, i.toId]) {
        if (ref != null) expect(ids, contains(ref));
      }
    }

    // Importing into an empty database keeps the original ids.
    await repo.deleteTrip(demo.trip.id);
    final again = await Backup.importZip(repo, zip);
    expect(again, demo.trip.id);
  });

  test('link preview parsing', () {
    const html = '''
      <html><head><title>Fallback</title>
      <meta property="og:title" content="Tree House &amp; Spa">
      <meta content="/img/a.jpg" property="og:image">
      </head></html>''';
    final p = parseLinkPreview(html, Uri.parse('https://example.com/x'));
    expect(p.title, 'Tree House & Spa');
    expect(p.imageUrl, 'https://example.com/img/a.jpg');
  });

  test('photon response parsing', () {
    const body = '''{"features":[{"geometry":{"coordinates":[80.6337,7.2906]},
      "properties":{"name":"Kandy","state":"Central Province","country":"Sri Lanka"}}]}''';
    final r = Geocoder.parsePhoton(body).single;
    expect(r.name, 'Kandy');
    expect(r.detail, 'Central Province, Sri Lanka');
    expect(r.lat, closeTo(7.29, 0.01));
  });
}
