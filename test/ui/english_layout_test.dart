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
import 'package:travel_planner/ui/common/item_sheet.dart';
import 'package:travel_planner/ui/common/l10n.dart';
import 'package:travel_planner/ui/editor/card_editor_page.dart';
import 'package:travel_planner/ui/editor/item_editor_page.dart';
import 'package:travel_planner/ui/trip/trip_page.dart';
import 'package:travel_planner/ui/trips/trips_page.dart';

import '../l10n_test_utils.dart';

/// The main screens on a 360 dp phone in both languages (the other widget
/// tests only run in German).
void main() {
  late Repository repo;
  late ProviderContainer container;
  late TripData demo;

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

  for (final locale in appLocales) {
    final l = lookupAppLocalizations(locale);

    Future<void> pump(WidgetTester tester, Widget home, {bool settles = true}) async {
      demo = demoInterrail(l.demoTexts);
      await tester.runAsync(() => repo.putTripData(demo));
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: testApp(locale: locale, home: home),
        ),
      );
      if (settles) {
        await settle(tester);
      } else {
        // Editors keep animating (cursor), so just give them a few frames.
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
        await tester.pump(const Duration(milliseconds: 500));
      }
    }

    testWidgets('${locale.languageCode}: trip list fits 360 dp', (tester) async {
      await pump(tester, const TripsPage());
      expect(find.text(l.myTrips), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${locale.languageCode}: canvas, notes and timeline fit 360 dp', (tester) async {
      await pump(tester, Builder(builder: (_) => TripPage(tripId: demo.trip.id)));
      expect(tester.takeException(), isNull);
      for (final v in [TripView.notes, TripView.timeline]) {
        await tester.tap(find.text(l.view(v)));
        await settle(tester);
        expect(tester.takeException(), isNull, reason: '$v');
      }
    });

    testWidgets('${locale.languageCode}: item sheets fit 360 dp', (tester) async {
      await pump(
        tester,
        Scaffold(
          body: Consumer(
            builder: (context, ref, _) => Column(
              children: [
                for (final title in ['Paris', 'TGV Paris → Lyon', 'Louvre', 'Hôtel du Marais'])
                  TextButton(
                    onPressed: () =>
                        showItemSheet(context, ref, demo.trip.id, demo.items.firstWhere((i) => i.title == title).id),
                    child: Text('open $title'),
                  ),
              ],
            ),
          ),
        ),
      );
      for (final title in ['Paris', 'TGV Paris → Lyon', 'Louvre', 'Hôtel du Marais']) {
        await tester.tap(find.text('open $title'));
        await settle(tester);
        expect(tester.takeException(), isNull, reason: title);
        await tester.tapAt(const Offset(180, 20));
        await settle(tester);
      }
    });

    testWidgets('${locale.languageCode}: editors fit 360 dp', (tester) async {
      for (final title in ['TGV Paris → Lyon', 'Hôtel du Marais', 'Louvre']) {
        final item = demoInterrail(l.demoTexts).items.firstWhere((i) => i.title == title);
        await pump(tester, ItemEditorPage(tripId: item.tripId, initial: item, isNew: false), settles: false);
        expect(tester.takeException(), isNull, reason: title);
      }
      final card = demoInterrail(l.demoTexts).cards.firstWhere((c) => c.type == CardType.checklist);
      await pump(tester, CardEditorPage(tripId: card.tripId, initial: card, isNew: false), settles: false);
      expect(tester.takeException(), isNull);
    });
  }
}
