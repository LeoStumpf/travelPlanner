import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/data/attachment_store.dart';
import 'package:travel_planner/data/backup.dart';
import 'package:travel_planner/data/db.dart';
import 'package:travel_planner/data/file_sources.dart';
import 'package:travel_planner/data/repository.dart';
import 'package:travel_planner/domain/demo.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/state/providers.dart';

void main() {
  late Directory tmp;
  late Repository repo;
  late ProviderContainer c;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('tp_files');
    repo = Repository(AppDatabase(NativeDatabase.memory()), AttachmentStore(Directory('${tmp.path}/att')));
    c = ProviderContainer(overrides: [repositoryProvider.overrideWithValue(repo)]);
  });

  tearDown(() async {
    c.dispose();
    await repo.close();
    await tmp.delete(recursive: true);
  });

  Future<Attachment> add(TripData d, String name, {String folder = '', List<String> owners = const []}) async {
    final a = await repo.files.addBytes(
      tripId: d.trip.id,
      ownerIds: owners,
      folder: folder,
      bytes: Uint8List.fromList([1, 2, 3]),
      fileName: name,
    );
    await repo.saveAttachment(a);
    return a;
  }

  test('a file is linked to several items; deleting one item only unlinks it', () async {
    final demo = demoSriLanka();
    await repo.putTripData(demo);
    final [first, second, ...] = demo.items;
    final a = await add(demo, 'e-ticket.pdf', folder: 'Flights', owners: [first.id]);
    await repo.linkAttachment(a, second.id);
    var d = (await repo.loadTrip(demo.trip.id))!;
    expect(d.attachmentsOf(first.id).single.id, a.id);
    expect(d.attachmentsOf(second.id).single.id, a.id);

    await repo.deleteItem(d, first.id);
    d = (await repo.loadTrip(demo.trip.id))!;
    expect(d.attachment(a.id)!.ownerIds, [second.id]);
    expect(await repo.files.fileFor(a).exists(), isTrue);
  });

  test('folders: create, rename with files and subfolders, delete with undo', () async {
    final demo = demoSriLanka();
    await repo.putTripData(demo);
    final actions = c.read(planActionsProvider);
    await repo.createFolder(demo, 'Visa');
    var d = (await repo.loadTrip(demo.trip.id))!;
    final out = await add(d, 'out.pdf', folder: 'Flights/Outbound');
    final back = await add(d, 'back.pdf', folder: 'Flights');
    d = (await repo.loadTrip(demo.trip.id))!;

    await repo.renameFolder(d, 'Flights', 'Flüge');
    d = (await repo.loadTrip(demo.trip.id))!;
    expect(d.attachment(out.id)!.folder, 'Flüge/Outbound');
    expect(d.attachment(back.id)!.folder, 'Flüge');
    expect(d.trip.folders, contains('Flüge'));

    await actions.record(demo.trip.id, 'deleted', (r) => r.deleteFolder(d, 'Flüge'));
    d = (await repo.loadTrip(demo.trip.id))!;
    expect(d.attachments, isEmpty);
    expect(d.trip.folders, ['Visa']);
    expect(await repo.files.fileFor(out).exists(), isFalse);

    await actions.undo(demo.trip.id);
    d = (await repo.loadTrip(demo.trip.id))!;
    expect(d.attachments, hasLength(2));
    expect(await repo.files.fileFor(out).readAsBytes(), [1, 2, 3]);
  });

  test('moving files makes taken names unique; renaming keeps the folder', () async {
    final demo = demoSriLanka();
    await repo.putTripData(demo);
    final a = await add(demo, 'ticket.pdf');
    await add(demo, 'ticket.pdf', folder: 'Flights');
    var d = (await repo.loadTrip(demo.trip.id))!;
    await repo.moveAttachments(d, [a.id], 'Flights');
    d = (await repo.loadTrip(demo.trip.id))!;
    expect(d.attachment(a.id)!.folder, 'Flights');
    expect(d.attachment(a.id)!.fileName, 'ticket (2).pdf');
    await repo.renameAttachment(d, d.attachment(a.id)!, 'Hinflug.pdf');
    d = (await repo.loadTrip(demo.trip.id))!;
    expect(d.attachment(a.id)!.fileName, 'Hinflug.pdf');
    expect(d.attachment(a.id)!.folder, 'Flights');
  });

  test('discarding a new item deletes its own new files and unlinks picked ones', () async {
    final demo = demoSriLanka();
    await repo.putTripData(demo);
    final old = await add(demo, 'old.pdf');
    final since = DateTime.now();
    final own = await add(demo, 'new.pdf', owners: ['draft']);
    await repo.linkAttachment(old, 'draft');
    final d = (await repo.loadTrip(demo.trip.id))!;
    await repo.discardOwnerFiles(d, 'draft', since);
    final after = (await repo.loadTrip(demo.trip.id))!;
    expect(after.attachment(own.id), isNull);
    expect(after.attachment(old.id)!.ownerIds, isEmpty);
  });

  test('backups keep folders, links and the trip folder list; copies remap owners', () async {
    final demo = demoSriLanka();
    await repo.putTripData(demo);
    await repo.createFolder(demo, 'Visa');
    final [first, second, ...] = demo.items;
    await add(demo, 'e-ticket.pdf', folder: 'Flights', owners: [first.id, second.id]);
    final zip = await Backup.exportTrip(repo, demo.trip.id);
    expect(ZipDecoder().decodeBytes(zip).files.where((f) => f.name.startsWith('files/')), hasLength(1));

    final id = await Backup.importZip(repo, zip);
    final copy = (await repo.loadTrip(id))!;
    expect(copy.trip.id, isNot(demo.trip.id));
    expect(copy.trip.folders, ['Visa']);
    final f = copy.attachments.single;
    expect(f.folder, 'Flights');
    expect(f.ownerIds, hasLength(2));
    expect(f.ownerIds.every((o) => copy.item(o) != null), isTrue);
    expect(await repo.files.fileFor(f).readAsBytes(), [1, 2, 3]);
  });

  test('readFolder lists files with their subfolders and skips hidden ones', () async {
    final dir = Directory('${tmp.path}/Sri Lanka');
    await File('${dir.path}/Flights/out.pdf').create(recursive: true);
    await File('${dir.path}/visa.pdf').create(recursive: true);
    await File('${dir.path}/.thumbnails/x.jpg').create(recursive: true);
    await File('${dir.path}/.nomedia').create(recursive: true);
    final f = await readFolder(dir);
    expect(f.name, 'Sri Lanka');
    expect([for (final x in f.files) '${x.folder}|${x.name}'], ['|visa.pdf', 'Flights|out.pdf']);
    expect(f.unreadable, 0);
    expect((await readFolder(Directory('${tmp.path}/missing'))).files, isEmpty);
  });
}
