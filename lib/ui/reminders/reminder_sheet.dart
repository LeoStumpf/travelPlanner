import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import '../../domain/reminders.dart';
import '../../state/providers.dart';
import '../../state/reminders.dart';
import '../common/l10n.dart';
import 'reminder_texts.dart';

/// ⋮ → Reminders (also reachable from the trip settings): switch reminders
/// on for trip [tripId], pick the lead times and what to be reminded of,
/// and see the next reminders. Changes apply at once. Opened from the trip
/// settings, [canSetStartDate] is false: the dialog has its own start date
/// field and would overwrite a date set here when saved.
Future<void> showReminderSheet(BuildContext context, String tripId, {bool canSetStartDate = true}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ReminderSheet(tripId: tripId, canSetStartDate: canSetStartDate),
    );

/// How many upcoming reminders the sheet lists.
const _previewCount = 5;

class ReminderSheet extends ConsumerWidget {
  final String tripId;
  final bool canSetStartDate;
  const ReminderSheet({super.key, required this.tripId, this.canSetStartDate = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final data = ref.watch(tripDataProvider(tripId)).value;
    final s = ref.watch(tripReminderSettingsProvider(tripId));
    final perms = ref.watch(reminderPermissionsProvider).value;
    final notifier = ref.read(reminderSettingsProvider.notifier);
    // Applied to the current settings, so quick taps never undo each other.
    void update(ReminderSettings Function(ReminderSettings) change) => notifier.set(tripId, change(notifier.of(tripId)));

    final upcoming = data == null || !s.enabled
        ? const <Reminder>[]
        : remindersFor(data, s, ref.read(clockProvider)());

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(l.reminders, style: theme.textTheme.titleLarge),
            ),
            SwitchListTile(
              key: const ValueKey('reminders-switch'),
              secondary: const Icon(Icons.notifications_active_outlined),
              title: Text(l.remindersSwitch),
              subtitle: Text(l.remindersSwitchHint),
              value: s.enabled,
              onChanged: (on) async {
                update((s) => s.copyWith(enabled: on));
                if (on) await _askPermission(context, ref);
              },
            ),
            if (s.enabled) ...[
              if (data != null && data.trip.startDate == null)
                _Notice(
                  key: const ValueKey('reminders-no-date'),
                  icon: Icons.event_busy,
                  text: l.remindersNeedStartDate,
                  action: canSetStartDate ? l.remindersSetStartDate : null,
                  onAction: () => _setStartDate(context, ref, data),
                ),
              if (perms != null && !perms.notifications)
                _Notice(
                  key: const ValueKey('reminders-denied'),
                  icon: Icons.notifications_off_outlined,
                  text: l.remindersNotificationsOff,
                  action: l.remindersAllow,
                  onAction: () => _askPermission(context, ref, openSettings: true),
                ),
              if (perms != null && perms.notifications && !perms.exactAlarms)
                _Notice(
                  key: const ValueKey('reminders-inexact'),
                  icon: Icons.alarm,
                  text: l.remindersInexact,
                  action: l.remindersAllowExact,
                  onAction: () async {
                    await ref.read(reminderSchedulerProvider)?.requestExactAlarms();
                    if (context.mounted) ref.invalidate(reminderPermissionsProvider);
                  },
                ),
              heading(l.remindersWhen),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(spacing: 8, runSpacing: 4, children: [
                  for (final m in reminderLeadChoices)
                    FilterChip(
                      key: ValueKey('reminder-lead-$m'),
                      label: Text(l.remindersLead(l.duration(m, withMinutes: true))),
                      selected: s.leads.contains(m),
                      onSelected: (_) => update((s) => s.toggleLead(m)),
                    ),
                ]),
              ),
              heading(l.remindersFor),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(spacing: 8, runSpacing: 4, children: [
                  for (final t in ReminderType.values)
                    FilterChip(
                      key: ValueKey('reminder-type-${t.name}'),
                      avatar: Icon(reminderIcon(t), size: 18),
                      label: Text(switch (t) {
                        ReminderType.departure => l.remindersDepartures,
                        ReminderType.checkIn => l.remindersCheckIn,
                        ReminderType.checkOut => l.remindersCheckOut,
                      }),
                      showCheckmark: false,
                      selected: s.covers(t),
                      onSelected: (on) => update((s) => switch (t) {
                        ReminderType.departure => s.copyWith(departures: on),
                        ReminderType.checkIn => s.copyWith(checkIns: on),
                        ReminderType.checkOut => s.copyWith(checkOuts: on),
                      }),
                    ),
                ]),
              ),
              if (data != null && data.trip.startDate != null) ...[
                heading(l.remindersUpcoming),
                if (upcoming.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(l.remindersNone, style: theme.textTheme.bodyMedium),
                  ),
                for (final r in upcoming.take(_previewCount))
                  ListTile(
                    key: ValueKey('reminder-${r.id}'),
                    dense: true,
                    leading: Icon(reminderIcon(r.type)),
                    title: Text(l.reminderTitle(data, r)),
                    subtitle: Text(l.remindersFiresAt(l.dateTime(r.fireAt.toLocal()))),
                  ),
                if (upcoming.length > _previewCount)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(l.remindersMore(upcoming.length - _previewCount)),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// Asks for the notification permission (Android 13+); after a denial
  /// the system no longer asks, so [openSettings] opens the app's settings.
  Future<void> _askPermission(BuildContext context, WidgetRef ref, {bool openSettings = false}) async {
    final scheduler = ref.read(reminderSchedulerProvider);
    if (scheduler == null) return;
    try {
      final granted = await scheduler.requestNotifications();
      if (!granted && openSettings) await scheduler.openSettings();
    } catch (e) {
      debugPrint('Asking for the notification permission failed: $e');
    }
    if (context.mounted) ref.invalidate(reminderPermissionsProvider);
  }

  Future<void> _setStartDate(BuildContext context, WidgetRef ref, TripData data) async {
    final l = context.l10n;
    final now = ref.read(clockProvider)();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (d == null || !context.mounted) return;
    final trip = data.trip.copyWith(startDate: DateTime(d.year, d.month, d.day));
    await ref.read(planActionsProvider).record(trip.id, l.stepStartDateSet, (r) => r.saveTrip(trip));
  }
}

/// A hint with (usually) one action, e.g. the missing start date.
class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback onAction;
  const _Notice({super.key, required this.icon, required this.text, required this.action, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: TextStyle(color: scheme.onSecondaryContainer))),
          ]),
          if (action != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onAction, child: Text(action!)),
            )
          else
            const SizedBox(height: 4),
        ]),
      ),
    );
  }
}
