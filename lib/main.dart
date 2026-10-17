import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'data/attachment_store.dart';
import 'data/auto_backup.dart';
import 'data/db.dart';
import 'data/repository.dart';
import 'state/providers.dart';
import 'ui/backup/auto_backup_listener.dart';
import 'ui/common/theme.dart';
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

  runApp(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(repo),
      autoBackupProvider.overrideWithValue(autoBackup),
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
        title: 'Tripboard',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        locale: const Locale('de'),
        supportedLocales: const [Locale('de'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        navigatorKey: navigatorKey,
        builder: (context, child) => ShareListener(child: AutoBackupListener(child: child!)),
        home: const TripsPage(),
      );
}
