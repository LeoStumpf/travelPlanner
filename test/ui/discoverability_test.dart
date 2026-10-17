import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_planner/data/attachment_store.dart';
import 'package:travel_planner/data/db.dart';
import 'package:travel_planner/data/repository.dart';
import 'package:travel_planner/domain/demo.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/domain/scheduler.dart';
import 'package:travel_planner/domain/time.dart';
import 'package:travel_planner/state/hints.dart';
import 'package:travel_planner/state/providers.dart';
import 'package:travel_planner/ui/canvas/canvas_view.dart';
import 'package:travel_planner/ui/common/item_sheet.dart';
import 'package:travel_planner/ui/common/l10n.dart';
import 'package:travel_planner/ui/timeline/timeline_view.dart';
import 'package:travel_planner/ui/trip/trip_page.dart';

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

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pumpAndSettle();
  }

  Future<TripData> load() async => (await repo.loadTrip(demo.trip.id))!;
  PlanItem byTitle(TripData d, String t) => d.items.firstWhere((i) => i.title == t);
  List<String> undoLabels() => [for (final e in container.read(undoProvider)[demo.trip.id] ?? const []) e.label];

  /// Hosts [body] (built from the live trip data) on a big screen.
  Future<void> pumpHost(WidgetTester tester, Widget Function(BuildContext, WidgetRef, TripData) body,
      {Size size = const Size(1600, 1000)}) async {
    await tester.runAsync(() => repo.putTripData(demo));
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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

  group('one-time hints', () {
    test('dismissals are stored in shared prefs and survive a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c1 = ProviderContainer(overrides: [hintPrefsProvider.overrideWithValue(prefs)]);
      addTearDown(c1.dispose);
      expect(c1.read(hintsProvider), isEmpty);
      c1.read(hintsProvider.notifier).dismiss(Hint.map);
      expect(prefs.getStringList('seenHints'), ['map']);

      final c2 = ProviderContainer(overrides: [hintPrefsProvider.overrideWithValue(prefs)]);
      addTearDown(c2.dispose);
      expect(c2.read(hintsProvider), {Hint.map});
      c2.read(hintsProvider.notifier).resetAll();
      expect(c2.read(hintsProvider), isEmpty);
      expect(prefs.getStringList('seenHints'), isEmpty);
    });

    testWidgets('the timeline explains its gestures until "Verstanden"', (tester) async {
      await pumpHost(tester, (context, ref, data) => TimelineView(data: data));
      expect(find.text(de.hintTimeline), findsOneWidget);
      await tester.tap(find.text('Verstanden'));
      await tester.pump();
      expect(find.text(de.hintTimeline), findsNothing);
      expect(container.read(hintsProvider), {Hint.timeline});

      // Reset (trip list menu) shows it again.
      container.read(hintsProvider.notifier).resetAll();
      await tester.pump();
      expect(find.text(de.hintTimeline), findsOneWidget);
    });

    testWidgets('the canvas hint gives way to the connect instructions', (tester) async {
      await pumpHost(tester, (context, ref, data) => CanvasView(data: data));
      expect(find.text(de.hintCanvas), findsOneWidget);
      await tester.tap(find.byTooltip('Verbinden'));
      await tester.pump();
      expect(find.text(de.hintCanvas), findsNothing);
      expect(find.textContaining('Verbinden: tippe'), findsOneWidget);
    });
  });

  testWidgets('hint banners and quick actions fit a 360 dp phone', (tester) async {
    await pumpHost(
      tester,
      size: const Size(360, 740),
      (context, ref, data) => Column(children: [
        TextButton(
          onPressed: () => showItemSheet(context, ref, demo.trip.id, byTitle(data, 'Louvre').id),
          child: const Text('open'),
        ),
        Expanded(child: TimelineView(data: data)),
      ]),
    );
    expect(find.text(de.hintTimeline), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('open'));
    await settle(tester);
    expect(find.byKey(const ValueKey('quick-delete')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('item sheet quick actions', () {
    Future<void> openSheet(WidgetTester tester, String title) async {
      await pumpHost(
        tester,
        (context, ref, data) => TextButton(
          onPressed: () => showItemSheet(context, ref, demo.trip.id, byTitle(data, title).id),
          child: const Text('open'),
        ),
      );
      await tester.tap(find.text('open'));
      await settle(tester);
    }

    ActionChip chip(WidgetTester tester, String key) => tester.widget<ActionChip>(find.byKey(ValueKey(key)));

    testWidgets('"Gebucht" toggles the status both ways, undoable', (tester) async {
      await openSheet(tester, 'Louvre');
      await tester.tap(find.byKey(const ValueKey('quick-booked')));
      await settle(tester);
      expect(byTitle(await load(), 'Louvre').status, ItemStatus.booked);

      await tester.tap(find.byKey(const ValueKey('quick-booked')));
      await settle(tester);
      expect(byTitle(await load(), 'Louvre').status, ItemStatus.planned);
      expect(undoLabels(), ['„Louvre“ als gebucht markiert', '„Louvre“ nicht mehr gebucht']);
    });

    testWidgets('"Fix" toggles fixed and disables the day shifts', (tester) async {
      await openSheet(tester, 'Louvre');
      expect(chip(tester, 'quick-later').onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey('quick-fixed')));
      await settle(tester);
      expect(byTitle(await load(), 'Louvre').fixed, isTrue);
      expect(undoLabels(), ['„Louvre“ fixiert']);
      expect(chip(tester, 'quick-later').onPressed, isNull);
      expect(chip(tester, 'quick-earlier').onPressed, isNull);
      expect(find.byIcon(Icons.lock), findsWidgets);
    });

    testWidgets('"+1 Tag" ripples in the current shift mode', (tester) async {
      final before = demo;
      await openSheet(tester, 'Lyon');
      await tester.tap(find.byKey(const ValueKey('quick-later')));
      await settle(tester);
      var after = await load();
      expect(byTitle(after, 'Lyon').start, byTitle(before, 'Lyon').start! + minutesPerDay);
      // "Alles danach": Barcelona follows, the fixed flight home stays.
      expect(byTitle(after, 'Barcelona').start, byTitle(before, 'Barcelona').start! + minutesPerDay);
      const flight = DemoTexts();
      expect(byTitle(after, flight.flightHomeValencia).start, byTitle(before, flight.flightHomeValencia).start);
      expect(undoLabels(), ['„Lyon“ +1 Tag']);

      // One undo step reverts the whole ripple.
      await tester.runAsync(() => container.read(planActionsProvider).undo(demo.trip.id));
      await settle(tester);

      container.read(tripUiProvider.notifier).setShiftMode(ShiftMode.single);
      await tester.tap(find.byKey(const ValueKey('quick-earlier')));
      await settle(tester);
      after = await load();
      expect(byTitle(after, 'Lyon').start, byTitle(before, 'Lyon').start! - minutesPerDay);
      expect(byTitle(after, 'Barcelona').start, byTitle(before, 'Barcelona').start);
      expect(undoLabels(), ['„Lyon“ −1 Tag']);
    });

    testWidgets('unscheduled items get no day shifts', (tester) async {
      await openSheet(tester, 'Avignon');
      expect(find.byKey(const ValueKey('quick-later')), findsNothing);
      expect(find.byKey(const ValueKey('quick-booked')), findsOneWidget);
    });

    testWidgets('"Löschen" asks, closes the sheet and offers undo', (tester) async {
      await openSheet(tester, 'Louvre');
      await tester.tap(find.byKey(const ValueKey('quick-delete')));
      await tester.pumpAndSettle();
      expect(find.text('„Louvre“ löschen?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Löschen'));
      await settle(tester);

      expect((await load()).items.where((i) => i.title == 'Louvre'), isEmpty);
      expect(find.byKey(const ValueKey('quick-delete')), findsNothing);
      expect(find.text('„Louvre“ gelöscht'), findsOneWidget);
      await tester.tap(find.text('Rückgängig'));
      await settle(tester);
      expect((await load()).items.where((i) => i.title == 'Louvre'), hasLength(1));
    });

    testWidgets('jump buttons skip the current view and unscheduled items', (tester) async {
      await openSheet(tester, 'Louvre');
      // Default view is the timeline.
      expect(find.widgetWithText(OutlinedButton, 'Zeitplan'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Karte'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Canvas'), findsOneWidget);

      container.read(tripUiProvider.notifier).setView(TripView.canvas);
      await tester.pump();
      expect(find.widgetWithText(OutlinedButton, 'Zeitplan'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Canvas'), findsNothing);
    });

    testWidgets('no timeline jump for an unscheduled item', (tester) async {
      container.read(tripUiProvider.notifier).setView(TripView.map);
      await openSheet(tester, 'Avignon');
      expect(find.widgetWithText(OutlinedButton, 'Zeitplan'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Canvas'), findsOneWidget);
    });
  });

  group('layer bar', () {
    testWidgets('labels carry no layer digits; the state is visible', (tester) async {
      await pumpHost(tester, (context, ref, data) => LayerBar(data: data));
      for (final k in ItemKind.values) {
        expect(find.text(de.kind(k)), findsOneWidget);
        expect(find.text('${k.layer} ${de.kind(k)}'), findsNothing);
      }
      FilterChip chip() => tester.widget<FilterChip>(find.byKey(const ValueKey('layer-transport')));
      expect(chip().selected, isTrue);
      expect(chip().side!.color, isNot(Colors.transparent));
      expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);

      await tester.tap(find.byKey(const ValueKey('layer-transport')));
      await tester.pump();
      expect(chip().selected, isFalse);
      expect(container.read(tripUiProvider).layers.contains(ItemKind.transport), isFalse);
      // Hidden layers swap their icon for a crossed-out eye.
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });
  });
}
