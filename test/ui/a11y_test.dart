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
import 'package:travel_planner/domain/time.dart';
import 'package:travel_planner/l10n/app_localizations.dart';
import 'package:travel_planner/state/offline_map.dart';
import 'package:travel_planner/state/providers.dart';
import 'package:travel_planner/ui/canvas/canvas_view.dart';
import 'package:travel_planner/ui/common/a11y.dart';
import 'package:travel_planner/ui/common/dashed_border.dart';
import 'package:travel_planner/ui/common/style.dart';
import 'package:travel_planner/ui/common/theme.dart';
import 'package:travel_planner/ui/editor/card_editor_page.dart';
import 'package:travel_planner/ui/editor/time_fields.dart';
import 'package:travel_planner/ui/map/map_view.dart';
import 'package:travel_planner/ui/timeline/timeline_view.dart';
import 'package:travel_planner/ui/trips/trip_settings_dialog.dart';

import '../l10n_test_utils.dart';
import '../offline_fake.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  late Repository repo;
  late ProviderContainer container;
  late TripData demo;

  setUp(() {
    repo = Repository(AppDatabase(NativeDatabase.memory()), AttachmentStore(Directory.systemTemp));
    container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(repo),
      nativeMapProvider.overrideWithValue(false),
      offlineMapStoreProvider.overrideWithValue(FakeOfflineStore()),
      mapReachabilityProvider.overrideWithValue(() async => true),
    ]);
    demo = demoSriLanka();
  });

  tearDown(() async {
    container.dispose();
    await repo.close();
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump();
    await tester.pump();
  }

  PlanItem byTitle(TripData d, String t) => d.items.firstWhere((i) => i.title == t);

  /// Hosts [body] (built from the live trip data) in the app theme.
  Future<void> pumpHost(
    WidgetTester tester,
    Widget Function(BuildContext, WidgetRef, TripData) body, {
    Size size = const Size(1600, 1000),
  }) async {
    await tester.runAsync(() => repo.putTripData(demo));
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        locale: testLocale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
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

  SemanticsData semanticsOf(WidgetTester tester, Finder f) => tester.getSemantics(f).getSemanticsData();

  int actionId(String label) => CustomSemanticsAction.getIdentifier(CustomSemanticsAction(label: label));

  group('timeline semantics', () {
    testWidgets('a place block reads as one sentence with day actions', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHost(tester, (c, ref, d) => TimelineView(data: d));
      final kandy = byTitle(demo, 'Kandy');

      final node = find.semantics.byLabel(RegExp(r'^Kandy, Ort, 3 Nächte, '));
      expect(node, findsOne);
      final data = node.evaluate().single.getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.customSemanticsActionIds, containsAll([actionId(de.a11yDayLater), actionId(de.a11yDayEarlier)]));

      // "1 Tag später" moves it like a drag would, as one undo step.
      tester.semantics.performAction(node, SemanticsAction.customAction, args: actionId(de.a11yDayLater));
      await settle(tester);
      final after = await tester.runAsync(() => repo.loadTrip(demo.trip.id));
      expect(after!.item(kandy.id)!.start, kandy.start! + minutesPerDay);
      expect(container.read(undoProvider)[demo.trip.id], hasLength(1));
      handle.dispose();
    });

    testWidgets('fixed items have no move actions; options say so', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHost(tester, (c, ref, d) => TimelineView(data: d));
      final flight = demo.items.firstWhere((i) => i.fixed && i.kind == ItemKind.transport);
      final data = semanticsOf(tester, find.byKey(ValueKey('block-semantics-${flight.id}')));
      expect(data.label, contains(de.fixedChip));
      // (Only the "show details" tap hint, no move actions.)
      expect(data.customSemanticsActionIds ?? const <int>[], isNot(contains(actionId(de.a11yDayLater))));
      expect(data.customSemanticsActionIds ?? const <int>[], isNot(contains(actionId(de.a11yDayEarlier))));

      final option = byTitle(demo, 'Kandy Hills Homestay');
      final o = semanticsOf(tester, find.byKey(ValueKey('block-semantics-${option.id}')));
      expect(o.label, startsWith('Kandy Hills Homestay, Unterkunft, 3 Nächte'));
      expect(o.label, contains(de.statusOption));
      handle.dispose();
    });

    testWidgets('night and transport markers and day headers are labelled', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHost(tester, (c, ref, d) => TimelineView(data: d));

      // Colombo has no bed for its night yet.
      final night = semanticsOf(tester, find.byKey(const ValueKey('missing-night-0')));
      expect(night.label, '${de.nightTitle(de.dayNumber(1), de.dayNumber(2))}: ${de.noAccommodationOptions(0)}');
      expect(night.hasAction(SemanticsAction.tap), isTrue);

      final colombo = byTitle(demo, 'Colombo'), sigiriya = byTitle(demo, 'Sigiriya');
      final gap = semanticsOf(tester, find.byKey(ValueKey('transport-gap-${colombo.id}-${sigiriya.id}')));
      expect(gap.label, de.noTransportBetween('Colombo', 'Sigiriya'));
      expect(gap.hasAction(SemanticsAction.tap), isTrue);

      // Long press on a day header adds something on that day.
      final day = find.semantics.byLabel(de.dayNumber(1));
      expect(day, findsOne);
      expect(day.evaluate().single.getSemanticsData().hasAction(SemanticsAction.longPress), isTrue);
      handle.dispose();
    });

    testWidgets('options and ideas are dashed, not only paler', (tester) async {
      await pumpHost(tester, (c, ref, d) => TimelineView(data: d));
      final option = byTitle(demo, 'Kandy Hills Homestay');
      final kandy = byTitle(demo, 'Kandy');
      bool dashed(String id) => find
          .descendant(of: find.byKey(ValueKey(id)), matching: find.byType(CustomPaint))
          .evaluate()
          .map((e) => e.widget as CustomPaint)
          .any((p) => p.foregroundPainter is DashedBorderPainter);
      expect(dashed(option.id), isTrue);
      expect(dashed(kandy.id), isFalse);
      // The option shows its status icon instead of the kind icon.
      expect(
        find.descendant(of: find.byKey(ValueKey(option.id)), matching: find.byIcon(statusIcon(ItemStatus.option))),
        findsOneWidget,
      );
    });
  });

  group('canvas and map semantics', () {
    testWidgets('canvas nodes are labelled buttons with day actions', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHost(tester, (c, ref, d) => CanvasView(data: d));
      final node = find.semantics.byLabel(RegExp(r'^Kandy, Ort, 3 Nächte, '));
      expect(node, findsOne);
      final data = node.evaluate().single.getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.customSemanticsActionIds, contains(actionId(de.a11yDayEarlier)));
      handle.dispose();
    });

    testWidgets('the map announces its places and offers them as a list', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHost(tester, (c, ref, d) => TripMapView(data: d, active: true), size: const Size(360, 640));
      final placed = demo.items.where((i) => i.kind != ItemKind.transport && i.hasLocation).length;
      expect(find.semantics.byLabel(de.a11yMap(placed)), findsOne);

      await tester.tap(find.byTooltip(de.a11yPlacesList));
      await tester.pumpAndSettle();
      expect(find.text(de.mapPlacesTitle), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      handle.dispose();
    });
  });

  group('touch targets', () {
    testWidgets('note colours are 48 dp, named and selectable', (tester) async {
      final handle = tester.ensureSemantics();
      final card = demo.cards.first;
      await pumpHost(tester, (c, ref, d) => CardEditorPage(tripId: d.trip.id, initial: card, isNew: false),
          size: const Size(400, 900));
      for (final c in noteColors) {
        final size = tester.getSize(find.byKey(ValueKey('note-color-$c')));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      expect(
        tester.getSemantics(find.byKey(const ValueKey('note-color-${0xFFFFF59D}'))),
        isSemantics(label: de.a11yColor(de.colorYellow), isButton: true, isSelected: card.color == 0xFFFFF59D),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('trip colours are 48 dp and pick the colour', (tester) async {
      Trip? result;
      await pumpHost(
        tester,
        (c, ref, d) => TextButton(
          onPressed: () async => result = await showTripSettingsDialog(c, d.trip),
          child: const Text('open'),
        ),
        size: const Size(400, 900),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final blue = find.byKey(ValueKey('trip-color-${tripColors[1]}'));
      expect(tester.getSize(blue).shortestSide, greaterThanOrEqualTo(48));
      await tester.tap(blue);
      await tester.pump();
      await tester.tap(find.text(de.save));
      await tester.pumpAndSettle();
      expect(result!.color, tripColors[1]);
    });

    testWidgets('day chevrons in the time field are 48 dp with a name', (tester) async {
      final handle = tester.ensureSemantics();
      var value = at(2, 600);
      await tester.pumpWidget(testApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (c, set) => MomentField(
              label: 'Beginn',
              tripStart: null,
              value: value,
              onChanged: (v) => set(() => value = v),
            ),
          ),
        ),
      ));
      final later = find.byTooltip(de.a11yDayLater);
      expect(tester.getSize(later).shortestSide, greaterThanOrEqualTo(48));
      expect(tester.getSize(find.byTooltip(de.a11yDayEarlier)).shortestSide, greaterThanOrEqualTo(48));
      await tester.tap(later);
      await tester.pump();
      expect(value, at(3, 600));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });

  group('labels and contrast', () {
    test('the item label names title, kind, nights, status, fixed and conflict', () {
      final kandy = byTitle(demo, 'Kandy');
      final label = itemSemanticsLabel(de, kandy.copyWith(fixed: true), conflict: true);
      expect(label, startsWith('Kandy, Ort, 3 Nächte, '));
      expect(label, endsWith(', ${de.fixedChip}, ${de.a11yConflict}'));
      final idea = byTitle(demo, 'Galle');
      expect(itemSemanticsLabel(en, idea), 'Galle, Place, ${en.notScheduledYet}, ${en.statusIdea}');
    });

    test('text on layer colours and on tentative tints reaches 4.5:1', () {
      for (final k in ItemKind.values) {
        expect(contrast(Colors.white, kindColor(k)), greaterThanOrEqualTo(4.5), reason: '$k white on solid');
        for (final b in Brightness.values) {
          final c = contrast(tentativeInk(kindColor(k), b), tentativeFill(kindColor(k), b));
          expect(c, greaterThanOrEqualTo(4.5), reason: '$k tentative $b');
        }
      }
    });

    test('night shading is visible in the light theme but keeps ink text readable', () {
      final light = buildTheme(Brightness.light);
      final night = light.extension<AppColors>()!.night;
      final ground = light.colorScheme.surface;
      expect(contrast(night, ground), greaterThan(1.15));
      expect(contrast(light.colorScheme.onSurface, night), greaterThanOrEqualTo(7));
      expect(contrast(light.colorScheme.outline, night), greaterThanOrEqualTo(4.5));
    });
  });
}
