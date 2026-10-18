import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/data/attachment_store.dart';
import 'package:travel_planner/data/db.dart';
import 'package:travel_planner/data/file_sources.dart';
import 'package:travel_planner/data/repository.dart';
import 'package:travel_planner/domain/demo.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/state/providers.dart';
import 'package:travel_planner/ui/agenda/agenda_view.dart';
import 'package:travel_planner/ui/editor/attachments_section.dart';
import 'package:travel_planner/ui/files/files_page.dart';

import '../l10n_test_utils.dart';

/// Hands out prepared files instead of opening the system pickers.
class _FakeSources extends FileSources {
  List<PickedFile> files = const [];
  PickedFolder? folder;

  @override
  Future<List<PickedFile>> pickFiles({String? dialogTitle}) async => files;
  @override
  Future<List<PickedFile>> pickImages() async => files;
  @override
  Future<PickedFile?> takePhoto() async => files.firstOrNull;
  @override
  Future<PickedFolder?> pickFolder({String? dialogTitle}) async => folder;
}

PickedFile _pdf(String name, {String folder = ''}) => PickedFile(name, Uint8List.fromList([1, 2, 3]), folder: folder);

void main() {
  late Directory tmp;
  late Repository repo;
  late ProviderContainer container;
  late _FakeSources sources;
  late List<String> opened;
  late TripData demo;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('tp_files_ui');
    repo = Repository(AppDatabase(NativeDatabase.memory()), AttachmentStore(tmp));
    sources = _FakeSources();
    opened = [];
    container = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        fileSourcesProvider.overrideWithValue(sources),
        fileOpenerProvider.overrideWithValue((path, mime) async {
          opened.add(path);
          return true;
        }),
      ],
    );
    demo = demoSriLanka();
  });

  tearDown(() async {
    container.dispose();
    await repo.close();
    await tmp.delete(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    // File and database work runs outside the fake clock, one step at a time.
    for (var k = 0; k < 12; k++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<TripData> stored(WidgetTester tester) async => (await tester.runAsync(() => repo.loadTrip(demo.trip.id)))!;

  Future<void> pumpPage(WidgetTester tester, {Size size = const Size(800, 1200)}) async {
    await tester.runAsync(() => repo.putTripData(demo));
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: testApp(home: FilesPage(tripId: demo.trip.id)),
      ),
    );
    await settle(tester);
  }

  Future<void> addVia(WidgetTester tester, String menuEntry) async {
    await tester.tap(find.text('Hinzufügen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(menuEntry));
    await settle(tester);
  }

  Future<void> fileMenu(WidgetTester tester, String fileName, String entry) async {
    await tester.tap(
      find.descendant(of: find.widgetWithText(ListTile, fileName), matching: find.byTooltip('Weitere Optionen')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(entry).last);
    await tester.pumpAndSettle();
  }

  testWidgets('several files at once, opened with a tap', (tester) async {
    await pumpPage(tester);
    expect(find.textContaining('Noch keine Dateien'), findsOneWidget);
    sources.files = [_pdf('Flug hin.pdf'), _pdf('Flug zurück.pdf')];
    await addVia(tester, 'Dateien wählen');
    expect(find.text('Flug hin.pdf'), findsOneWidget);
    expect(find.text('Flug zurück.pdf'), findsOneWidget);
    expect((await stored(tester)).attachments, hasLength(2));

    await tester.tap(find.text('Flug hin.pdf'));
    await settle(tester);
    expect(opened.single, endsWith('.pdf'));
  });

  testWidgets('folders: create, add into it, breadcrumb back to the top', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byTooltip('Neuer Ordner'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Flüge');
    await tester.tap(find.text('OK'));
    await settle(tester);
    // Opened the new folder: breadcrumb "Dateien › Flüge".
    expect(find.text('Flüge'), findsOneWidget);
    expect(find.text('Dieser Ordner ist leer.'), findsOneWidget);

    sources.files = [_pdf('e-ticket.pdf')];
    await addVia(tester, 'Dateien wählen');
    expect((await stored(tester)).attachments.single.folder, 'Flüge');

    await tester.tap(find.widgetWithText(TextButton, 'Dateien'));
    await settle(tester);
    expect(find.text('e-ticket.pdf'), findsNothing);
    expect(find.text('1 Datei'), findsOneWidget);
  });

  testWidgets('a whole folder comes in with its subfolders', (tester) async {
    await pumpPage(tester);
    sources.folder = PickedFolder('Sri Lanka', [_pdf('visa.pdf'), _pdf('out.pdf', folder: 'Flights')]);
    await addVia(tester, 'Ordner importieren');
    final d = await stored(tester);
    expect(
      {for (final a in d.attachments) a.fileName: a.folder},
      {'visa.pdf': 'Sri Lanka', 'out.pdf': 'Sri Lanka/Flights'},
    );
    // Shows the imported folder.
    expect(find.text('visa.pdf'), findsOneWidget);
    expect(find.text('Flights'), findsOneWidget);

    sources.folder = const PickedFolder('Locked', []);
    await addVia(tester, 'Ordner importieren');
    expect(find.textContaining('kann diesen Ordner nicht lesen'), findsOneWidget);
  });

  testWidgets('one file linked to both flights; chips show the links', (tester) async {
    await pumpPage(tester);
    sources.files = [_pdf('tickets.pdf')];
    await addVia(tester, 'Dateien wählen');
    final flights = [
      for (final i in demo.items)
        if (i.kind == ItemKind.transport && i.fixed) i,
    ];
    expect(flights, hasLength(2));

    await fileMenu(tester, 'tickets.pdf', 'Mit Elementen verknüpfen');
    for (final f in flights) {
      await tester.tap(find.widgetWithText(CheckboxListTile, f.title));
      await tester.pump();
    }
    await tester.tap(find.text('OK'));
    await settle(tester);
    final a = (await stored(tester)).attachments.single;
    expect(a.ownerIds, [for (final f in flights) f.id]);
    for (final f in flights) {
      expect(find.widgetWithText(ActionChip, f.title), findsOneWidget);
    }
  });

  testWidgets('deleting files can be undone, file included', (tester) async {
    await pumpPage(tester);
    sources.files = [_pdf('old.pdf')];
    await addVia(tester, 'Dateien wählen');
    final a = (await stored(tester)).attachments.single;
    await fileMenu(tester, 'old.pdf', 'Löschen');
    await tester.tap(find.widgetWithText(FilledButton, 'Löschen'));
    await settle(tester);
    expect((await stored(tester)).attachments, isEmpty);
    expect(File('${tmp.path}/${a.relPath}').existsSync(), isFalse);

    await tester.tap(find.text('Rückgängig'));
    await settle(tester);
    expect((await stored(tester)).attachments, hasLength(1));
    expect(File('${tmp.path}/${a.relPath}').existsSync(), isTrue);
    expect(find.text('old.pdf'), findsOneWidget);
  });

  testWidgets('selecting several files moves them into a folder', (tester) async {
    await pumpPage(tester);
    await tester.runAsync(() => repo.createFolder(demo, 'Visa'));
    sources.files = [_pdf('a.pdf'), _pdf('b.pdf')];
    await addVia(tester, 'Dateien wählen');
    await tester.longPress(find.text('a.pdf'));
    await tester.pump();
    await tester.tap(find.text('b.pdf'));
    await tester.pump();
    expect(find.text('2 ausgewählt'), findsOneWidget);
    await tester.tap(find.byTooltip('In Ordner verschieben'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Visa').last);
    await settle(tester);
    expect([for (final a in (await stored(tester)).attachments) a.folder], ['Visa', 'Visa']);
  });

  testWidgets('fits a 360 dp phone', (tester) async {
    await pumpPage(tester, size: const Size(360, 640));
    sources.files = [_pdf('A very long booking confirmation file name for the flight to Colombo.pdf')];
    await addVia(tester, 'Dateien wählen');
    expect(tester.takeException(), isNull);
  });

  group('attachments of an item', () {
    Future<PlanItem> pumpSection(WidgetTester tester) async {
      await tester.runAsync(() => repo.putTripData(demo));
      final train = demo.items.firstWhere((i) => i.kind == ItemKind.transport && !i.fixed);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: testApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  final d = ref.watch(tripDataProvider(demo.trip.id)).value;
                  if (d == null) return const SizedBox();
                  return ListView(
                    children: [
                      AttachmentsSection(tripId: d.trip.id, ownerId: train.id, attachments: d.attachmentsOf(train.id)),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      return train;
    }

    testWidgets('picks files from the workspace; unlinking keeps them there', (tester) async {
      await tester.runAsync(() async {
        await repo.putTripData(demo);
        final a = await repo.files.addBytes(
          tripId: demo.trip.id,
          folder: 'Trains',
          bytes: Uint8List.fromList([1]),
          fileName: 'seat.pdf',
        );
        await repo.saveAttachment(a);
      });
      final train = await pumpSection(tester);
      await tester.tap(find.byTooltip('Aus den Dateien der Reise'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'seat.pdf'));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await settle(tester);
      expect((await stored(tester)).attachments.single.ownerIds, [train.id]);
      expect(find.text('seat.pdf'), findsOneWidget);

      await tester.tap(find.byTooltip('Verknüpfung lösen'));
      await settle(tester);
      final a = (await stored(tester)).attachments.single;
      expect(a.ownerIds, isEmpty);
      expect(a.folder, 'Trains');
      expect(find.text('seat.pdf'), findsNothing);
    });

    testWidgets('new files from the editor are linked and land at the top level', (tester) async {
      final train = await pumpSection(tester);
      sources.files = [_pdf('one.pdf'), _pdf('two.pdf')];
      await tester.tap(find.byTooltip('Datei (PDF-Ticket …)'));
      await settle(tester);
      final atts = (await stored(tester)).attachments;
      expect(atts, hasLength(2));
      expect(atts.every((a) => a.ownerIds.single == train.id && a.folder.isEmpty), isTrue);
    });
  });
}
