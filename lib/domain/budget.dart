// Costs and budget – pure Dart.
//
// Items may carry a [Cost] (amount, ISO currency, per person or total, paid).
// The budget converts everything into the trip's home currency with the
// exchange rates the user typed in (Trip.rates, foreign units per home unit),
// so it works offline. Amounts in a currency without a rate are not guessed
// but reported per currency.
//
// Only planned and booked items count; options and ideas are alternatives
// and summed up separately ("not counted").

import 'models.dart';

/// Common symbols people type instead of a code.
const _symbols = {'€': 'EUR', r'$': 'USD', '£': 'GBP', '¥': 'JPY', '₹': 'INR'};

/// [input] as an ISO 4217 style code ("eur" → "EUR", "€" → "EUR"), or null
/// when it is not three letters (or a known symbol).
String? normalizeCurrency(String? input) {
  final t = input?.trim().toUpperCase();
  if (t == null || t.isEmpty) return null;
  final s = _symbols[t];
  if (s != null) return s;
  return RegExp(r'^[A-Z]{3}$').hasMatch(t) ? t : null;
}

/// Parses an amount the way people type it: "12", "12.50", "12,50",
/// "1.234,50", "1,234.50", "1 234". Null for anything else or negatives.
double? parseAmount(String? input) {
  var t = input?.trim().replaceAll(RegExp(r"[\s\u00a0\u202f']"), '');
  if (t == null || t.isEmpty) return null;
  final dot = t.lastIndexOf('.'), comma = t.lastIndexOf(',');
  if (dot >= 0 && comma >= 0) {
    // The later one is the decimal separator, the other groups thousands.
    final decimal = dot > comma ? '.' : ',';
    final group = decimal == '.' ? ',' : '.';
    t = t.replaceAll(group, '').replaceAll(decimal, '.');
  } else if (comma >= 0) {
    // "1,234" with exactly three digits after a single comma reads as
    // thousands only with more commas ("1,234,567"); a single one is decimal.
    t = ','.allMatches(t).length > 1 ? t.replaceAll(',', '') : t.replaceAll(',', '.');
  } else if ('.'.allMatches(t).length > 1) {
    t = t.replaceAll('.', '');
  }
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(t)) return null;
  return double.tryParse(t);
}

/// Statuses whose cost counts into the budget.
bool countsIntoBudget(PlanItem i) => i.status == ItemStatus.planned || i.status == ItemStatus.booked;

/// Total of [c] for [travellers] people, in the cost's own currency.
double costTotal(Cost c, int travellers) => c.perPerson ? c.amount * (travellers < 1 ? 1 : travellers) : c.amount;

/// The home currency the budget is shown in: the trip's, else the currency
/// used most among the items' costs (ties: alphabetical), else null.
String? budgetCurrency(Trip trip, Iterable<PlanItem> items) {
  if (trip.currency != null) return trip.currency;
  final counts = <String, int>{};
  for (final i in items) {
    final c = i.cost?.currency;
    if (c != null) counts[c] = (counts[c] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : a.key.compareTo(b.key));
  return sorted.first.key;
}

/// [amount] of [currency] in [home], or null when no rate is known. A null
/// currency is the home currency itself.
double? convertAmount(double amount, String? currency, String? home, Map<String, double> rates) {
  if (currency == null || currency == home) return amount;
  final r = rates[currency];
  if (r == null || r <= 0) return null;
  return amount / r;
}

/// Paid and open sums in the home currency, plus what could not be
/// converted (per currency, in that currency).
class BudgetLine {
  final double paid;
  final double open;
  final Map<String, double> unconverted;
  final int count;

  const BudgetLine({this.paid = 0, this.open = 0, this.unconverted = const {}, this.count = 0});

  double get total => paid + open;
  bool get isEmpty => count == 0;

  /// Share of [total] already paid (0 when there is nothing).
  double get paidShare => total <= 0 ? 0 : paid / total;

  BudgetLine _add(double? converted, String? currency, double raw, bool paid) => BudgetLine(
        paid: this.paid + (converted != null && paid ? converted : 0),
        open: open + (converted != null && !paid ? converted : 0),
        unconverted: converted != null
            ? unconverted
            : {...unconverted, currency!: (unconverted[currency] ?? 0) + raw},
        count: count + 1,
      );
}

/// One item with a cost, converted.
class BudgetEntry {
  final PlanItem item;

  /// Total in the cost's own currency (per person × travellers).
  final double total;

  /// [total] in the home currency; null without a rate.
  final double? converted;
  final bool counted;

  const BudgetEntry({required this.item, required this.total, required this.converted, required this.counted});

  Cost get cost => item.cost!;
}

class Budget {
  /// Home currency (see [budgetCurrency]); null while no currency is known.
  final String? currency;
  final int travellers;

  /// Counted costs per planning layer (every layer present, maybe empty).
  final Map<ItemKind, BudgetLine> layers;
  final BudgetLine total;

  /// Options and ideas – not part of [total].
  final BudgetLine notCounted;

  /// Every item with a cost, chronologically, unscheduled ones last.
  final List<BudgetEntry> entries;

  /// Foreign currencies in use without an exchange rate, sorted.
  final List<String> missingRates;

  /// Foreign currencies in use (with or without a rate), sorted.
  final List<String> foreignCurrencies;

  const Budget({
    required this.currency,
    required this.travellers,
    required this.layers,
    required this.total,
    required this.notCounted,
    required this.entries,
    required this.missingRates,
    required this.foreignCurrencies,
  });

  bool get isEmpty => entries.isEmpty;

  /// Counted total per traveller.
  double get perPerson => total.total / (travellers < 1 ? 1 : travellers);
}

/// The budget of [data]'s trip.
Budget budgetOf(TripData data) {
  final trip = data.trip;
  final home = budgetCurrency(trip, data.items);
  final layers = {for (final k in ItemKind.values) k: const BudgetLine()};
  var total = const BudgetLine(), notCounted = const BudgetLine();
  final entries = <BudgetEntry>[];
  final foreign = <String>{}, missing = <String>{};
  final items = [for (final i in data.items) if (i.cost != null) i]..sort((a, b) {
      if ((a.start == null) != (b.start == null)) return a.start == null ? 1 : -1;
      final c = (a.start ?? 0).compareTo(b.start ?? 0);
      return c != 0 ? c : a.kind.layer.compareTo(b.kind.layer);
    });
  for (final i in items) {
    final c = i.cost!;
    final raw = costTotal(c, trip.travellers);
    final cur = c.currency == home ? null : c.currency;
    final converted = convertAmount(raw, cur, home, trip.rates);
    if (cur != null) {
      foreign.add(cur);
      if (converted == null) missing.add(cur);
    }
    final counted = countsIntoBudget(i);
    entries.add(BudgetEntry(item: i, total: raw, converted: converted, counted: counted));
    if (counted) {
      layers[i.kind] = layers[i.kind]!._add(converted, cur, raw, c.paid);
      total = total._add(converted, cur, raw, c.paid);
    } else {
      notCounted = notCounted._add(converted, cur, raw, c.paid);
    }
  }
  return Budget(
    currency: home,
    travellers: trip.travellers,
    layers: layers,
    total: total,
    notCounted: notCounted,
    entries: entries,
    missingRates: missing.toList()..sort(),
    foreignCurrencies: foreign.toList()..sort(),
  );
}

/// [item] marked paid / unpaid; unchanged without a cost.
PlanItem setPaid(PlanItem item, bool paid) =>
    item.cost == null ? item : item.copyWith(cost: item.cost!.copyWith(paid: paid));

/// [trip] with the rate for [currency] set (or removed for null / ≤ 0).
Trip setRate(Trip trip, String currency, double? rate) {
  final rates = {...trip.rates}..remove(currency);
  if (rate != null && rate > 0) rates[currency] = rate;
  return trip.copyWith(rates: rates);
}
