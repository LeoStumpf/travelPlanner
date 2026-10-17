import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/data/attachment_store.dart';
import 'package:travel_planner/data/db.dart';
import 'package:travel_planner/data/repository.dart';
import 'package:travel_planner/domain/demo.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/state/providers.dart';
import 'package:travel_planner/ui/editor/card_editor_page.dart';
import 'package:travel_planner/ui/editor/item_editor_page.dart';
import 'package:travel_planner/ui/trips/trips_page.dart';

import '../l10n_test_utils.dart';

void main() {
  late Repository repo;
  late ProviderContainer container;
  late TripData demo;

  setUp(() {
    repo = Repository(AppDatabase(NativeDatabase.memory()), AttachmentStore(Directory.systemTemp));
    container = ProviderContainer(overrides: [repositoryProvider.overrideWithValue(repo)]);
    demo = demoInterrail();
  });

  tearDown(() async {
    container.dispose();
    await repo.close();
  });

  /// Lets drift and the stream providers catch up.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pumpAndSettle();
  }

  Future<void> pump(WidgetTester tester, Widget home) async {
    await tester.runAsync(() => repo.putTripData(demo));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: testApp(home: home),
    ));
    await settle(tester);
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    await settle(tester);
  }

  group('trip list', () {
    Future<void> deleteDemo(WidgetTester tester) async {
      await pump(tester, const TripsPage());
      expect(find.text(demo.trip.title), findsOneWidget);
      await tapAndSettle(tester, find.descendant(of: find.byType(Card), matching: find.byType(PopupMenuButton<String>)));
      await tapAndSettle(tester, find.text('Löschen'));
    }

    Future<void> openTrash(WidgetTester tester) async {
      await tapAndSettle(tester, find.descendant(of: find.byType(AppBar), matching: find.byType(PopupMenuButton<String>)));
      await tapAndSettle(tester, find.text('Papierkorb'));
    }

    testWidgets('deleting moves the trip to the trash and the snackbar undoes it', (tester) async {
      await deleteDemo(tester);
      expect(find.text(demo.trip.title), findsNothing);
      expect(find.text('Reise gelöscht'), findsOneWidget);
      expect(await tester.runAsync(repo.loadTrash), hasLength(1));

      await tapAndSettle(tester, find.text('Rückgängig'));
      expect(find.text(demo.trip.title), findsOneWidget);
      expect(await tester.runAsync(repo.loadTrash), isEmpty);
    });

    testWidgets('the trash restores a trip', (tester) async {
      await deleteDemo(tester);
      await openTrash(tester);
      expect(find.text(demo.trip.title), findsOneWidget);
      expect(find.textContaining('Wird in 30 Tagen'), findsOneWidget);

      await tapAndSettle(tester, find.byTooltip('Wiederherstellen'));
      expect(find.textContaining('Der Papierkorb ist leer.'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(find.text(demo.trip.title), findsOneWidget);
    });

    testWidgets('the trash deletes a trip for good after confirming', (tester) async {
      await deleteDemo(tester);
      await openTrash(tester);

      await tapAndSettle(tester, find.byTooltip('Endgültig löschen'));
      await tapAndSettle(tester, find.text('Abbrechen'));
      expect(await tester.runAsync(repo.loadTrash), hasLength(1));

      await tapAndSettle(tester, find.byTooltip('Endgültig löschen'));
      await tapAndSettle(tester, find.widgetWithText(FilledButton, 'Endgültig löschen'));
      expect(find.textContaining('Der Papierkorb ist leer.'), findsOneWidget);
      expect(await tester.runAsync(() => repo.loadTrip(demo.trip.id)), isNull);
    });

    testWidgets('emptying the trash removes all trips', (tester) async {
      await tester.runAsync(() async {
        final other = demoSriLanka();
        await repo.putTripData(other);
        await repo.trashTrip(other.trip.id);
      });
      await deleteDemo(tester);
      await openTrash(tester);
      await tapAndSettle(tester, find.text('Leeren'));
      expect(find.textContaining('2 Reisen werden'), findsOneWidget);
      await tapAndSettle(tester, find.widgetWithText(FilledButton, 'Endgültig löschen'));
      expect(await tester.runAsync(repo.loadTrash), isEmpty);
    });
  });

  group('editors', () {
    /// A page with an "open" button that runs [open].
    Future<void> pumpHost(WidgetTester tester, Future<void> Function(BuildContext, TripData) open) async {
      await pump(
        tester,
        Scaffold(
          body: Consumer(builder: (context, ref, _) {
            final data = ref.watch(tripDataProvider(demo.trip.id)).value;
            return data == null
                ? const Text('loading')
                : TextButton(onPressed: () => open(context, data), child: const Text('open'));
          }),
        ),
      );
      await tapAndSettle(tester, find.text('open'));
    }

    Future<TripData> load() async => (await repo.loadTrip(demo.trip.id))!;

    testWidgets('deleting an item offers undo', (tester) async {
      final paris = demo.items.firstWhere((i) => i.title == 'Paris');
      await pumpHost(tester, (context, data) => openItemEditor(context, data, item: data.item(paris.id)));
      await tapAndSettle(tester, find.byTooltip('Löschen'));
      await tapAndSettle(tester, find.widgetWithText(FilledButton, 'Löschen'));
      expect(find.text('open'), findsOneWidget);
      expect(find.text('„Paris“ gelöscht'), findsOneWidget);
      expect((await tester.runAsync(load))!.item(paris.id), isNull);

      await tapAndSettle(tester, find.text('Rückgängig'));
      expect((await tester.runAsync(load))!.item(paris.id), isNotNull);
    });

    testWidgets('deleting a note offers undo', (tester) async {
      final card = demo.cards.firstWhere((c) => c.type == CardType.note);
      await pumpHost(tester, (context, data) => openCardEditor(context, data, card: card));
      await tapAndSettle(tester, find.byType(PopupMenuButton<String>));
      await tapAndSettle(tester, find.text('Löschen'));
      await tapAndSettle(tester, find.widgetWithText(FilledButton, 'Löschen'));
      expect(find.text('open'), findsOneWidget);
      expect(find.text('Notiz gelöscht'), findsOneWidget);
      expect((await tester.runAsync(load))!.cards.where((c) => c.id == card.id), isEmpty);

      await tapAndSettle(tester, find.text('Rückgängig'));
      expect((await tester.runAsync(load))!.cards.where((c) => c.id == card.id), hasLength(1));
    });
  });
}
