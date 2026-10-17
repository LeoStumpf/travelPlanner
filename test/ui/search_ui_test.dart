import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/data/attachment_store.dart';
import 'package:travel_planner/data/db.dart';
import 'package:travel_planner/data/repository.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/state/providers.dart';
import 'package:travel_planner/ui/editor/card_editor_page.dart';
import 'package:travel_planner/ui/keep/notes_view.dart';
import 'package:travel_planner/ui/search/search_page.dart';
import 'package:travel_planner/ui/trip/trip_page.dart';
import 'package:travel_planner/ui/trips/trips_page.dart';

import '../l10n_test_utils.dart';

final _t0 = DateTime(2026, 1, 1);

final _lanka = TripData(
  trip: Trip(id: 'lanka', title: 'Sri Lanka', createdAt: _t0.add(const Duration(days: 2))),
  items: [
    PlanItem(
        id: 'kandy', tripId: 'lanka', kind: ItemKind.stay, title: 'Kandy', start: 0, end: 2 * 1440, createdAt: _t0),
    PlanItem(
      id: 'train',
      tripId: 'lanka',
      kind: ItemKind.transport,
      mode: TransportMode.train,
      title: 'Zug nach Ella',
      bookingRef: 'PNR X7Q2',
      fromId: 'kandy',
      start: 2 * 1440 + 600,
      end: 2 * 1440 + 900,
      createdAt: _t0,
    ),
  ],
  cards: [
    NoteCard(id: 'food', tripId: 'lanka', type: CardType.note, title: 'Essen', text: 'Kottu im Café Aroma', createdAt: _t0),
  ],
);

final _alps = TripData(
  trip: Trip(id: 'alps', title: 'Alpen', createdAt: _t0),
  items: [
    PlanItem(id: 'hut', tripId: 'alps', kind: ItemKind.activity, title: 'Hüttenwanderung', notes: 'Café oben', createdAt: _t0),
  ],
);

void main() {
  late Repository repo;
  late ProviderContainer container;

  setUp(() {
    repo = Repository(AppDatabase(NativeDatabase.memory()), AttachmentStore(Directory.systemTemp));
    container = ProviderContainer(overrides: [repositoryProvider.overrideWithValue(repo)]);
  });

  tearDown(() async {
    container.dispose();
    await repo.close();
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pumpAndSettle();
  }

  Future<void> pump(WidgetTester tester, Widget home) async {
    await tester.runAsync(() async {
      await repo.putTripData(_lanka);
      await repo.putTripData(_alps);
    });
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: testApp(home: home)));
    await settle(tester);
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    await settle(tester);
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const ValueKey('search-field')), text);
    await settle(tester);
  }

  Finder appBarSearch() => find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.search));
  Finder appBarTitle(String t) => find.descendant(of: find.byType(AppBar), matching: find.text(t));

  group('from the trip list', () {
    testWidgets('explains what it searches before anything is typed', (tester) async {
      await pump(tester, const TripsPage());
      await tap(tester, appBarSearch());
      expect(find.byType(SearchPage), findsOneWidget);
      expect(find.textContaining('Durchsucht Titel, Orte, Notizen'), findsOneWidget);
    });

    testWidgets('groups hits by trip, accent-insensitive', (tester) async {
      await pump(tester, const TripsPage());
      await tap(tester, appBarSearch());
      await type(tester, 'cafe');

      expect(find.text('Sri Lanka'), findsOneWidget);
      expect(find.text('Alpen'), findsOneWidget);
      expect(find.text('1 Treffer'), findsNWidgets(2));
      expect(find.byKey(const ValueKey('hit-food')), findsOneWidget);
      expect(find.byKey(const ValueKey('hit-hut')), findsOneWidget);
      expect(find.textContaining('Notizen: Café oben', findRichText: true), findsOneWidget);
      // Newest trip first.
      expect(tester.getTopLeft(find.text('Sri Lanka')).dy, lessThan(tester.getTopLeft(find.text('Alpen')).dy));
    });

    testWidgets('finds ticket details and opens the trip with the item sheet', (tester) async {
      await pump(tester, const TripsPage());
      await tap(tester, appBarSearch());
      await type(tester, 'x7q2');

      expect(find.textContaining('Buchungsnummer: PNR X7Q2', findRichText: true), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('hit-train')));

      expect(find.byType(SearchPage), findsNothing);
      expect(find.byType(TripPage), findsOneWidget);
      expect(appBarTitle('Sri Lanka'), findsOneWidget);
      expect(container.read(tripUiProvider).selectedId, 'train');
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Zug nach Ella')), findsOneWidget);
    });

    testWidgets('a note opens in the card editor', (tester) async {
      await pump(tester, const TripsPage());
      await tap(tester, appBarSearch());
      await type(tester, 'kottu');
      await tap(tester, find.byKey(const ValueKey('hit-food')));

      expect(find.byType(CardEditorPage), findsOneWidget);
      // The trip lies under the editor.
      expect(find.byType(TripPage, skipOffstage: false), findsOneWidget);
      expect(container.read(tripUiProvider).view, TripView.notes);
    });

    testWidgets('a trip whose title matches opens from its header', (tester) async {
      await pump(tester, const TripsPage());
      await tap(tester, appBarSearch());
      await type(tester, 'alpen');
      expect(find.text('Reise öffnen'), findsOneWidget);

      await tap(tester, find.text('Alpen'));
      expect(find.byType(TripPage), findsOneWidget);
      expect(appBarTitle('Alpen'), findsOneWidget);
    });

    testWidgets('says when nothing matches and clears', (tester) async {
      await pump(tester, const TripsPage());
      await tap(tester, appBarSearch());
      await type(tester, 'zzz');
      expect(find.text('Keine Treffer für „zzz“'), findsOneWidget);

      await tap(tester, find.byTooltip('Suche leeren'));
      expect(find.textContaining('Durchsucht Titel'), findsOneWidget);
    });

    testWidgets('trashed trips are not searched', (tester) async {
      await pump(tester, const TripsPage());
      await tester.runAsync(() => repo.trashTrip('alps'));
      await tap(tester, appBarSearch());
      await type(tester, 'cafe');
      expect(find.text('Alpen'), findsNothing);
      expect(find.text('Sri Lanka'), findsOneWidget);
    });
  });

  group('inside a trip', () {
    Future<void> openLankaSearch(WidgetTester tester) async {
      await pump(tester, const TripsPage());
      await tap(tester, find.text('Sri Lanka'));
      expect(find.byType(TripPage), findsOneWidget);
      await tap(tester, appBarSearch());
    }

    testWidgets('searches this trip and can widen to all trips', (tester) async {
      await openLankaSearch(tester);
      await type(tester, 'cafe');
      expect(find.byKey(const ValueKey('hit-food')), findsOneWidget);
      expect(find.byKey(const ValueKey('hit-hut')), findsNothing);

      await tap(tester, find.text('Alle Reisen'));
      expect(find.byKey(const ValueKey('hit-hut')), findsOneWidget);
    });

    testWidgets('no hit in this trip offers all trips; a hit there switches trips', (tester) async {
      await openLankaSearch(tester);
      await type(tester, 'hütten');
      expect(find.text('Keine Treffer für „hütten“'), findsOneWidget);

      await tap(tester, find.text('Nichts in dieser Reise – in allen Reisen suchen?'));
      expect(find.byKey(const ValueKey('hit-hut')), findsOneWidget);

      await tap(tester, find.byKey(const ValueKey('hit-hut')));
      expect(find.byType(SearchPage), findsNothing);
      expect(find.byType(TripPage), findsOneWidget);
      expect(appBarTitle('Alpen'), findsOneWidget);
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Hüttenwanderung')), findsOneWidget);
    });

    testWidgets('a hit in the same trip returns to it and shows the sheet', (tester) async {
      await openLankaSearch(tester);
      await type(tester, 'kandy');
      await tap(tester, find.byKey(const ValueKey('hit-kandy')));
      expect(find.byType(SearchPage), findsNothing);
      expect(find.byType(TripPage), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      // Back from the sheet lands on the trip, not on the trip list.
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await settle(tester);
      expect(appBarTitle('Sri Lanka'), findsOneWidget);
    });

    testWidgets('fits a 360 dp wide phone', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openLankaSearch(tester);
      await type(tester, 'PNR X7Q2');
      await tap(tester, find.text('Alle Reisen'));
      expect(find.byKey(const ValueKey('hit-train')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('notes grid', () {
    Future<void> pumpNotes(WidgetTester tester) async {
      await tester.runAsync(() => repo.putTripData(_lanka));
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: testApp(
          home: Scaffold(
            body: Consumer(builder: (context, ref, _) {
              final data = ref.watch(tripDataProvider('lanka')).value;
              return data == null ? const Text('loading') : NotesView(data: data);
            }),
          ),
        ),
      ));
      await settle(tester);
    }

    testWidgets('an empty search result says so instead of the empty-trip text', (tester) async {
      await pumpNotes(tester);
      await tester.enterText(find.byType(SearchBar), 'pizza');
      await settle(tester);
      expect(find.text('Keine Treffer für „pizza“'), findsOneWidget);
      expect(find.textContaining('Sammle hier Ideen'), findsNothing);
    });

    testWidgets('finds notes accent-insensitively, by several words', (tester) async {
      await pumpNotes(tester);
      await tester.enterText(find.byType(SearchBar), 'aroma cafe');
      await settle(tester);
      expect(find.text('Essen'), findsOneWidget);
    });
  });

  testWidgets('highlights the matching parts', (tester) async {
    await tester.pumpWidget(testApp(home: const Scaffold(body: HighlightedText('Café Central', terms: ['cafe']))));
    final rich = tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
    final spans = rich.children!.cast<TextSpan>();
    expect(spans.map((s) => s.text), ['Café', ' Central']);
    expect(spans.first.style?.fontWeight, FontWeight.bold);
    expect(spans.last.style, isNull);
  });
}
