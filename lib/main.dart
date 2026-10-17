import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/attachment_store.dart';
import 'data/auto_backup.dart';
import 'data/db.dart';
import 'data/reminder_scheduler.dart';
import 'data/repository.dart';
import 'state/hints.dart';
import 'state/providers.dart';
import 'state/reminders.dart';
import 'ui/backup/auto_backup_listener.dart';
import 'ui/common/l10n.dart';
import 'ui/common/theme.dart';
import 'ui/exchange/clipboard_plan_listener.dart';
import 'ui/reminders/reminder_listener.dart';
import 'ui/share/share_listener.dart';
import 'ui/trips/trips_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final docs = await getApplicationDocumentsDirectory();
  final attachments = Directory(p.join(docs.path, 'attachments'));
  await attachments.create(recursive: true);
  final store = AttachmentStore(attachments);
  await store.emptyTrash();
  final repo = Repository(AppDatabase(), store);
  try {
    await repo.purgeTrash();
  } catch (e) {
    // A broken trash must never keep the app from starting.
    debugPrint('Purging the trash failed: $e');
  }

  final autoBackup = AutoBackup(repo, await _backupDir(docs));

  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    // Without prefs the hints simply show again next start.
    debugPrint('No shared preferences: $e');
  }

  runApp(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(repo),
      autoBackupProvider.overrideWithValue(autoBackup),
      hintPrefsProvider.overrideWithValue(prefs),
      reminderSchedulerProvider.overrideWithValue(LocalReminderScheduler()),
    ],
    child: const TravelPlannerApp(),
  ));
}

/// App-specific external storage on Android (visible via USB under
/// `Android/data/<app>/files`, no permission needed), else the documents folder.
Future<Directory> _backupDir(Directory docs) async {
  Directory? base;
  if (Platform.isAndroid) {
    try {
      base = await getExternalStorageDirectory();
    } catch (e) {
      debugPrint('No external storage: $e');
    }
  }
  return Directory(p.join((base ?? docs).path, 'backups'));
}

class TravelPlannerApp extends StatelessWidget {
  const TravelPlannerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        onGenerateTitle: (context) => context.l10n.appTitle,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        // Follows the device language; anything but German falls back to
        // English (the first supported locale).
        supportedLocales: appLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        navigatorKey: navigatorKey,
        builder: (context, child) => ShareListener(
            child: AutoBackupListener(child: ReminderListener(child: ClipboardPlanListener(child: child!)))),
        home: const TripsPage(),
      );
}
