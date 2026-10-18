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
import 'package:travel_planner/domain/time.dart';
import 'package:travel_planner/state/hints.dart';
import 'package:travel_planner/state/providers.dart';
import 'package:travel_planner/state/timeline_prefs.dart';
import 'package:travel_planner/ui/timeline/timeline_view.dart';

import '../l10n_test_utils.dart';

void main() {
  late Repository repo;
  late SharedPreferences prefs;
  late ProviderContainer container;

  setUp(() async {
    repo = Repository(AppDatabase(NativeDatabase.memory()), AttachmentStore(Directory.systemTemp));
  });

  tearDown(() async {
    container.dispose();
    await repo.close();
  });

  Future<TripData> pump(WidgetTester tester, {String? axis, Size size = const Size(900, 1600)}) async {
    SharedPreferences.setMockInitialValues({
      'timelineAxis': ?axis,
      'seenHints': ['timeline'],
    });
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo), hintPrefsProvider.overrideWithValue(prefs)],
    );
    final data = demoInterrail();
    await tester.runAsync(() => repo.putTripData(data));
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: testApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                final d = ref.watch(tripDataProvider(data.trip.id)).value;
                return d == null ? const SizedBox() : TimelineView(data: d);
              },
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    return data;
  }

  Future<TripData> reload(WidgetTester tester, TripData data) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    return (await tester.runAsync(() => repo.loadTrip(data.trip.id)))!;
  }

  testWidgets('the button turns the timeline and the choice is remembered', (tester) async {
    await pump(tester);
    final parisH = tester.getTopLeft(find.text('Paris'));
    final lyonH = tester.getTopLeft(find.text('Lyon'));
    expect(lyonH.dx, greaterThan(parisH.dx + 40));
    expect(find.byTooltip('Senkrecht anzeigen'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('timeline-axis')));
    await tester.pumpAndSettle();
    final paris = tester.getTopLeft(find.text('Paris'));
    final lyon = tester.getTopLeft(find.text('Lyon'));
    // Days run down now: the next place is below, in the same column.
    expect(lyon.dy, greaterThan(paris.dy + 40));
    expect((lyon.dx - paris.dx).abs(), lessThan(4));
    expect(prefs.getString('timelineAxis'), 'vertical');
    expect(container.read(timelineAxisProvider), TimelineAxis.vertical);
    expect(find.byTooltip('Waagerecht anzeigen'), findsOneWidget);
    // Day numbers run down the left side.
    expect(tester.getTopLeft(find.text('02')).dy, greaterThan(tester.getTopLeft(find.text('01')).dy));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('timeline-axis')));
    await tester.pumpAndSettle();
    expect(prefs.getString('timelineAxis'), 'horizontal');
    expect(tester.getTopLeft(find.text('Lyon')).dx, greaterThan(tester.getTopLeft(find.text('Paris')).dx + 40));
  });

  testWidgets('vertical: long-press drag down moves a stay by a day', (tester) async {
    final data = await pump(tester, axis: 'vertical');
    final lyon = data.items.firstWhere((i) => i.title == 'Lyon');
    final g = await tester.startGesture(tester.getCenter(find.text('Lyon')));
    await tester.pump(const Duration(milliseconds: 700));
    await g.moveBy(const Offset(0, 65));
    await tester.pump();
    await g.moveBy(const Offset(0, 65)); // ~1 day at 120 px per day
    await tester.pump();
    await g.up();
    await tester.pump();
    final after = await reload(tester, data);
    expect(dayOf(after.item(lyon.id)!.start!), dayOf(lyon.start!) + 1);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('vertical: the end grip of the selected block drags downwards', (tester) async {
    final data = await pump(tester, axis: 'vertical');
    final lyon = data.items.firstWhere((i) => i.title == 'Lyon');
    container.read(tripUiProvider.notifier).select(lyon.id);
    await tester.pumpAndSettle();
    final grip = find.byKey(ValueKey('resizeEnd-${lyon.id}'));
    expect(grip, findsOneWidget);
    expect(tester.getSize(grip).height, greaterThanOrEqualTo(24));
    await tester.drag(grip, const Offset(0, 130));
    await tester.pump();
    final after = await reload(tester, data);
    expect(after.item(lyon.id)!.end, lyon.end! + minutesPerDay);
    expect(after.item(lyon.id)!.start, lyon.start);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('vertical: fits a 360 dp phone, also with large text', (tester) async {
    await pump(tester, axis: 'vertical', size: const Size(360, 640));
    expect(find.text('Paris'), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  group('times when zoomed in', () {
    Future<void> zoomIn(WidgetTester tester, int taps) async {
      for (var k = 0; k < taps; k++) {
        await tester.tap(find.byTooltip('Vergrößern'));
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    testWidgets('horizontal: hours appear and get finer, down to every hour', (tester) async {
      await pump(tester, size: const Size(360, 740));
      expect(find.text('12:00'), findsNothing);
      await zoomIn(tester, 3); // 216 dp per day: every 6 hours
      expect(find.text('12:00'), findsWidgets);
      expect(find.text('15:00'), findsNothing);
      await zoomIn(tester, 10); // fully zoomed in: every hour
      expect(find.text('15:00'), findsWidgets);
      expect(find.text('16:00'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Verkleinern'));
      for (var k = 0; k < 12; k++) {
        await tester.tap(find.byTooltip('Verkleinern'));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('12:00'), findsNothing);
    });

    testWidgets('vertical: hours run down the day column', (tester) async {
      await pump(tester, axis: 'vertical', size: const Size(360, 740));
      expect(find.text('18'), findsWidgets); // 120 dp per day: every 6 hours
      await zoomIn(tester, 10);
      expect(find.text('9'), findsWidgets);
      final nine = tester.getTopLeft(find.text('9').first);
      final ten = tester.getTopLeft(find.text('10').first);
      expect(ten.dy, greaterThan(nine.dy + 40));
      expect(tester.takeException(), isNull);
    });
  });
}
