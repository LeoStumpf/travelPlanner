import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/data/attachment_store.dart';
import 'package:travel_planner/data/db.dart';
import 'package:travel_planner/data/geocoding.dart';
import 'package:travel_planner/data/repository.dart';
import 'package:travel_planner/domain/demo.dart';
import 'package:travel_planner/domain/places.dart';
import 'package:travel_planner/domain/plan_exchange.dart';
import 'package:travel_planner/l10n/app_localizations.dart';
import 'package:travel_planner/state/providers.dart';
import 'package:travel_planner/ui/exchange/clipboard_plan_listener.dart';
import 'package:travel_planner/ui/exchange/plan_exchange_ui.dart';
import 'package:travel_planner/ui/share/share_listener.dart';

import '../l10n_test_utils.dart';

/// Finds nothing, as if offline or the places do not exist.
class _NoGeocoder extends Geocoder {
  final queries = <String>[];
  @override
  Future<List<PlaceResult>> search(String query, {String lang = 'en', GeoBias? bias}) async {
    queries.add(query);
    return const [];
  }
}

void main() {
  late Repository repo;
  late _NoGeocoder geocoder;

  setUp(() {
    repo = Repository(AppDatabase(NativeDatabase.memory()), AttachmentStore(Directory.systemTemp));
    geocoder = _NoGeocoder();
    seenPlanTexts.clear();
  });

  tearDown(() => repo.close());

  Future<void> settle(WidgetTester tester, [int ms = 200]) async {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pumpAndSettle();
  }

  /// A button that opens the import of [plan] into [target].
  Future<void> openImport(WidgetTester tester, String plan, {String? target}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repo), geocoderProvider.overrideWithValue(geocoder)],
      child: testApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => importPlanText(context, ref, plan, targetTripId: target),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await settle(tester);
  }

  /// The style of the entry line starting with [title].
  TextStyle? entryStyle(WidgetTester tester, String title) {
    final rich = tester.widget<RichText>(find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().startsWith(title)));
    TextStyle? style;
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text == title) {
        style = span.style;
        return false;
      }
      return true;
    });
    return style;
  }

  testWidgets('import dialog previews the changes and applies them', (tester) async {
    final demo = demoInterrail();
    await tester.runAsync(() => repo.putTripData(demo));
    final paris = demo.items.firstWhere((i) => i.title == 'Paris');
    final plan = jsonEncode({
      'format': planFormat,
      'trip': {'id': demo.trip.id},
      'items': [
        {'ref': 'eiffel', 'kind': 'activity', 'title': 'Eiffelturm', 'stay': paris.id, 'lat': 48.858, 'lng': 2.294,
         'start': {'day': 2, 'time': '18:00'}, 'end': {'day': 2, 'time': '20:00'}},
        {'ref': 'oops', 'kind': 'activity', 'title': 'Kaputt', 'stay': 'nirgends'},
      ],
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repo)],
      child: testApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => importPlanText(context, ref, 'Plan:\n```json\n$plan\n```', targetTripId: demo.trip.id),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();

    expect(find.text('Plan übernehmen'), findsOneWidget);
    expect(find.text('• 2 neue Einträge'), findsOneWidget);
    expect(find.text('1 Hinweis'), findsOneWidget);
    expect(find.text('Eiffelturm'), findsOneWidget, reason: 'entries listed by title');
    expect(find.text('Kaputt'), findsOneWidget);
    expect(find.text('Keine Konflikte nach dem Import'), findsOneWidget);
    expect(find.text('bisher keiner'), findsOneWidget);
    expect(find.text(demo.trip.title), findsOneWidget, reason: 'target preselected');

    await tester.tap(find.text('Übernehmen'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(find.text('Plan übernommen'), findsOneWidget);

    final after = (await tester.runAsync(() => repo.loadTrip(demo.trip.id)))!;
    expect(after.items.firstWhere((i) => i.title == 'Eiffelturm').parentId, paris.id);
    expect(after.items, hasLength(demo.items.length + 2));
  });

  testWidgets('preview: changed entries name their fields, deleted ones are red, conflicts are counted',
      (tester) async {
    final demo = demoInterrail();
    await tester.runAsync(() => repo.putTripData(demo));
    final louvre = demo.items.firstWhere((i) => i.title == 'Louvre');
    final lyon = demo.items.firstWhere((i) => i.title == 'Lyon');
    final bcn = demo.items.firstWhere((i) => i.title == 'Barcelona');
    final plan = jsonEncode({
      'format': planFormat,
      'trip': {'id': demo.trip.id, 'title': 'Frankreich & Spanien'},
      'items': [
        {'ref': louvre.id, 'notes': 'Tickets online', 'start': {'day': 2, 'time': '09:00'}, 'end': {'day': 2, 'time': '12:00'}},
        // Barcelona moved onto Valencia's days: the stays overlap.
        {'ref': bcn.id, 'start': {'day': 11, 'time': '14:00'}, 'end': {'day': 13, 'time': '10:00'}},
      ],
      'remove': [lyon.id],
    });
    await openImport(tester, plan, target: demo.trip.id);

    expect(find.text('• Reisedaten ändern sich: Titel'), findsOneWidget);
    expect(find.text('• 2 Einträge geändert'), findsOneWidget);
    expect(find.text('• 1 Eintrag gelöscht'), findsOneWidget);
    expect(find.text('Louvre  Zeit, Notizen'), findsOneWidget);
    expect(find.text('Lyon'), findsOneWidget);

    final error = Theme.of(tester.element(find.text('Lyon'))).colorScheme.error;
    expect(entryStyle(tester, 'Lyon')?.color, error);
    expect(entryStyle(tester, 'Lyon')?.decoration, TextDecoration.lineThrough);
    expect(entryStyle(tester, 'Louvre'), isNull);

    // Barcelona now overlaps Valencia.
    expect(find.textContaining('nach dem Import'), findsOneWidget);
    expect(find.text('Keine Konflikte nach dem Import'), findsNothing);
    await tester.tap(find.textContaining('nach dem Import'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Barcelona'), findsWidgets);
  });

  testWidgets('places that cannot be found are listed after applying', (tester) async {
    final demo = demoInterrail();
    await tester.runAsync(() => repo.putTripData(demo));
    final paris = demo.items.firstWhere((i) => i.title == 'Paris');
    final plan = jsonEncode({
      'format': planFormat,
      'trip': {'id': demo.trip.id},
      'items': [
        {'ref': 'a', 'kind': 'activity', 'title': 'Musée Rodin', 'place': 'Musée Rodin', 'stay': paris.id},
        {'ref': 'b', 'kind': 'activity', 'title': 'Geheimtipp', 'place': 'Irgendwo im Marais', 'stay': paris.id},
      ],
    });
    await openImport(tester, plan, target: demo.trip.id);
    expect(find.text('Koordinaten für 2 Einträge suchen'), findsOneWidget);

    await tester.tap(find.text('Übernehmen'));
    await settle(tester, 300);
    expect(geocoder.queries, ['Musée Rodin', 'Irgendwo im Marais']);
    expect(find.text('2 von 2 nicht gefunden'), findsOneWidget);
    expect(find.text('Geheimtipp'), findsOneWidget);
    expect(find.text('Irgendwo im Marais'), findsOneWidget);

    // The plan is already in.
    final after = (await tester.runAsync(() => repo.loadTrip(demo.trip.id)))!;
    expect(after.items.where((i) => i.title == 'Musée Rodin'), hasLength(1));

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Plan übernommen'), findsOneWidget);
  });

  group('plan in the clipboard', () {
    late String clip;
    late int reads;

    Future<void> pumpApp(WidgetTester tester) async {
      clip = '';
      reads = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        switch (call.method) {
          case 'Clipboard.hasStrings':
            return {'value': clip.isNotEmpty};
          case 'Clipboard.getData':
            reads++;
            return {'text': clip};
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.pumpWidget(ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo), geocoderProvider.overrideWithValue(geocoder)],
        child: MaterialApp(
          locale: testLocale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          navigatorKey: navigatorKey,
          builder: (context, child) => ClipboardPlanListener(child: child!),
          home: const Scaffold(body: Text('home')),
        ),
      ));
    }

    Future<void> resume(WidgetTester tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester, 50);
    }

    final plan = 'Hier dein Plan:\n```json\n${jsonEncode({
          'format': planFormat,
          'trip': {'title': 'Sizilien'},
          'items': [
            {'ref': 'pa', 'kind': 'stay', 'title': 'Palermo', 'lat': 38.1, 'lng': 13.36},
          ],
        })}\n```';

    testWidgets('a copied plan is offered once on resume and opens the import', (tester) async {
      await pumpApp(tester);
      clip = plan;
      await resume(tester);
      expect(find.text('Plan in der Zwischenablage gefunden. Plan übernehmen?'), findsOneWidget);

      await tester.tap(find.text('Übernehmen'));
      await settle(tester);
      expect(find.text('Plan übernehmen'), findsOneWidget, reason: 'import dialog');
      expect(find.text('Palermo'), findsOneWidget);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      // Same plan again: not offered a second time.
      await resume(tester);
      expect(find.text('Plan in der Zwischenablage gefunden. Plan übernehmen?'), findsNothing);
    });

    testWidgets('other text or an empty clipboard is ignored', (tester) async {
      await pumpApp(tester);
      await resume(tester);
      expect(reads, 0, reason: 'an empty clipboard is not read');

      clip = 'Einkaufsliste: Milch, Brot';
      await resume(tester);
      expect(reads, 1);
      expect(find.byType(SnackBar), findsNothing);

      clip = 'tripboard-plan, aber kaputt {';
      await resume(tester);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a plan already opened via paste is not offered', (tester) async {
      await pumpApp(tester);
      seenPlanTexts.add(plan.trim().hashCode);
      clip = plan;
      await resume(tester);
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
