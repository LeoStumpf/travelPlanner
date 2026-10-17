import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:travel_planner/data/attachment_store.dart';
import 'package:travel_planner/data/auto_backup.dart';
import 'package:travel_planner/data/db.dart';
import 'package:travel_planner/data/repository.dart';
import 'package:travel_planner/domain/demo.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/state/providers.dart';
import 'package:travel_planner/ui/backup/auto_backup_listener.dart';
import 'package:travel_planner/ui/backup/backups_page.dart';
import 'package:travel_planner/ui/trips/trips_page.dart';

void main() {
  late Directory tmp;
  late Repository repo;
  late AutoBackup auto;
  late ProviderContainer container;
  late TripData demo;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tp_backup_ui');
    repo = Repository(AppDatabase(NativeDatabase.memory()), AttachmentStore(tmp));
    auto = AutoBackup(repo, Directory(p.join(tmp.path, 'backups')));
    container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(repo),
      autoBackupProvider.overrideWithValue(auto),
    ]);
    demo = demoInterrail();
  });

  tearDown(() async {
    container.dispose();
    await repo.close();
    tmp.deleteSync(recursive: true);
  });

  /// Real file and database work only advances between pumps, and the
  /// progress bar never settles, so this alternates instead of pumpAndSettle.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 25; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pump(WidgetTester tester, Widget home) async {
    await tester.runAsync(() => repo.putTripData(demo));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: home),
    ));
    await settle(tester);
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    await settle(tester);
  }

  Future<void> openMenu(WidgetTester tester) => tapAndSettle(
      tester, find.descendant(of: find.byType(AppBar), matching: find.byType(PopupMenuButton<String>)));

  testWidgets('the trip list menu shows the last backup', (tester) async {
    await pump(tester, const TripsPage());
    await openMenu(tester);
    expect(find.text('Alle Reisen exportieren'), findsOneWidget);
    expect(find.text('Noch kein Backup'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await settle(tester);

    final b = await tester.runAsync(() => auto.createNow(now: DateTime(2026, 10, 17, 14, 3)));
    expect(b, isNotNull);
    container.invalidate(backupsProvider);
    await settle(tester);
    await openMenu(tester);
    expect(find.text('Letztes Backup: 17.10.2026, 14:03'), findsOneWidget);
  });

  testWidgets('the listener backs up on start and when the app goes to the background', (tester) async {
    await pump(tester, const AutoBackupListener(child: SizedBox()));
    expect(await tester.runAsync(auto.list), hasLength(1));

    // Within a day nothing new is written.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await settle(tester);
    expect(await tester.runAsync(auto.list), hasLength(1));

    // An old backup makes the next background switch write one.
    await tester.runAsync(() async {
      final old = (await auto.list()).single.file;
      await old.rename(p.join(auto.dir.path, AutoBackup.fileName(DateTime.now().subtract(const Duration(days: 2)))));
    });
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await settle(tester);
    expect(await tester.runAsync(auto.list), hasLength(2));
    for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
  });

  testWidgets('backing up now and restoring a backup', (tester) async {
    await pump(tester, const BackupsPage());
    expect(find.text('Noch kein Backup'), findsOneWidget);
    expect(find.text('Noch keine automatischen Backups.'), findsOneWidget);

    await tapAndSettle(tester, find.byTooltip('Jetzt sichern'));
    await settle(tester);
    expect(find.text('Backup erstellt'), findsOneWidget);
    expect(find.textContaining('Letztes Backup:'), findsOneWidget);
    expect(find.byTooltip('Wiederherstellen'), findsOneWidget);

    // Change the trip, then restore the backup.
    final paris = demo.items.firstWhere((i) => i.title == 'Paris');
    await tester.runAsync(() async {
      await repo.saveItem(paris.copyWith(title: 'Lyon'));
      // Dated back, so the safety backup gets its own file name.
      final b = (await auto.list()).single.file;
      await b.rename(p.join(auto.dir.path, AutoBackup.fileName(DateTime(2026, 10, 1, 8))));
    });
    container.invalidate(backupsProvider);
    await settle(tester);

    await tapAndSettle(tester, find.byTooltip('Wiederherstellen'));
    expect(find.text('Backup wiederherstellen?'), findsOneWidget);
    await tapAndSettle(tester, find.widgetWithText(FilledButton, 'Wiederherstellen'));
    await settle(tester);
    expect(find.text('Eine Reise wiederhergestellt'), findsOneWidget);
    final restored = await tester.runAsync(() => repo.loadTrip(demo.trip.id));
    expect(restored!.item(paris.id)!.title, 'Paris');
    // The state before restoring was saved as well.
    expect(await tester.runAsync(auto.list), hasLength(2));
  });
}
