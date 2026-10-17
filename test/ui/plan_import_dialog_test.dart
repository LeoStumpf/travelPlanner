import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/data/attachment_store.dart';
import 'package:travel_planner/data/db.dart';
import 'package:travel_planner/data/repository.dart';
import 'package:travel_planner/domain/demo.dart';
import 'package:travel_planner/domain/plan_exchange.dart';
import 'package:travel_planner/state/providers.dart';
import 'package:travel_planner/ui/exchange/plan_exchange_ui.dart';

import '../l10n_test_utils.dart';

void main() {
  late Repository repo;

  setUp(() {
    repo = Repository(AppDatabase(NativeDatabase.memory()), AttachmentStore(Directory.systemTemp));
  });

  tearDown(() => repo.close());

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
    expect(find.text(demo.trip.title), findsOneWidget, reason: 'target preselected');

    await tester.tap(find.text('Übernehmen'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(find.text('Plan übernommen'), findsOneWidget);

    final after = (await tester.runAsync(() => repo.loadTrip(demo.trip.id)))!;
    expect(after.items.firstWhere((i) => i.title == 'Eiffelturm').parentId, paris.id);
    expect(after.items, hasLength(demo.items.length + 2));
  });
}
