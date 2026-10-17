import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'data/attachment_store.dart';
import 'data/db.dart';
import 'data/repository.dart';
import 'state/providers.dart';
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

  runApp(ProviderScope(
    overrides: [repositoryProvider.overrideWithValue(repo)],
    child: const TravelPlannerApp(),
  ));
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
        builder: (context, child) => ShareListener(child: child!),
        home: const TripsPage(),
      );
}
