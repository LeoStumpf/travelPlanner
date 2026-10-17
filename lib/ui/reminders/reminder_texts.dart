import 'package:flutter/material.dart';

import '../../data/reminder_scheduler.dart';
import '../../domain/models.dart';
import '../../domain/reminders.dart';
import '../../domain/time.dart';
import '../common/l10n.dart';

/// Words a [Reminder] of [data] in the language of [l].
extension ReminderWording on AppLocalizations {
  /// "Departure 07:30: Colombo → Kandy"; with the day when the reminder
  /// comes long before (from 6 h), as it may be another day by then.
  String reminderTitle(TripData data, Reminder r) {
    final item = data.item(r.itemId);
    final title = item?.title ?? '';
    final time =
        r.lead >= 360 ? moment(data.trip.startDate, r.eventMinute) : formatClock(r.eventMinute);
    return switch (r.type) {
      ReminderType.departure => reminderDepartureTitle(time, title),
      ReminderType.checkIn => reminderCheckInTitle(time, title),
      ReminderType.checkOut => reminderCheckOutTitle(time, title),
    };
  }

  /// "in 2h · Colombo Fort · IC 1009 · Car 3, seat 42 · ABC123".
  String reminderBody(TripData data, Reminder r) {
    final item = data.item(r.itemId);
    final where = switch (r.type) {
      ReminderType.departure => item?.departureStation ?? data.item(item?.fromId ?? '')?.title,
      _ => item?.placeName,
    };
    return [
      reminderIn(duration(r.lead, withMinutes: true)),
      ?where,
      if (r.type == ReminderType.departure) ...[?item?.transportNumber, ?item?.seat, ?item?.bookingRef],
    ].where((s) => s.trim().isNotEmpty).join(' · ');
  }

  ReminderNotice reminderNotice(TripData data, Reminder r) =>
      ReminderNotice(r, reminderTitle(data, r), reminderBody(data, r));

  /// "Off" or "1 day, 2h before" for a settings row.
  String reminderSummary(ReminderSettings s) => !s.enabled
      ? remindersOff
      : remindersLead(s.leads.map((m) => duration(m, withMinutes: true)).join(', '));
}

IconData reminderIcon(ReminderType t) => switch (t) {
      ReminderType.departure => Icons.departure_board,
      ReminderType.checkIn => Icons.login,
      ReminderType.checkOut => Icons.logout,
    };
