import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/data/attachment_store.dart';
import 'package:travel_planner/data/db.dart';
import 'package:travel_planner/data/repository.dart';
import 'package:travel_planner/domain/demo.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/state/providers.dart';
import 'package:travel_planner/ui/editor/card_editor_page.dart';
import 'package:travel_planner/ui/keep/notes_view.dart';
import 'package:travel_planner/ui/trip/trip_page.dart';

import '../l10n_test_utils.dart';

void main() {
  late Repository repo;
  late ProviderContainer container;
  late TripData demo;
  late NoteCard packing;

  setUp(() {
    repo = Repository(AppDatabase(NativeDatabase.memory()), AttachmentStore(Directory.systemTemp));
    container = ProviderContainer(overrides: [repositoryProvider.overrideWithValue(repo)]);
    demo = demoInterrail();
    packing = demo.cards.firstWhere((c) => c.type == CardType.checklist);
  });

  tearDown(() async {
    container.dispose();
    await repo.close();
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pumpAndSettle();
  }

  /// Hosts [body] with the stored demo trip; [body] gets the live data.
  Future<void> pumpHost(WidgetTester tester, Widget Function(BuildContext, WidgetRef, TripData) body,
      {List<TripData> others = const []}) async {
    await tester.runAsync(() async {
      await repo.putTripData(demo);
      for (final o in others) {
        await repo.putTripData(o);
      }
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: testApp(
        home: Scaffold(
          body: Consumer(builder: (context, ref, _) {
            final data = ref.watch(tripDataProvider(demo.trip.id)).value;
            return data == null ? const Text('loading') : body(context, ref, data);
          }),
        ),
      ),
    ));
    await settle(tester);
  }

  Future<NoteCard> stored(String id) async => (await repo.loadTrip(demo.trip.id))!.cards.firstWhere((c) => c.id == id);
  List<String> undoLabels() => [for (final e in container.read(undoProvider)[demo.trip.id] ?? const []) e.label];
  Widget opener(BuildContext context, VoidCallback onTap) => TextButton(onPressed: onTap, child: const Text('open'));

  group('ticking in the notes grid', () {
    testWidgets('ticks an entry as one undoable step', (tester) async {
      await pumpHost(tester, (_, _, data) => NotesView(data: data));
      expect(find.text('Adapter'), findsOneWidget);

      await tester.tap(find.text('Adapter'));
      await settle(tester);
      expect((await tester.runAsync(() => stored(packing.id)))!.checklist.firstWhere((e) => e.text == 'Adapter').done,
          isTrue);
      expect(undoLabels(), ['„Adapter“ abgehakt']);
      expect(find.text('Adapter'), findsNothing);
      expect(find.text('+ 2 erledigt'), findsOneWidget);
      // The tap did not open the editor.
      expect(find.byType(CardEditorPage), findsNothing);

      await tester.tap(find.text('Rückgängig'));
      await settle(tester);
      expect((await tester.runAsync(() => stored(packing.id)))!.checklist.firstWhere((e) => e.text == 'Adapter').done,
          isFalse);
      expect(find.text('Adapter'), findsOneWidget);
    });

    testWidgets('entries are announced as unchecked checkboxes', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHost(tester, (_, _, data) => NotesView(data: data));
      final adapter = packing.checklist.firstWhere((e) => e.text == 'Adapter');
      final node = tester.getSemantics(find.byKey(ValueKey('tick-${adapter.id}')));
      expect(node, isSemantics(hasCheckedState: true, isChecked: false));
      handle.dispose();
    });

    testWidgets('tapping the card elsewhere still opens the editor', (tester) async {
      await pumpHost(tester, (_, _, data) => NotesView(data: data));
      await tester.tap(find.text('Packing list'));
      await settle(tester);
      expect(find.byType(CardEditorPage), findsOneWidget);
    });
  });

  group('packing list from the add sheet', () {
    testWidgets('combines templates into a new checklist', (tester) async {
      await pumpHost(tester, (context, ref, data) => opener(context, () => showAddSheet(context, ref, data)));
      await tester.tap(find.text('open'));
      await settle(tester);
      await tester.tap(find.text('Packliste'));
      await settle(tester);

      expect(find.text('Vorlagen'), findsOneWidget);
      final create = find.widgetWithText(FilledButton, 'Liste erstellen');
      expect(tester.widget<FilledButton>(create).onPressed, isNull);
      await tester.tap(find.text('Strand'));
      await tester.pump();
      await tester.tap(find.text('Wandern'));
      await tester.pump();
      final count = de.packingTemplateBeachItems.split('|').length + de.packingTemplateHikingItems.split('|').length - 1;
      expect(find.text('$count Einträge'), findsOneWidget);

      await tester.tap(create);
      await settle(tester);
      expect(find.byType(CardEditorPage), findsOneWidget);
      expect(find.text('Sonnencreme'), findsOneWidget);

      await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await settle(tester);
      final data = (await tester.runAsync(() => repo.loadTrip(demo.trip.id)))!;
      final created = data.cards.firstWhere((c) => c.title == 'Packliste · Strand, Wandern');
      expect(created.type, CardType.checklist);
      expect(created.checklist, hasLength(count));
      expect(created.checklist.every((e) => !e.done), isTrue);
      expect(undoLabels(), ['„Packliste · Strand, Wandern“ angelegt']);
    });

    testWidgets('copies a list from another trip, unticked', (tester) async {
      final other = demoSriLanka();
      final prep = other.cards.firstWhere((c) => c.type == CardType.checklist);
      final ticked = prep.copyWith(checklist: [for (final e in prep.checklist) e.copyWith(done: true)]);
      final others = [
        TripData(trip: other.trip, items: other.items, cards: [ticked], edges: const [], attachments: const []),
      ];
      await pumpHost(tester, (context, ref, data) => opener(context, () => showAddSheet(context, ref, data)),
          others: others);
      await tester.tap(find.text('open'));
      await settle(tester);
      await tester.tap(find.text('Packliste'));
      await settle(tester);

      expect(find.text('Liste aus anderer Reise übernehmen'), findsOneWidget);
      // The trip's own packing list is not offered.
      expect(find.text('Packing list'), findsNothing);
      expect(find.text('${other.trip.title} · ${prep.checklist.length} Einträge'), findsOneWidget);
      await tester.tap(find.text('Preparation'));
      await settle(tester);
      expect(find.byType(CardEditorPage), findsOneWidget);
      await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await settle(tester);

      final data = (await tester.runAsync(() => repo.loadTrip(demo.trip.id)))!;
      final copy = data.cards.firstWhere((c) => c.title == 'Preparation');
      expect(copy.id, isNot(prep.id));
      expect([for (final e in copy.checklist) e.text], [for (final e in prep.checklist) e.text]);
      expect(copy.checklist.every((e) => !e.done), isTrue);
      // The source stays as it was.
      final source = (await tester.runAsync(() => repo.loadTrip(other.trip.id)))!.cards.single;
      expect(source.checklist.every((e) => e.done), isTrue);
    });

    testWidgets('says so when no other trip has a checklist', (tester) async {
      await pumpHost(tester, (context, ref, data) => opener(context, () => showAddSheet(context, ref, data)));
      await tester.tap(find.text('open'));
      await settle(tester);
      await tester.tap(find.text('Packliste'));
      await settle(tester);
      expect(find.text('In anderen Reisen gibt es noch keine Checklisten.'), findsOneWidget);
    });
  });

  group('checklist editor', () {
    Future<void> openPacking(WidgetTester tester) async {
      await pumpHost(tester,
          (context, _, data) => opener(context, () => openCardEditor(context, data, card: data.cards.firstWhere((c) => c.id == packing.id))));
      await tester.tap(find.text('open'));
      await settle(tester);
    }

    Future<void> back(WidgetTester tester) async {
      await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await settle(tester);
    }

    testWidgets('adds template entries that are not on the list yet', (tester) async {
      await openPacking(tester);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await settle(tester);
      await tester.tap(find.text('Aus Vorlage oder Reise ergänzen …'));
      await settle(tester);
      expect(find.text('Einträge hinzufügen'), findsOneWidget);
      await tester.tap(find.text('Strand'));
      await tester.pump();
      await tester.tap(find.text('Einträge hinzufügen'));
      await settle(tester);
      final beach = de.packingTemplateBeachItems.split('|');
      expect(find.text('${beach.length} Einträge hinzugefügt'), findsOneWidget);

      await back(tester);
      final card = (await tester.runAsync(() => stored(packing.id)))!;
      expect(card.title, 'Packing list');
      expect([for (final e in card.checklist) e.text], [...packing.checklist.map((e) => e.text), ...beach]);
      expect(undoLabels(), ['„Packing list“ geändert']);
    });

    testWidgets('dragging the handle reorders open entries', (tester) async {
      await openPacking(tester);
      final open = [for (final e in packing.checklist) if (!e.done) e];
      final first = open.first;
      final handle = find.byKey(ValueKey('drag-${first.id}'));
      final rowHeight = tester.getSize(find.byKey(ValueKey(first.id))).height;
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(const Duration(milliseconds: 100));
      for (var k = 0; k < 10; k++) {
        await gesture.moveBy(Offset(0, rowHeight * 1.1 / 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      await back(tester);

      final card = (await tester.runAsync(() => stored(packing.id)))!;
      final openIds = [for (final e in card.checklist) if (!e.done) e.id];
      expect(openIds, [open[1].id, first.id, ...open.skip(2).map((e) => e.id)]);
      // The ticked entry kept its slot.
      expect(card.checklist.first.done, isTrue);
    });

    testWidgets('screen readers can move entries up and down', (tester) async {
      final handle = tester.ensureSemantics();
      await openPacking(tester);
      final open = [for (final e in packing.checklist) if (!e.done) e];
      final node = tester.getSemantics(find.byKey(ValueKey('drag-${open[1].id}')));
      int idOf(String label) => CustomSemanticsAction.getIdentifier(CustomSemanticsAction(label: label));
      final semanticsNode = _withAction(node, idOf('Nach oben'));
      expect(semanticsNode, isNotNull);
      semanticsNode!.owner!.performAction(semanticsNode.id, SemanticsAction.customAction, idOf('Nach oben'));
      await tester.pumpAndSettle();
      await back(tester);
      final card = (await tester.runAsync(() => stored(packing.id)))!;
      expect([for (final e in card.checklist) if (!e.done) e.id].take(2), [open[1].id, open[0].id]);
      handle.dispose();
    });
  });
}

/// [node] or the closest ancestor that carries custom action [id].
SemanticsNode? _withAction(SemanticsNode node, int id) {
  for (SemanticsNode? n = node; n != null; n = n.parent) {
    if (n.getSemanticsData().customSemanticsActionIds?.contains(id) ?? false) return n;
  }
  return null;
}
