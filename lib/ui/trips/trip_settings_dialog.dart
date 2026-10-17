import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/budget.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../../state/reminders.dart';
import '../common/a11y.dart';
import '../common/l10n.dart';
import '../common/style.dart';
import '../common/zone_picker.dart';
import '../reminders/reminder_sheet.dart';
import '../reminders/reminder_texts.dart';

/// Create ([trip] == null) or edit a trip's title, start date, length, home
/// time zone, home currency and number of travellers; an existing trip
/// also links to its reminders (saved at once, see reminder_sheet.dart). [usedZones] are offered first in the zone picker.
Future<Trip?> showTripSettingsDialog(BuildContext context, Trip? trip, {List<String> usedZones = const []}) =>
    showDialog<Trip>(context: context, builder: (_) => _TripSettingsDialog(trip: trip, usedZones: usedZones));

class _TripSettingsDialog extends StatefulWidget {
  final Trip? trip;
  final List<String> usedZones;
  const _TripSettingsDialog({this.trip, this.usedZones = const []});

  @override
  State<_TripSettingsDialog> createState() => _TripSettingsDialogState();
}

class _TripSettingsDialogState extends State<_TripSettingsDialog> {
  late final _title = TextEditingController(text: widget.trip?.title ?? '');
  late final _days = TextEditingController(text: widget.trip?.plannedDays?.toString() ?? '');
  late DateTime? _start = widget.trip?.startDate;
  late int _color = widget.trip?.color ?? tripColors.first;
  late String? _homeZone = widget.trip?.homeZone;
  late final _currency = TextEditingController(text: widget.trip?.currency ?? '');
  late final _travellers = TextEditingController(text: '${widget.trip?.travellers ?? 1}');
  bool _currencyError = false;

  @override
  void dispose() {
    _title.dispose();
    _days.dispose();
    _currency.dispose();
    _travellers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.trip == null ? l.newTrip : l.editTrip),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _title,
              autofocus: widget.trip == null,
              decoration: InputDecoration(labelText: l.tripTitleLabel, hintText: l.tripTitleHint),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _days,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.plannedDaysLabel, hintText: l.optional),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(_start == null ? l.startDateOpen : l.startDateValue(l.date(_start!))),
                ),
                if (_start != null)
                  IconButton(
                    tooltip: l.removeDate,
                    onPressed: () => setState(() => _start = null),
                    icon: const Icon(Icons.clear),
                  ),
                TextButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _start ?? now,
                      firstDate: DateTime(now.year - 5),
                      lastDate: DateTime(now.year + 10),
                    );
                    if (d != null) setState(() => _start = d);
                  },
                  child: Text(l.choose),
                ),
              ],
            ),
            Text(
              l.withoutDateHint,
              style: const TextStyle(fontSize: 12),
            ),
            ZoneTile(
              key: const ValueKey('home-zone'),
              label: l.homeZoneLabel,
              zone: _homeZone,
              noneLabel: l.zoneNone,
              subtitle: l.homeZoneHint,
              suggestions: widget.usedZones,
              onChanged: (z) => setState(() => _homeZone = z),
            ),
            const SizedBox(height: 4),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('trip-currency'),
                  controller: _currency,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 3,
                  decoration: InputDecoration(
                    labelText: l.tripCurrencyLabel,
                    hintText: 'EUR',
                    counterText: '',
                    errorText: _currencyError ? l.costInvalidCurrency : null,
                    errorMaxLines: 2,
                  ),
                  onChanged: (_) {
                    if (_currencyError) setState(() => _currencyError = false);
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 96,
                child: TextField(
                  key: const ValueKey('trip-travellers'),
                  controller: _travellers,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l.travellersLabel),
                ),
              ),
            ]),
            Text(l.tripCurrencyHint, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            Wrap(
              children: [
                for (final c in tripColors)
                  ColorSwatchButton(
                    key: ValueKey('trip-color-$c'),
                    color: c,
                    fill: Color(c),
                    radius: 14,
                    checkColor: Colors.white,
                    selected: c == _color,
                    onTap: () => setState(() => _color = c),
                  ),
              ],
            ),
            if (widget.trip != null)
              Consumer(
                builder: (context, ref, _) => ListTile(
                  key: const ValueKey('trip-reminders'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notifications_outlined),
                  title: Text(l.reminders),
                  subtitle: Text(l.reminderSummary(ref.watch(tripReminderSettingsProvider(widget.trip!.id)))),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showReminderSheet(context, widget.trip!.id, canSetStartDate: false),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          onPressed: () {
            final title = _title.text.trim().isEmpty ? l.newTrip : _title.text.trim();
            final days = int.tryParse(_days.text.trim());
            final currencyText = _currency.text.trim();
            final currency = normalizeCurrency(currencyText);
            if (currencyText.isNotEmpty && currency == null) {
              setState(() => _currencyError = true);
              return;
            }
            final travellers = (int.tryParse(_travellers.text.trim()) ?? 1).clamp(1, 99);
            final t = widget.trip;
            Navigator.pop(
              context,
              t == null
                  ? Trip(
                      id: newId(),
                      title: title,
                      startDate: _start,
                      plannedDays: days,
                      color: _color,
                      homeZone: _homeZone,
                      currency: currency,
                      travellers: travellers,
                      createdAt: DateTime.now(),
                    )
                  : setHomeCurrency(
                      t.copyWith(
                        title: title,
                        startDate: _start,
                        plannedDays: days,
                        color: _color,
                        homeZone: _homeZone,
                        travellers: travellers,
                      ),
                      currency,
                    ),
            );
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}
