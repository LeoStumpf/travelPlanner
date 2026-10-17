import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:travel_planner/data/attachment_store.dart';
import 'package:travel_planner/data/auto_backup.dart';
import 'package:travel_planner/data/backup.dart';
import 'package:travel_planner/data/db.dart';
import 'package:travel_planner/data/repository.dart';
import 'package:travel_planner/domain/demo.dart';
import 'package:travel_planner/domain/models.dart';

void main() {
  late Directory tmp;
  late Repository repo;
  late TripData interrail;
  late TripData sriLanka;

  Repository newRepo(String name) {
    final dir = Directory(p.join(tmp.path, name))..createSync();
    return Repository(AppDatabase(NativeDatabase.memory()), AttachmentStore(dir));
  }

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('tp_backup');
    repo = newRepo('a');
    interrail = demoInterrail();
    sriLanka = demoSriLanka();
    await repo.putTripData(interrail);
    await repo.putTripData(sriLanka);
  });

  tearDown(() async {
    await repo.close();
    await tmp.delete(recursive: true);
  });

  Future<Attachment> attach(TripData d, List<int> bytes) async {
    final att = await repo.files.addBytes(
      tripId: d.trip.id,
      ownerId: d.items.first.id,
      bytes: Uint8List.fromList(bytes),
      fileName: 'ticket.pdf',
    );
    await repo.saveAttachment(att);
    return att;
  }

  group('all-trips ZIP', () {
    test('round trip into an empty app keeps ids and attachments, skips the trash', () async {
      final att = await attach(sriLanka, [9, 8, 7]);
      final trashed = demoInterrail();
      final trashedData = Backup.withFreshIds(trashed);
      await repo.putTripData(trashedData);
      await repo.trashTrip(trashedData.trip.id);

      final zip = await Backup.exportAll(repo);
      final other = newRepo('b');
      addTearDown(other.close);
      final ids = await Backup.importAny(other, zip);

      expect(ids.toSet(), {interrail.trip.id, sriLanka.trip.id});
      final loaded = (await other.loadTrip(sriLanka.trip.id))!;
      expect(loaded.items.length, sriLanka.items.length);
      expect(loaded.attachments.single.id, att.id);
      expect(await other.files.fileFor(loaded.attachments.single).readAsBytes(), [9, 8, 7]);
      expect(await other.tripExists(trashedData.trip.id), isFalse);
    });

    test('import into the same app creates copies', () async {
      final zip = await Backup.exportAll(repo);
      final ids = await Backup.importAny(repo, zip);
      expect(ids, hasLength(2));
      expect(ids, isNot(contains(interrail.trip.id)));
      final titles = (await repo.watchTrips().first).map((t) => t.title);
      expect(titles, contains('${interrail.trip.title} (Kopie)'));
      expect(titles, hasLength(4));
    });

    test('restore replaces existing trips and brings trashed ones back', () async {
      final att = await attach(interrail, [1, 2, 3]);
      final zip = await Backup.exportAll(repo);

      // Later changes: an item renamed, the attachment removed, a trip trashed.
      final first = interrail.items.first;
      await repo.saveItem(first.copyWith(title: 'Geändert'));
      await repo.deleteAttachment(att);
      await repo.trashTrip(sriLanka.trip.id);

      final ids = await Backup.importAny(repo, zip, replace: true);
      expect(ids.toSet(), {interrail.trip.id, sriLanka.trip.id});
      final restored = (await repo.loadTrip(interrail.trip.id))!;
      expect(restored.item(first.id)!.title, first.title);
      expect(restored.attachments.single.id, att.id);
      expect(await repo.files.fileFor(restored.attachments.single).readAsBytes(), [1, 2, 3]);
      expect(await repo.loadTrash(), isEmpty);
      expect(await repo.watchTrips().first, hasLength(2));
    });

    test('importAny also accepts a single-trip ZIP', () async {
      final zip = await Backup.exportTrip(repo, interrail.trip.id);
      final ids = await Backup.importAny(repo, zip);
      expect(ids, hasLength(1));
      expect((await repo.loadTrip(ids.single))!.trip.title, '${interrail.trip.title} (Kopie)');
    });

    test('a ZIP without trips is rejected', () async {
      final archive = Archive()..addFile(ArchiveFile.string('readme.txt', 'hi'));
      final zip = Uint8List.fromList(ZipEncoder().encodeBytes(archive));
      expect(() => Backup.importAny(repo, zip), throwsFormatException);
    });
  });

  group('AutoBackup', () {
    late AutoBackup auto;
    final t0 = DateTime(2026, 10, 17, 9, 30, 5);

    setUp(() => auto = AutoBackup(repo, Directory(p.join(tmp.path, 'backups'))));

    test('file names round trip', () {
      expect(AutoBackup.fileName(t0), 'tripboard-backup-20261017-093005.zip');
      expect(AutoBackup.parseName(AutoBackup.fileName(t0)), t0);
      expect(AutoBackup.parseName('other.zip'), isNull);
    });

    test('writes at most once per day', () async {
      expect(await auto.lastBackupAt(), isNull);
      expect(await auto.runIfDue(now: t0), isNotNull);
      expect(await auto.runIfDue(now: t0.add(const Duration(hours: 23))), isNull);
      expect(await auto.runIfDue(now: t0.add(const Duration(hours: 25))), isNotNull);
      expect(await auto.list(), hasLength(2));
      expect(await auto.lastBackupAt(), t0.add(const Duration(hours: 25)));
      // The clock was set back: a newer backup does not block.
      expect(await auto.runIfDue(now: t0.subtract(const Duration(days: 3))), isNotNull);
    });

    test('the written ZIP restores all trips', () async {
      final b = (await auto.runIfDue(now: t0))!;
      final other = newRepo('c');
      addTearDown(other.close);
      final ids = await Backup.importAny(other, await b.file.readAsBytes());
      expect(ids.toSet(), {interrail.trip.id, sriLanka.trip.id});
    });

    test('keeps the newest seven and ignores unfinished files', () async {
      for (var d = 0; d < 9; d++) {
        await auto.runIfDue(now: t0.add(Duration(days: d)));
      }
      await File(p.join(auto.dir.path, '${AutoBackup.fileName(t0)}.tmp')).writeAsString('x');
      final list = await auto.list();
      expect(list, hasLength(AutoBackup.keep));
      expect(list.first.createdAt, t0.add(const Duration(days: 8)));
      expect(list.last.createdAt, t0.add(const Duration(days: 2)));
    });

    test('does nothing without trips', () async {
      await repo.trashTrip(interrail.trip.id);
      await repo.trashTrip(sriLanka.trip.id);
      expect(await auto.runIfDue(now: t0), isNull);
      expect(await auto.list(), isEmpty);
    });

    test('concurrent triggers write one backup', () async {
      final a = auto.createNow(now: t0);
      final b = auto.createNow(now: t0.add(const Duration(seconds: 3)));
      expect(identical(await a, await b), isTrue);
      expect(await auto.list(), hasLength(1));
    });
  });
}
