import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models.dart';
import 'l10n.dart';

/// Route text of transport [t]: the linked stays, falling back to the
/// departure / arrival station for open ends (flight out and home).
String transportRoute(TripData data, PlanItem t) =>
    '${data.item(t.fromId)?.title ?? t.departureStation ?? '?'} → '
    '${data.item(t.toId)?.title ?? t.arrivalStation ?? '?'}';

/// The ticket details of a transport like on a boarding pass: from / to
/// station, number, seat and the booking reference, which is copied with
/// one tap. Shows nothing when no detail is filled in.
class TransportDetailsPanel extends StatefulWidget {
  final PlanItem item;

  /// Called after the booking reference was copied, e.g. to show a
  /// snackbar where one is visible (not inside a bottom sheet).
  final VoidCallback? onCopied;

  const TransportDetailsPanel({super.key, required this.item, this.onCopied});

  @override
  State<TransportDetailsPanel> createState() => _TransportDetailsPanelState();
}

class _TransportDetailsPanelState extends State<TransportDetailsPanel> {
  /// Shows a check mark on the copy button for a moment after copying.
  bool _copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy(String ref) async {
    await Clipboard.setData(ClipboardData(text: ref));
    if (!mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
    widget.onCopied?.call();
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.item;
    if (!i.hasTransportDetails) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l = context.l10n;
    final label = theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);
    final value = theme.textTheme.titleSmall;

    Widget field(String name, String text, {CrossAxisAlignment align = CrossAxisAlignment.start, Key? key}) =>
        Column(
          key: key,
          crossAxisAlignment: align,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name, style: label),
            Text(text, style: value, textAlign: align == CrossAxisAlignment.end ? TextAlign.end : null),
          ],
        );

    final hasStations = i.departureStation != null || i.arrivalStation != null;
    return Container(
      key: ValueKey('transport-details-${i.id}'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasStations)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: field(l.fromLabel, i.departureStation ?? '—')),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: Icon(Icons.arrow_forward, size: 18, color: scheme.onSurfaceVariant),
                  ),
                  Expanded(child: field(l.toLabel, i.arrivalStation ?? '—', align: CrossAxisAlignment.end)),
                ],
              ),
            ),
          if (i.transportNumber != null || i.seat != null)
            Padding(
              padding: EdgeInsets.only(top: hasStations ? 8 : 0, right: 8),
              child: Wrap(spacing: 24, runSpacing: 6, children: [
                if (i.transportNumber != null) field(l.transportNumberLabel, i.transportNumber!),
                if (i.seat != null) field(l.seatLabel, i.seat!),
              ]),
            ),
          if (i.bookingRef case final ref?)
            Padding(
              padding: EdgeInsets.only(top: hasStations || i.transportNumber != null || i.seat != null ? 4 : 0),
              child: Row(children: [
                Expanded(
                  child: field(l.bookingRefLabel, ref),
                ),
                IconButton(
                  key: const ValueKey('copy-booking-ref'),
                  tooltip: _copied ? l.bookingRefCopied : l.copyBookingRef,
                  icon: Icon(_copied ? Icons.check : Icons.copy, size: 20),
                  onPressed: () => _copy(ref),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}
