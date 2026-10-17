import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../state/providers.dart';
import '../common/l10n.dart';
import '../common/style.dart';

/// Create ([trip] == null) or edit a trip's title, start date and length.
Future<Trip?> showTripSettingsDialog(BuildContext context, Trip? trip) =>
    showDialog<Trip>(context: context, builder: (_) => _TripSettingsDialog(trip: trip));

class _TripSettingsDialog extends StatefulWidget {
  final Trip? trip;
  const _TripSettingsDialog({this.trip});

  @override
  State<_TripSettingsDialog> createState() => _TripSettingsDialogState();
}

class _TripSettingsDialogState extends State<_TripSettingsDialog> {
  late final _title = TextEditingController(text: widget.trip?.title ?? '');
  late final _days = TextEditingController(text: widget.trip?.plannedDays?.toString() ?? '');
  late DateTime? _start = widget.trip?.startDate;
  late int _color = widget.trip?.color ?? tripColors.first;

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
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final c in tripColors)
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Color(c),
                      child: c == _color ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                    ),
                  ),
              ],
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
                      createdAt: DateTime.now(),
                    )
                  : t.copyWith(title: title, startDate: _start, plannedDays: days, color: _color),
            );
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}
