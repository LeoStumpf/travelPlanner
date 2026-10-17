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

  /// A page with an "open" button that runs [open]; returns once the editor is shown.
  Future<void> pumpHost(WidgetTester tester, Future<void> Function(BuildContext, TripData) open) async {
    await tester.runAsync(() => repo.putTripData(demo));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(builder: (context, ref, _) {
            final data = ref.watch(tripDataProvider(demo.trip.id)).value;
            return data == null
                ? const Text('loading')
                : TextButton(onPressed: () => open(context, data), child: const Text('open'));
          }),
        ),
      ),
    ));
    await settle(tester);
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  Future<void> back(WidgetTester tester) async {
    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await settle(tester);
  }

  Future<TripData> load() async => (await repo.loadTrip(demo.trip.id))!;
  List<String> undoLabels() => [for (final e in container.read(undoProvider)[demo.trip.id] ?? const []) e.label];

  group('item editor', () {
    late PlanItem paris;
    setUp(() => paris = demo.items.firstWhere((i) => i.title == 'Paris'));

    Future<void> openParis(WidgetTester tester) =>
        pumpHost(tester, (context, data) => openItemEditor(context, data, item: data.item(paris.id)));

    testWidgets('leaves without asking when nothing changed', (tester) async {
      await openParis(tester);
      expect(find.text('Titel'), findsOneWidget);
      await back(tester);
      expect(find.text('Ungespeicherte Änderungen'), findsNothing);
      expect(find.text('open'), findsOneWidget);
      expect(undoLabels(), isEmpty);
    });

    testWidgets('asks on back; keep editing stays, discard leaves without saving', (tester) async {
      await openParis(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Paris'), 'Paris Nord');
      await back(tester);
      expect(find.text('Ungespeicherte Änderungen'), findsOneWidget);

      await tester.tap(find.text('Weiter bearbeiten'));
      await settle(tester);
      expect(find.text('Ungespeicherte Änderungen'), findsNothing);
      expect(find.text('Paris Nord'), findsOneWidget, reason: 'still in the editor with the edit');

      await back(tester);
      await tester.tap(find.text('Verwerfen'));
      await settle(tester);
      expect(find.text('open'), findsOneWidget);
      final after = (await tester.runAsync(load))!;
      expect(after.item(paris.id)!.title, 'Paris');
      expect(undoLabels(), isEmpty);
    });

    testWidgets('save in the dialog stores the edit', (tester) async {
      await openParis(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Paris'), 'Paris Nord');
      await back(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
      await settle(tester);
      expect(find.text('open'), findsOneWidget);
      final after = (await tester.runAsync(load))!;
      expect(after.item(paris.id)!.title, 'Paris Nord');
      expect(undoLabels(), ['„Paris Nord“ geändert']);
    });

    testWidgets('a double tap on save stores once and leaves only the editor', (tester) async {
      await openParis(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Paris'), 'Paris Nord');
      final save = find.widgetWithText(TextButton, 'Speichern');
      await tester.tap(save);
      await tester.tap(save);
      await settle(tester);
      expect(find.text('open'), findsOneWidget, reason: 'the host page must not be popped too');
      expect(undoLabels(), ['„Paris Nord“ geändert']);
    });

    testWidgets('changing a non-text field also counts as a change', (tester) async {
      await openParis(tester);
      await tester.tap(find.text('Fixer Termin'));
      await settle(tester);
      await back(tester);
      expect(find.text('Ungespeicherte Änderungen'), findsOneWidget);
    });

    testWidgets('a new item without input closes silently', (tester) async {
      await pumpHost(tester, (context, data) => openItemEditor(context, data, newKind: ItemKind.activity));
      await back(tester);
      expect(find.text('Ungespeicherte Änderungen'), findsNothing);
      expect(find.text('open'), findsOneWidget);
      final after = (await tester.runAsync(load))!;
      expect(after.items, hasLength(demo.items.length));
    });
  });

  group('card editor', () {
    Future<void> openNewNote(WidgetTester tester) =>
        pumpHost(tester, (context, data) => openCardEditor(context, data, newType: CardType.note));

    Future<void> pause(WidgetTester tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await settle(tester);
    }

    Future<void> resume(WidgetTester tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
    }

    testWidgets('a new note is saved when the app goes to the background', (tester) async {
      await openNewNote(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Notiz'), 'Sonnencreme kaufen');
      await pause(tester);
      var after = (await tester.runAsync(load))!;
      expect(after.cards.where((c) => c.text == 'Sonnencreme kaufen'), hasLength(1));
      expect(undoLabels(), ['Notiz angelegt']);

      // Pausing again without changes adds nothing.
      await resume(tester);
      await pause(tester);
      expect(undoLabels(), hasLength(1));

      // Further edits are saved on leaving, as a change of the existing card.
      await resume(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Sonnencreme kaufen'), 'Sonnencreme und Hut');
      await back(tester);
      after = (await tester.runAsync(load))!;
      expect(after.cards.where((c) => c.text.startsWith('Sonnencreme')).map((c) => c.text), ['Sonnencreme und Hut']);
      expect(after.cards, hasLength(demo.cards.length + 1));
      expect(undoLabels(), ['Notiz angelegt', 'Notiz geändert']);
    });

    testWidgets('an empty new note is not stored in the background', (tester) async {
      await openNewNote(tester);
      await pause(tester);
      final after = (await tester.runAsync(load))!;
      expect(after.cards, hasLength(demo.cards.length));
      expect(undoLabels(), isEmpty);
    });

    testWidgets('deleting a new note after a background save removes it', (tester) async {
      await openNewNote(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Notiz'), 'Wegwerfen');
      await pause(tester);
      await resume(tester);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await settle(tester);
      await tester.tap(find.text('Löschen'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Löschen'));
      await settle(tester);
      expect(find.text('open'), findsOneWidget);
      final after = (await tester.runAsync(load))!;
      expect(after.cards.where((c) => c.text == 'Wegwerfen'), isEmpty);
    });

    testWidgets('an existing note is saved in the background without extra undo steps on leaving', (tester) async {
      final card = demo.cards.firstWhere((c) => c.type == CardType.note);
      await pumpHost(tester, (context, data) => openCardEditor(context, data, card: card));
      await tester.enterText(find.widgetWithText(TextField, card.text), 'Neu geschrieben');
      await pause(tester);
      var after = (await tester.runAsync(load))!;
      expect(after.cards.firstWhere((c) => c.id == card.id).text, 'Neu geschrieben');
      await resume(tester);
      await back(tester);
      after = (await tester.runAsync(load))!;
      expect(after.cards.firstWhere((c) => c.id == card.id).text, 'Neu geschrieben');
      expect(undoLabels(), hasLength(1));
    });
  });
}
