import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/data/attachment_store.dart';
import 'package:travel_planner/data/db.dart';
import 'package:travel_planner/data/repository.dart';
import 'package:travel_planner/domain/budget.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/domain/time.dart';
import 'package:travel_planner/state/providers.dart';
import 'package:travel_planner/ui/budget/budget_page.dart';
import 'package:travel_planner/ui/common/item_sheet.dart';
import 'package:travel_planner/ui/common/l10n.dart';
import 'package:travel_planner/ui/editor/item_editor_page.dart';
import 'package:travel_planner/ui/trips/trip_settings_dialog.dart';

import '../l10n_test_utils.dart';

void main() {
  String eur(num v) => de.money(v.toDouble(), 'EUR');
  late Repository repo;
  late ProviderContainer container;
  final now = DateTime(2026, 10, 17);

  PlanItem item(String id, ItemKind kind, {Cost? cost, ItemStatus status = ItemStatus.planned, int day = 0}) =>
      PlanItem(
        id: id,
        tripId: 't',
        kind: kind,
        title: id,
        status: status,
        start: at(day, 10 * 60),
        end: at(day, 12 * 60),
        parentId: kind == ItemKind.stay || kind == ItemKind.transport ? null : 'Kandy',
        mode: kind == ItemKind.transport ? TransportMode.train : null,
        cost: cost,
        createdAt: now,
      );

  TripData sample({String? currency = 'EUR', Map<String, double> rates = const {}}) => TripData(
        trip: Trip(id: 't', title: 'Sri Lanka', currency: currency, travellers: 2, rates: rates, createdAt: now),
        items: [
          item('Kandy', ItemKind.stay).copyWith(end: at(2, 10 * 60)),
          item('Train', ItemKind.transport, cost: const Cost(amount: 10, perPerson: true, paid: true)),
          item('Hotel', ItemKind.accommodation, cost: const Cost(amount: 33000, currency: 'LKR'), day: 0)
              .copyWith(end: at(2, 10 * 60)),
          item('Safari', ItemKind.activity, cost: const Cost(amount: 50), status: ItemStatus.option, day: 1),
        ],
      );

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

  Future<TripData> stored(WidgetTester tester) async => (await tester.runAsync(() => repo.loadTrip('t')))!;

  /// Puts [data] into the database and shows a button that runs [open].
  Future<void> openWith(WidgetTester tester, TripData data, void Function(BuildContext, WidgetRef, TripData) open,
      {Size size = const Size(800, 2000)}) async {
    await tester.runAsync(() => repo.putTripData(data));
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: testApp(
        home: Scaffold(
          body: Consumer(builder: (context, ref, _) {
            final d = ref.watch(tripDataProvider(data.trip.id)).value;
            return d == null
                ? const Text('loading')
                : TextButton(onPressed: () => open(context, ref, d), child: const Text('open'));
          }),
        ),
      ),
    ));
    await settle(tester);
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  group('editor', () {
    testWidgets('saves amount, currency, per person and paid', (tester) async {
      await openWith(tester, sample(), (c, ref, d) => openItemEditor(c, d, item: d.item('Kandy')));
      expect(find.text(de.costSection), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('field-cost-amount')), '1.234,50');
      await tester.enterText(find.byKey(const ValueKey('field-cost-currency')), 'lkr');
      await tester.ensureVisible(find.text(de.costPerPerson));
      await tester.tap(find.text(de.costPerPerson));
      await tester.pump();
      // Two travellers: the total is shown right away.
      expect(find.byKey(const ValueKey('cost-travellers-total')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('cost-paid')));
      await tester.tap(find.byKey(const ValueKey('cost-paid')));
      await tester.pump();
      await tester.tap(find.text(de.save));
      await settle(tester);

      expect((await stored(tester)).item('Kandy')!.cost,
          const Cost(amount: 1234.5, currency: 'LKR', perPerson: true, paid: true));
    });

    testWidgets('an invalid amount or currency blocks saving', (tester) async {
      await openWith(tester, sample(), (c, ref, d) => openItemEditor(c, d, item: d.item('Kandy')));
      await tester.enterText(find.byKey(const ValueKey('field-cost-amount')), '12 Euro');
      await tester.enterText(find.byKey(const ValueKey('field-cost-currency')), 'E1');
      await tester.tap(find.text(de.save));
      await settle(tester);
      expect(find.text(de.costInvalidAmount), findsOneWidget);
      expect(find.text(de.costInvalidCurrency), findsOneWidget);
      expect(find.byType(ItemEditorPage), findsOneWidget);
      expect((await stored(tester)).item('Kandy')!.cost, isNull);
    });

    testWidgets('clearing the amount removes the cost; typing counts as unsaved', (tester) async {
      await openWith(tester, sample(), (c, ref, d) => openItemEditor(c, d, item: d.item('Train')));
      expect(find.text('10'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('field-cost-amount')), '');
      await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pumpAndSettle();
      expect(find.text(de.unsavedChangesTitle), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, de.save));
      await settle(tester);
      expect((await stored(tester)).item('Train')!.cost, isNull);
    });
  });

  testWidgets('a blank currency is stored as the guessed home currency', (tester) async {
    // No trip currency: the budget shows the most used one (LKR here).
    final data = sample(currency: null);
    await openWith(tester, data, (c, ref, d) => openItemEditor(c, d, item: d.item('Kandy')));
    await tester.enterText(find.byKey(const ValueKey('field-cost-amount')), '5000');
    await tester.tap(find.text(de.save));
    await settle(tester);
    final cost = (await stored(tester)).item('Kandy')!.cost!;
    expect([cost.amount, cost.currency], [5000, budgetCurrency(data.trip, data.items)]);
  });

  testWidgets('changing the home currency in trip settings rebases the rates', (tester) async {
    Trip? result;
    await openWith(tester, sample(rates: {'LKR': 330, 'USD': 1.1}),
        (c, ref, d) async => result = await showTripSettingsDialog(c, d.trip));
    await tester.enterText(find.byKey(const ValueKey('trip-currency')), 'USD');
    await tester.tap(find.text(de.save));
    await tester.pumpAndSettle();
    expect(result?.currency, 'USD');
    expect(result?.rates['LKR'], closeTo(300, 1e-9));
    expect(result?.rates.containsKey('EUR'), isTrue);
  });

  testWidgets('trip settings take the home currency and travellers', (tester) async {
    Trip? result;
    await openWith(tester, sample(currency: null),
        (c, ref, d) async => result = await showTripSettingsDialog(c, d.trip));
    await tester.enterText(find.byKey(const ValueKey('trip-currency')), 'E1R');
    await tester.tap(find.text(de.save));
    await tester.pumpAndSettle();
    expect(find.text(de.costInvalidCurrency), findsOneWidget);
    expect(result, isNull);

    await tester.enterText(find.byKey(const ValueKey('trip-currency')), '€');
    await tester.enterText(find.byKey(const ValueKey('trip-travellers')), '3');
    await tester.tap(find.text(de.save));
    await tester.pumpAndSettle();
    expect([result?.currency, result?.travellers], ['EUR', 3]);
  });

  testWidgets('item sheet shows the cost and toggles paid as an undoable step', (tester) async {
    await openWith(tester, sample(rates: {'LKR': 330}), (c, ref, d) => showItemSheet(c, ref, 't', 'Hotel'));
    final tile = find.byKey(const ValueKey('item-cost'));
    expect(tile, findsOneWidget);
    expect(find.descendant(of: tile, matching: find.textContaining('≈ ${eur(100)}')), findsOneWidget);
    expect(find.descendant(of: tile, matching: find.text(de.costOpen)), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('quick-paid')));
    await settle(tester);
    expect((await stored(tester)).item('Hotel')!.cost!.paid, isTrue);
    expect(find.descendant(of: tile, matching: find.text(de.costPaid)), findsOneWidget);
    expect(container.read(undoLabelProvider('t')), de.stepMarkedPaid('Hotel'));

    await tester.runAsync(() => container.read(planActionsProvider).undo('t'));
    expect((await stored(tester)).item('Hotel')!.cost!.paid, isFalse);
  });

  testWidgets('no cost, no tile and no paid chip', (tester) async {
    await openWith(tester, sample(), (c, ref, d) => showItemSheet(c, ref, 't', 'Kandy'));
    expect(find.byKey(const ValueKey('item-cost')), findsNothing);
    expect(find.byKey(const ValueKey('quick-paid')), findsNothing);
  });

  group('budget page', () {
    testWidgets('sums per layer, asks for a missing rate and converts with it', (tester) async {
      await openWith(tester, sample(), (c, ref, d) => openBudget(c, 't'));
      expect(find.text(de.budget), findsOneWidget);
      // Only the train counts so far: 2 × 10 €, paid; the hotel lacks a rate.
      final total = find.byKey(const ValueKey('budget-total'));
      expect(find.descendant(of: total, matching: find.text(eur(20))), findsOneWidget);
      expect(find.descendant(of: total, matching: find.text(de.costPerPersonOf(eur(10)))), findsOneWidget);
      expect(find.byKey(const ValueKey('budget-missing-LKR')), findsOneWidget);
      expect(find.byKey(const ValueKey('budget-layer-transport')), findsOneWidget);
      expect(find.byKey(const ValueKey('budget-layer-accommodation')), findsOneWidget);
      expect(find.byKey(const ValueKey('budget-layer-stay')), findsNothing);
      expect(find.byKey(const ValueKey('budget-not-counted')), findsOneWidget);

      await tester.tap(find.text(de.budgetEnterRate));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('rate-value')), '330');
      await tester.tap(find.widgetWithText(FilledButton, de.save));
      await settle(tester);

      expect((await stored(tester)).trip.rates, {'LKR': 330});
      expect(find.byKey(const ValueKey('budget-missing-LKR')), findsNothing);
      expect(find.descendant(of: total, matching: find.text(eur(120))), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('budget-open'))).data, '${de.costOpen}: ${eur(100)}');
      expect(find.text(de.budgetRateValue('EUR', '330', 'LKR')), findsOneWidget);
      expect(container.read(undoLabelProvider('t')), de.stepRateChanged('LKR'));
    });

    testWidgets('ticking an item marks it paid', (tester) async {
      await openWith(tester, sample(rates: {'LKR': 330}), (c, ref, d) => openBudget(c, 't'));
      await tester.ensureVisible(find.byKey(const ValueKey('budget-paid-Hotel')));
      await tester.tap(find.byKey(const ValueKey('budget-paid-Hotel')));
      await settle(tester);
      expect((await stored(tester)).item('Hotel')!.cost!.paid, isTrue);
      expect(tester.widget<Text>(find.byKey(const ValueKey('budget-paid'))).data, '${de.costPaid}: ${eur(120)}');
    });

    testWidgets('a rate can be added for any currency and removed again', (tester) async {
      await openWith(tester, sample(rates: {'LKR': 330}), (c, ref, d) => openBudget(c, 't'));
      await tester.ensureVisible(find.byKey(const ValueKey('budget-add-rate')));
      await tester.tap(find.byKey(const ValueKey('budget-add-rate')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('rate-currency')), 'usd');
      await tester.enterText(find.byKey(const ValueKey('rate-value')), '1,08');
      await tester.tap(find.widgetWithText(FilledButton, de.save));
      await settle(tester);
      expect((await stored(tester)).trip.rates, {'LKR': 330, 'USD': 1.08});

      await tester.ensureVisible(find.byKey(const ValueKey('budget-rate-USD')));
      await tester.tap(find.byKey(const ValueKey('budget-rate-USD')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(de.budgetRemoveRate));
      await settle(tester);
      expect((await stored(tester)).trip.rates, {'LKR': 330});
    });

    testWidgets('empty state without costs', (tester) async {
      final d = sample();
      await openWith(
        tester,
        TripData(trip: d.trip, items: [for (final i in d.items) i.copyWith(cost: null)]),
        (c, ref, d) => openBudget(c, 't'),
      );
      expect(find.byKey(const ValueKey('budget-empty')), findsOneWidget);
      expect(find.text(de.budgetEmptyTitle), findsOneWidget);
    });

    testWidgets('without a home currency it shows the most used one and says so', (tester) async {
      await openWith(tester, sample(currency: null), (c, ref, d) => openBudget(c, 't'));
      expect(find.text(de.budgetCurrencyGuessed('LKR')), findsOneWidget);
      expect(find.text(de.budgetSettingsLine(de.budgetCurrencyNotSet, 2)), findsOneWidget);
    });

    testWidgets('fits a 360 dp phone in English', (tester) async {
      await tester.runAsync(() => repo.putTripData(sample()));
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: testApp(locale: const Locale('en'), home: const BudgetPage(tripId: 't')),
      ));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(en.budgetEnterRate), findsOneWidget);
    });
  });
}
