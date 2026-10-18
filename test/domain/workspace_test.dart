import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/domain/workspace.dart';

final _t0 = DateTime(2026, 10, 1);

Attachment _file(String id, String name, {String folder = '', List<String> owners = const [], int minute = 0}) =>
    Attachment(
      id: id,
      tripId: 't',
      ownerIds: owners,
      folder: folder,
      fileName: name,
      relPath: '$id.pdf',
      mime: 'application/pdf',
      createdAt: _t0.add(Duration(minutes: minute)),
    );

TripData _data({List<String> folders = const [], List<Attachment> files = const []}) => TripData(
  trip: Trip(id: 't', title: 'Sri Lanka', folders: folders, createdAt: _t0),
  attachments: files,
);

void main() {
  test('folder paths are normalised and split', () {
    expect(normalizeFolder(' /Flights// Outbound /'), 'Flights/Outbound');
    expect(parentFolder('Flights/Outbound'), 'Flights');
    expect(parentFolder('Flights'), '');
    expect(folderName('Flights/Outbound'), 'Outbound');
    expect(joinFolder('', 'Flights'), 'Flights');
    expect(joinFolder('Flights', ''), 'Flights');
    expect(isInFolder('Flights/Outbound', 'Flights'), isTrue);
    expect(isInFolder('Flightsx', 'Flights'), isFalse);
    expect(isInFolder('anything', ''), isTrue);
  });

  test('folders come from the trip and from the files, with their parents', () {
    final d = _data(
      folders: ['Visa'],
      files: [_file('a', 'out.pdf', folder: 'Flights/Outbound')],
    );
    expect(d.allFolders, {'Visa', 'Flights', 'Flights/Outbound'});
    expect(d.subfoldersOf(''), ['Flights', 'Visa']);
    expect(d.subfoldersOf('Flights'), ['Flights/Outbound']);
    expect(d.subfoldersOf('Visa'), isEmpty);
  });

  test('files per folder, newest first; filesBelow includes subfolders', () {
    final d = _data(
      files: [
        _file('a', 'a.pdf', folder: 'Flights', minute: 1),
        _file('b', 'b.pdf', folder: 'Flights', minute: 2),
        _file('c', 'c.pdf', folder: 'Flights/Return'),
        _file('d', 'd.pdf'),
      ],
    );
    expect([for (final f in d.filesIn('Flights')) f.id], ['b', 'a']);
    expect([for (final f in d.filesBelow('Flights')) f.id], unorderedEquals(['a', 'b', 'c']));
    expect([for (final f in d.filesIn('')) f.id], ['d']);
  });

  test('taken names get a number, per folder and ignoring case', () {
    final d = _data(
      folders: ['Flights'],
      files: [
        _file('a', 'Ticket.pdf'),
        _file('b', 'ticket (2).pdf'),
        _file('c', 'Ticket.pdf', folder: 'Flights'),
      ],
    );
    expect(d.uniqueFileName('', 'ticket.pdf'), 'ticket (3).pdf');
    expect(d.uniqueFileName('Visa', 'Ticket.pdf'), 'Ticket.pdf');
    expect(d.uniqueFileName('', 'Ticket.pdf', except: 'a'), 'Ticket.pdf');
    expect(d.uniqueFileName('', 'README'), 'README');
    expect(d.uniqueFolderName('', 'flights'), 'flights (2)');
    expect(d.uniqueFolderName('', 'v1.2'), 'v1.2');
  });

  test('renaming a folder moves its subfolders along', () {
    expect(movedFolderPath('Flights', 'Flights', 'Flüge'), 'Flüge');
    expect(movedFolderPath('Flights/Return', 'Flights', 'Trip/Flüge'), 'Trip/Flüge/Return');
    expect(movedFolderPath('Flightsx', 'Flights', 'Flüge'), 'Flightsx');
    expect(movedFolderPath('', 'Flights', 'Flüge'), '');
  });

  test('attachments are linked to several owners and survive JSON', () {
    final a = _file('a', 'e-ticket.pdf', folder: 'Flights', owners: ['out', 'back']);
    final back = Attachment.fromJson(a.toJson());
    expect(back.ownerIds, ['out', 'back']);
    expect(back.folder, 'Flights');
    final d = _data(files: [a]);
    expect(d.attachmentsOf('back'), [a]);
    expect(d.attachmentsOf('other'), isEmpty);
    final trip = Trip.fromJson(Trip(id: 't', title: 'x', folders: ['Visa'], createdAt: _t0).toJson());
    expect(trip.folders, ['Visa']);
  });
}
