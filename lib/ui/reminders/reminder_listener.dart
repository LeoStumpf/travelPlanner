import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import '../../domain/reminders.dart';
import '../../state/providers.dart';
import '../../state/reminders.dart';
import '../common/l10n.dart';
import '../share/share_listener.dart';
import '../trips/trips_page.dart';
import 'reminder_texts.dart';

/// Keeps the scheduled reminders in step with the plans: whenever a trip
/// with reminders changes (or its settings do, or the app comes back to the
/// front), all reminders are scheduled anew. A tap on a reminder opens its
/// trip with the item selected.
class ReminderListener extends ConsumerStatefulWidget {
  final Widget child;
  const ReminderListener({super.key, required this.child});

  @override
  ConsumerState<ReminderListener> createState() => _ReminderListenerState();
}

class _ReminderListenerState extends ConsumerState<ReminderListener> {
  AppLifecycleListener? _lifecycle;
  ProviderSubscription<List<(TripData, ReminderSettings)>?>? _inputs;
  StreamSubscription<String>? _taps;
  Timer? _debounce;

  /// What was scheduled last, to skip identical rescheduling.
  String? _last;

  @override
  void initState() {
    super.initState();
    final scheduler = ref.read(reminderSchedulerProvider);
    if (scheduler == null) return;
    _inputs = ref.listenManual(reminderInputsProvider, (_, _) => _schedule(), fireImmediately: true);
    _lifecycle = AppLifecycleListener(onResume: () {
      ref.invalidate(reminderPermissionsProvider);
      _schedule();
    });
    _taps = scheduler.taps.listen(_open);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final p = await scheduler.launchPayload();
        if (p != null) _open(p);
      } catch (e) {
        debugPrint('Reading the launch notification failed: $e');
      }
    });
  }

  /// Plans change in bursts (a drag saves several items), so wait briefly.
  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _sync);
  }

  Future<void> _sync() async {
    final scheduler = ref.read(reminderSchedulerProvider);
    final inputs = ref.read(reminderInputsProvider);
    if (scheduler == null || inputs == null || !mounted) return;
    final l = context.l10n;
    final byTrip = {for (final (d, _) in inputs) d.trip.id: d};
    final notices = [
      for (final r in upcomingReminders(inputs, ref.read(clockProvider)()))
        l.reminderNotice(byTrip[r.tripId]!, r),
    ];
    final key = [for (final n in notices) '${n.reminder.id}@${n.reminder.fireAt}|${n.title}|${n.body}'].join('\n');
    if (key == _last) return;
    _last = key;
    try {
      await scheduler.sync(notices);
    } catch (e) {
      _last = null;
      // Reminders must never disturb the app; the next change retries.
      debugPrint('Scheduling reminders failed: $e');
    }
  }

  void _open(String payload) {
    final ids = parseReminderPayload(payload);
    final nav = navigatorKey.currentState;
    if (ids == null || nav == null) return;
    final (tripId, itemId) = ids;
    nav.popUntil((r) => r.isFirst);
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    openTrip(context, ref, tripId);
    ref.read(tripUiProvider.notifier).select(itemId);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _inputs?.close();
    _taps?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
