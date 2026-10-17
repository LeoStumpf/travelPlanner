import 'package:flutter/material.dart';

import '../../domain/time.dart';
import '../common/a11y.dart';
import '../common/l10n.dart';

/// Day + time of day in the trip-relative minute model. The day is shown as
/// "Day N" or as a date when the trip has a start date.
class MomentField extends StatelessWidget {
  final String label;
  final DateTime? tripStart;
  final int value;
  final ValueChanged<int> onChanged;

  const MomentField({
    super.key,
    required this.label,
    required this.tripStart,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final day = dayOf(value);
    final mod = minuteOfDay(value);
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 84, child: Text(label)),
          // Full 48 dp targets (no compact density) with a spoken name.
          IconButton(
            tooltip: l.a11yDayEarlier,
            constraints: const BoxConstraints(minWidth: minTapTarget, minHeight: minTapTarget),
            onPressed: () => onChanged(value - minutesPerDay),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _pickDay(context, day, mod),
              child: Text(l.day(tripStart, day), overflow: TextOverflow.ellipsis),
            ),
          ),
          IconButton(
            tooltip: l.a11yDayLater,
            constraints: const BoxConstraints(minWidth: minTapTarget, minHeight: minTapTarget),
            onPressed: () => onChanged(value + minutesPerDay),
            icon: const Icon(Icons.chevron_right),
          ),
          PopupMenuButton<int>(
            tooltip: l.timeOfDay,
            onSelected: (m) async {
              if (m >= 0) {
                onChanged(at(day, m));
              } else {
                final t = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: mod ~/ 60, minute: mod % 60),
                );
                if (t != null) onChanged(at(day, t.hour * 60 + t.minute));
              }
            },
            itemBuilder: (_) => [
              for (final p in DayPart.values)
                PopupMenuItem(value: p.minuteOfDay, child: Text('${l.dayPart(p)} (${formatClock(p.minuteOfDay)})')),
              PopupMenuItem(value: -1, child: Text(l.exactTime)),
            ],
            child: Chip(label: Text(formatClock(value))),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDay(BuildContext context, int day, int mod) async {
    if (tripStart != null) {
      final d = await showDatePicker(
        context: context,
        initialDate: dateOfDay(tripStart!, day),
        firstDate: dateOfDay(tripStart!, -365),
        lastDate: dateOfDay(tripStart!, 365 * 2),
      );
      if (d == null) return;
      final base = DateTime(tripStart!.year, tripStart!.month, tripStart!.day);
      final newDay = DateTime(d.year, d.month, d.day).difference(base).inHours ~/ 24;
      onChanged(at(newDay, mod));
    } else {
      final picked = await showDialog<int>(
        context: context,
        builder: (c) => SimpleDialog(
          title: Text(c.l10n.pickDay),
          children: [
            SizedBox(
              width: 280,
              height: 320,
              child: GridView.count(
                crossAxisCount: 5,
                padding: const EdgeInsets.all(8),
                children: [
                  for (var d = 0; d < 60; d++)
                    Padding(
                      padding: const EdgeInsets.all(2),
                      child: d == day
                          ? FilledButton(
                              style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                              onPressed: () => Navigator.pop(c, d),
                              child: Text('${d + 1}'))
                          : OutlinedButton(
                              style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                              onPressed: () => Navigator.pop(c, d),
                              child: Text('${d + 1}')),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
      if (picked != null) onChanged(at(picked, mod));
    }
  }
}
