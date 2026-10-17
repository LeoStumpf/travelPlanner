import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/budget.dart';
import '../../domain/models.dart';
import '../../domain/zones.dart';
import '../../state/providers.dart';
import '../common/item_sheet.dart';
import '../common/l10n.dart';
import '../common/style.dart';
import '../editor/item_editor_page.dart';
import '../trips/trip_settings_dialog.dart';

Future<void> openBudget(BuildContext context, String tripId) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => BudgetPage(tripId: tripId)));

/// The trip's costs in its home currency: total with paid / open, per
/// layer, options and ideas apart, the manual exchange rates and every item
/// with a cost (tick = paid). All changes are undoable steps.
class BudgetPage extends ConsumerWidget {
  final String tripId;
  const BudgetPage({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(tripDataProvider(tripId)).value;
    final l = context.l10n;
    if (data == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final b = budgetOf(data);
    final theme = Theme.of(context);
    final home = b.currency;

    return Scaffold(
      appBar: AppBar(title: Text(l.budget)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          ListTile(
            key: const ValueKey('budget-settings'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.tune),
            title: Text(l.budgetSettingsLine(data.trip.currency ?? l.budgetCurrencyNotSet, data.trip.travellers)),
            subtitle: data.trip.currency == null && home != null ? Text(l.budgetCurrencyGuessed(home)) : null,
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editSettings(context, ref, data),
          ),
          if (b.isEmpty)
            Padding(
              key: const ValueKey('budget-empty'),
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(children: [
                Icon(Icons.savings_outlined, size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text(l.budgetEmptyTitle, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(l.budgetEmptyBody, textAlign: TextAlign.center),
              ]),
            )
          else ...[
            _TotalCard(budget: b),
            for (final c in b.missingRates)
              Card(
                key: ValueKey('budget-missing-$c'),
                color: theme.colorScheme.errorContainer,
                child: ListTile(
                  leading: Icon(Icons.currency_exchange, color: theme.colorScheme.onErrorContainer),
                  title: Text(
                    l.budgetMissingRate(
                        c, l.money((b.total.unconverted[c] ?? 0) + (b.notCounted.unconverted[c] ?? 0), c)),
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                  trailing: home == null
                      ? null
                      : TextButton(onPressed: () => _editRate(context, ref, data, c), child: Text(l.budgetEnterRate)),
                ),
              ),
            _header(context, l.budgetByLayer),
            for (final k in ItemKind.values)
              if (!b.layers[k]!.isEmpty) _LayerRow(kind: k, line: b.layers[k]!, currency: home),
            if (!b.notCounted.isEmpty)
              ListTile(
                key: const ValueKey('budget-not-counted'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.help_outline),
                title: Text(l.budgetNotCounted),
                trailing: Text(l.money(b.notCounted.total, home)),
              ),
            ..._rates(context, ref, data, b),
            _header(context, l.budgetItems),
            for (final e in b.entries) _entryTile(context, ref, data, e, home),
          ],
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 4),
        child: Text(t, style: Theme.of(context).textTheme.titleSmall),
      );

  List<Widget> _rates(BuildContext context, WidgetRef ref, TripData data, Budget b) {
    final l = context.l10n;
    final home = b.currency;
    final codes = {...b.foreignCurrencies, ...data.trip.rates.keys}.where((c) => c != home).toList()..sort();
    if (home == null && codes.isEmpty) return const [];
    return [
      Row(children: [
        Expanded(child: _header(context, l.budgetRates)),
        if (home != null) _addRateButton(context, ref, data),
      ]),
      if (home == null)
        Text(l.budgetNoCurrency)
      else ...[
        for (final c in codes)
          ListTile(
            key: ValueKey('budget-rate-$c'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.currency_exchange),
            title: Text(data.trip.rates[c] == null
                ? '$c · ${l.budgetRateMissing}'
                : l.budgetRateValue(home, l.rate(data.trip.rates[c]!), c)),
            onTap: () => _editRate(context, ref, data, c),
          ),
        Text(l.budgetRatesHint, style: Theme.of(context).textTheme.bodySmall),
      ],
    ];
  }

  Widget _addRateButton(BuildContext context, WidgetRef ref, TripData data) => TextButton.icon(
        key: const ValueKey('budget-add-rate'),
        onPressed: () => _editRate(context, ref, data, null),
        icon: const Icon(Icons.add, size: 18),
        label: Text(context.l10n.budgetAddRate),
      );

  Widget _entryTile(BuildContext context, WidgetRef ref, TripData data, BudgetEntry e, String? home) {
    final l = context.l10n;
    final i = e.item;
    final cur = e.cost.currency ?? home;
    final shown = e.converted ?? e.total;
    final foreign = cur != home;
    return ListTile(
      key: ValueKey('budget-entry-${i.id}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(itemIcon(i), color: kindColor(i.kind).withValues(alpha: e.counted ? 1 : 0.45)),
      title: Text(i.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: e.counted ? null : const TextStyle(fontStyle: FontStyle.italic)),
      subtitle: Text([
        l.status(i.status),
        if (e.cost.perPerson) l.costTimesPerPerson(data.trip.travellers, l.money(e.cost.amount, cur)),
        if (foreign && e.converted != null) l.money(e.total, cur),
      ].join(' · ')),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(l.money(shown, e.converted != null ? home : cur)),
        Checkbox(
          key: ValueKey('budget-paid-${i.id}'),
          value: e.cost.paid,
          onChanged: (_) => togglePaid(l, ref, data, i),
        ),
      ]),
      onTap: () => openItemEditor(context, data, item: i),
    );
  }

  Future<void> _editSettings(BuildContext context, WidgetRef ref, TripData data) async {
    final l = context.l10n;
    final t = await showTripSettingsDialog(context, data.trip, usedZones: data.usedZones);
    if (t != null) await ref.read(planActionsProvider).record(t.id, l.stepTripEdited, (r) => r.saveTrip(t));
  }

  /// Enter, change or remove the rate for [currency] (null: ask for it).
  Future<void> _editRate(BuildContext context, WidgetRef ref, TripData data, String? currency) async {
    final l = context.l10n;
    final home = budgetCurrency(data.trip, data.items);
    if (home == null) return;
    final r = await showDialog<(String, double?)>(
      context: context,
      builder: (_) => _RateDialog(home: home, currency: currency, rate: data.trip.rates[currency]),
    );
    if (r == null) return;
    final (code, rate) = r;
    // Rates are relative to the shown currency; a guessed one becomes the trip's.
    final trip = setRate(data.trip.currency == null ? data.trip.copyWith(currency: home) : data.trip, code, rate);
    await ref.read(planActionsProvider).record(trip.id, l.stepRateChanged(code), (repo) => repo.saveTrip(trip));
  }
}

class _TotalCard extends StatelessWidget {
  final Budget budget;
  const _TotalCard({required this.budget});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final t = budget.total;
    final cur = budget.currency;
    return Card(
      key: const ValueKey('budget-total'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.costTotal, style: theme.textTheme.labelLarge),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(l.money(t.total, cur), style: theme.textTheme.headlineMedium),
          ),
          if (budget.travellers > 1) Text(l.costPerPersonOf(l.money(budget.perPerson, cur))),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: t.paidShare, minHeight: 8),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 16, runSpacing: 4, children: [
            Text('${l.costPaid}: ${l.money(t.paid, cur)}', key: const ValueKey('budget-paid')),
            Text('${l.costOpen}: ${l.money(t.open, cur)}', key: const ValueKey('budget-open')),
          ]),
        ]),
      ),
    );
  }
}

class _LayerRow extends StatelessWidget {
  final ItemKind kind;
  final BudgetLine line;
  final String? currency;
  const _LayerRow({required this.kind, required this.line, required this.currency});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final color = kindColor(kind);
    return Padding(
      key: ValueKey('budget-layer-${kind.name}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(kindIcon(kind), color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(l.kind(kind), overflow: TextOverflow.ellipsis)),
              Text(l.money(line.total, currency), style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: line.paidShare,
              color: color,
              backgroundColor: color.withValues(alpha: 0.18),
            ),
            const SizedBox(height: 2),
            Text(l.budgetPaidOf(l.money(line.paid, currency), l.money(line.total, currency)),
                style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ]),
    );
  }
}

/// Asks for "1 [home] = x [currency]". Returns (code, rate), rate null =
/// remove; null when cancelled.
class _RateDialog extends StatefulWidget {
  final String home;
  final String? currency;
  final double? rate;
  const _RateDialog({required this.home, this.currency, this.rate});

  @override
  State<_RateDialog> createState() => _RateDialogState();
}

class _RateDialogState extends State<_RateDialog> {
  late final _code = TextEditingController(text: widget.currency ?? '');
  late final _rate = TextEditingController(text: widget.rate == null ? '' : _plain(widget.rate!));
  bool _codeError = false, _rateError = false;

  static String _plain(double r) => r == r.roundToDouble() ? r.toInt().toString() : r.toString();

  @override
  void dispose() {
    _code.dispose();
    _rate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final code = normalizeCurrency(_code.text) ?? (widget.currency ?? '…');
    return AlertDialog(
      title: Text(l.budgetRateDialogTitle(widget.currency ?? l.costCurrencyLabel)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.currency == null)
          TextField(
            key: const ValueKey('rate-currency'),
            controller: _code,
            autofocus: true,
            maxLength: 3,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: l.costCurrencyLabel,
              hintText: 'USD',
              counterText: '',
              errorText: _codeError ? l.costInvalidCurrency : null,
            ),
            onChanged: (_) => setState(() => _codeError = false),
          ),
        Text(l.budgetRateDialogHint(code, widget.home)),
        TextField(
          key: const ValueKey('rate-value'),
          controller: _rate,
          autofocus: widget.currency != null,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixText: '1 ${widget.home} = ',
            suffixText: code,
            errorText: _rateError ? l.costInvalidAmount : null,
          ),
          onChanged: (_) => setState(() => _rateError = false),
        ),
      ]),
      actions: [
        if (widget.rate != null)
          TextButton(
            onPressed: () => Navigator.pop(context, (widget.currency!, null)),
            child: Text(l.budgetRemoveRate),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          onPressed: () {
            final c = widget.currency ?? normalizeCurrency(_code.text);
            final r = parseAmount(_rate.text);
            if (c == null || c == widget.home || r == null || r <= 0) {
              setState(() {
                _codeError = c == null || c == widget.home;
                _rateError = r == null || r <= 0;
              });
              return;
            }
            Navigator.pop(context, (c, r));
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}
