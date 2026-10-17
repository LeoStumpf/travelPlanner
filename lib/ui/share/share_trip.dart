// "Share…" in a trip's menu: the itinerary as text or PDF and the calendar
// (ICS) for fellow travellers, via the system share sheet.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/ics.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../common/dialogs.dart';
import '../common/l10n.dart';
import 'itinerary_doc.dart';
import 'itinerary_pdf.dart';

enum ShareFormat { text, copy, pdf, calendar }

Future<void> showShareSheet(BuildContext context, WidgetRef ref, TripData data) async {
  final l = context.l10n;
  final noDate = data.trip.startDate == null;
  final format = await showModalBottomSheet<ShareFormat>(
    context: context,
    showDragHandle: true,
    // As tall as its content; scrolls on small phones and in landscape.
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(l.shareSheetTitle, style: Theme.of(c).textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                noDate ? '${l.shareSheetHint}\n${l.shareNoStartDate}' : l.shareSheetHint,
                style: Theme.of(c).textTheme.bodySmall,
              ),
            ),
            ListTile(
              key: const ValueKey('share-text'),
              leading: const Icon(Icons.notes),
              title: Text(l.shareAsText),
              subtitle: Text(l.shareAsTextSub),
              onTap: () => Navigator.pop(c, ShareFormat.text),
              trailing: IconButton(
                key: const ValueKey('share-copy'),
                tooltip: l.shareCopyText,
                icon: const Icon(Icons.copy),
                onPressed: () => Navigator.pop(c, ShareFormat.copy),
              ),
            ),
            ListTile(
              key: const ValueKey('share-pdf'),
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(l.shareAsPdf),
              subtitle: Text(l.shareAsPdfSub),
              onTap: () => Navigator.pop(c, ShareFormat.pdf),
            ),
            ListTile(
              key: const ValueKey('share-ics'),
              leading: const Icon(Icons.event_outlined),
              title: Text(l.shareCalendar),
              subtitle: Text(noDate ? '${l.shareCalendarSub} · ${l.shareCalendarNeedsDate}' : l.shareCalendarSub),
              onTap: () => Navigator.pop(c, ShareFormat.calendar),
            ),
          ],
        ),
      ),
    ),
  );
  if (format == null || !context.mounted) return;
  await shareTrip(context, ref, data, format);
}

/// Shares [data] as [format]. Errors end up in a snack bar.
Future<void> shareTrip(BuildContext context, WidgetRef ref, TripData data, ShareFormat format) async {
  final l = context.l10n;
  final sharer = ref.read(sharerProvider);
  final now = ref.read(clockProvider)();
  final subject = l.shareSubject(data.trip.title);
  try {
    switch (format) {
      case ShareFormat.text || ShareFormat.copy:
        final text = itineraryText(ItineraryWriter(l, data).document(now: now), l);
        if (format == ShareFormat.copy) {
          await Clipboard.setData(ClipboardData(text: text));
          if (context.mounted) showSnack(context, l.shareTextCopied);
        } else {
          await sharer.shareText(text, subject: subject);
        }
      case ShareFormat.pdf:
        final fonts = await PdfFonts.load();
        final bytes = await itineraryPdf(ItineraryWriter(l, data).document(now: now), l, fonts);
        await sharer.shareFile(bytes, name: shareFileName(data.trip, 'pdf'), mime: 'application/pdf', subject: subject);
      case ShareFormat.calendar:
        if (calendarItems(data).isEmpty) {
          showSnack(context, l.shareNothingToExport);
          return;
        }
        var d = data;
        if (d.trip.startDate == null) {
          final start = await _askStartDate(context, now);
          if (start == null || !context.mounted) return;
          final trip = d.trip.copyWith(startDate: start);
          await ref.read(planActionsProvider).record(trip.id, l.stepStartDateSet, (r) => r.saveTrip(trip));
          d = TripData(trip: trip, items: d.items, cards: d.cards, edges: d.edges, attachments: d.attachments);
        }
        final w = ItineraryWriter(l, d);
        final ics = buildIcs(d, now: now, summary: w.eventSummary, describe: w.eventDescription);
        await sharer.shareFile(utf8.encode(ics), name: shareFileName(d.trip, 'ics'), mime: 'text/calendar', subject: subject);
    }
  } catch (e) {
    if (context.mounted) showSnack(context, l.shareFailed('$e'));
  }
}

/// Explains why the calendar needs a date, then asks for day 1's date.
Future<DateTime?> _askStartDate(BuildContext context, DateTime now) async {
  final l = context.l10n;
  final pick = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(l.shareStartDateTitle),
      content: Text(l.shareStartDateBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.sharePickDate)),
      ],
    ),
  );
  if (pick != true || !context.mounted) return null;
  final d = await showDatePicker(
    context: context,
    initialDate: now,
    firstDate: DateTime(now.year - 5),
    lastDate: DateTime(now.year + 10),
  );
  return d == null ? null : DateTime(d.year, d.month, d.day);
}
