import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/analysis.dart';
import '../../domain/models.dart';
import '../../domain/timeline.dart';
import '../../domain/zones.dart';
import '../../state/providers.dart';
import 'dialogs.dart';
import 'item_sheet.dart';
import 'l10n.dart';
import 'style.dart';

/// Places the unscheduled [item] on trip [day] with kind-specific default
/// times (see [defaultSlotOn]) as one undoable step.
Future<void> scheduleItemOn(BuildContext context, WidgetRef ref, TripData data, PlanItem item, int day) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final actions = ref.read(planActionsProvider);
  // The caller (e.g. the tray) may be gone after the save; read up front.
  final ui = ref.read(tripUiProvider.notifier);
  final r = scheduleOn(data.items, item.id, day, ref.read(tripUiProvider).shiftMode, zones: data.zones);
  final label = l.stepScheduled(item.title, l.day(data.trip.startDate, day));
  await actions.applySchedule(data, r, label);
  ui.select(item.id);
  final step = actions.lastStep(data.trip.id);
  final others = r.changedIds.length - 1;
  showUndoSnack(
    messenger,
    [label, if (others > 0) l.othersMovedAlong(others)].join(' · '),
    () => actions.undoStep(data.trip.id, step),
  );
}

/// "Schedule on …": the suggested day first, any other trip day below,
/// plus (with [withDetails]) a way to the item's details.
Future<void> showScheduleSheet(
  BuildContext context,
  WidgetRef ref,
  TripData data,
  PlanItem item, {
  bool withDetails = true,
}) {
  final (first, last) = dayRange(data.items, plannedDays: data.trip.plannedDays);
  final suggested = suggestedDay(item, data.items, plannedDays: data.trip.plannedDays, zones: data.zones);
  // One day past the end, so a new place can be appended.
  final from = suggested < first ? suggested : first;
  final to = suggested > last + 1 ? suggested : last + 1;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (c) {
      final l = c.l10n;
      final theme = Theme.of(c);
      final tripStart = data.trip.startDate;
      void pick(int day) {
        Navigator.pop(c);
        scheduleItemOn(context, ref, data, item, day);
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(itemIcon(item), color: kindColor(item.kind)),
                const SizedBox(width: 12),
                Expanded(child: Text(item.title, style: theme.textTheme.titleLarge)),
              ],
            ),
            const SizedBox(height: 4),
            Text(l.scheduleDefaultsHint(item.kind.name)),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('schedule-suggested'),
              onPressed: () => pick(suggested),
              icon: const Icon(Icons.event_available),
              label: Text(l.scheduleOnDay(l.day(tripStart, suggested))),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 6),
              child: Text(l.scheduleOtherDay, style: theme.textTheme.titleSmall),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var d = from; d <= to; d++)
                  ActionChip(
                    key: ValueKey('schedule-day-$d'),
                    label: Text(l.day(tripStart, d)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => pick(d),
                  ),
              ],
            ),
            if (withDetails) ...[
              const Divider(height: 32),
              ListTile(
                key: const ValueKey('schedule-details'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline),
                title: Text(l.details),
                onTap: () {
                  Navigator.pop(c);
                  showItemSheet(context, ref, data.trip.id, item.id);
                },
              ),
            ],
          ],
        ),
      );
    },
  );
}
