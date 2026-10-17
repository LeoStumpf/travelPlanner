import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reminder_scheduler.dart';
import '../domain/models.dart';
import '../domain/reminders.dart';
import 'hints.dart';
import 'providers.dart';

/// Overridden in main(); null where notifications are not available (tests
/// that do not care about them).
final reminderSchedulerProvider = Provider<ReminderScheduler?>((ref) => null);

const _prefsKey = 'tripReminders';

/// Reminder settings per trip id, kept in the shared preferences (the same
/// instance as the hints, see [hintPrefsProvider]); see [ReminderSettings]
/// for why they are not part of the trip.
class ReminderSettingsNotifier extends Notifier<Map<String, ReminderSettings>> {
  @override
  Map<String, ReminderSettings> build() {
    final raw = ref.watch(hintPrefsProvider)?.getString(_prefsKey);
    if (raw == null) return const {};
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return const {};
      return {for (final e in j.entries) '${e.key}': ReminderSettings.fromJson(e.value)};
    } on FormatException {
      return const {};
    }
  }

  ReminderSettings of(String tripId) => state[tripId] ?? ReminderSettings.off;

  void set(String tripId, ReminderSettings s) {
    state = {...state, tripId: s};
    ref.read(hintPrefsProvider)?.setString(
          _prefsKey,
          jsonEncode({for (final e in state.entries) if (e.value != ReminderSettings.off) e.key: e.value.toJson()}),
        );
  }
}

final reminderSettingsProvider =
    NotifierProvider<ReminderSettingsNotifier, Map<String, ReminderSettings>>(ReminderSettingsNotifier.new);

/// The settings of one trip (off when never set).
final tripReminderSettingsProvider = Provider.family<ReminderSettings, String>(
  (ref, tripId) => ref.watch(reminderSettingsProvider)[tripId] ?? ReminderSettings.off,
);

/// Every live (not trashed) trip with reminders switched on, with its
/// data. Null while any of them is still loading. Rebuilt whenever one of
/// these plans or the settings change, which reschedules the reminders.
final reminderInputsProvider = Provider<List<(TripData, ReminderSettings)>?>((ref) {
  final settings = ref.watch(reminderSettingsProvider);
  final enabled = [for (final e in settings.entries) if (e.value.enabled) e];
  if (enabled.isEmpty) return const [];
  final trips = ref.watch(tripsProvider);
  if (!trips.hasValue) return null;
  final live = {for (final t in trips.value!) t.id};
  final out = <(TripData, ReminderSettings)>[];
  for (final e in enabled) {
    if (!live.contains(e.key)) continue;
    final data = ref.watch(tripDataProvider(e.key));
    if (!data.hasValue) {
      if (data.hasError) continue;
      return null;
    }
    final d = data.value;
    if (d != null) out.add((d, e.value));
  }
  return out;
});

/// What the phone allows; refreshed when the app comes back to the front.
final reminderPermissionsProvider = FutureProvider<ReminderPermissions>(
  (ref) async => await ref.watch(reminderSchedulerProvider)?.permissions() ?? const ReminderPermissions(),
);
