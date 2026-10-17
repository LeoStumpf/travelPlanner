import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../../domain/agenda.dart';
import '../../domain/analysis.dart';
import '../../domain/models.dart';
import '../../domain/time.dart';
import '../../state/providers.dart';
import '../common/dialogs.dart';
import '../common/item_sheet.dart';
import '../common/l10n.dart';
import '../common/style.dart';
import '../common/transport_details.dart';

/// Opens a local file in another app and tells whether that worked (no
/// file, no app for the type); overridden in tests.
typedef FileOpener = Future<bool> Function(String path, String mime);

final fileOpenerProvider = Provider<FileOpener>(
  (ref) => (path, mime) async {
    try {
      return (await OpenFilex.open(path, type: mime)).type == ResultType.done;
    } catch (_) {
      return false;
    }
  },
);

/// The "Today" view for being on the road: a strip of trip days on top and
/// the selected day below – where you are, where you sleep, the next
/// transport and the day's programme, with tickets one tap away. Reads only
/// local data, so it works offline.
class AgendaView extends ConsumerStatefulWidget {
  final TripData data;
  const AgendaView({super.key, required this.data});

  @override
  ConsumerState<AgendaView> createState() => _AgendaViewState();
}

class _AgendaViewState extends ConsumerState<AgendaView> {
  /// Selected trip day; null = the default (today while running).
  int? _day;
  final _chipKeys = <int, GlobalKey>{};

  /// Refreshes "next transport" and the greyed-out past events.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealChip(animate: false));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _select(int day) {
    setState(() => _day = day);
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealChip());
  }

  /// Scrolls the day strip so the selected chip is visible.
  void _revealChip({bool animate = true}) {
    if (!mounted) return;
    final ctx = _chipKeys[_selectedDay]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        alignment: 0.5, duration: animate ? const Duration(milliseconds: 250) : Duration.zero);
  }

  int get _selectedDay {
    final data = widget.data;
    final (first, last) = dayRange(data.items, plannedDays: data.trip.plannedDays);
    final today = tripDayOn(data.trip, ref.read(clockProvider)());
    final fallback = today != null && today >= first && today <= last ? today : first;
    return (_day ?? fallback).clamp(first, last);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final l = context.l10n;
    final now = ref.watch(clockProvider)();
    final (first, last) = dayRange(data.items, plannedDays: data.trip.plannedDays);
    final today = tripDayOn(data.trip, now);
    final todayInTrip = today != null && today >= first && today <= last;
    final day = _selectedDay;
    final nowMinute = tripMinuteAt(data.trip, now);
    final agenda = agendaFor(data.items, day, now: nowMinute);
    final start = data.trip.startDate;
    final relative = l.relativeDay(start, day, today);
    final theme = Theme.of(context);

    return Column(
      children: [
        SizedBox(
          height: 52,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                for (var d = first; d <= last; d++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: _chipKeys.putIfAbsent(d, () => GlobalKey(debugLabel: 'agenda-day-$d')),
                      visualDensity: VisualDensity.compact,
                      avatar: d == today ? const Icon(Icons.today, size: 16) : null,
                      label: Text(l.relativeDay(start, d, today)),
                      selected: d == day,
                      onSelected: (_) => _select(d),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            key: ValueKey('agenda-day-$day'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(relative, style: theme.textTheme.headlineSmall),
                      if (start != null)
                        Text(l.day(start, day, withDayNumber: true), style: theme.textTheme.bodyMedium),
                    ],
                  ),
                  if (todayInTrip && day != today)
                    FilledButton.tonalIcon(
                      key: const ValueKey('agenda-jump-today'),
                      onPressed: () => _select(today),
                      icon: const Icon(Icons.today),
                      label: Text(l.agendaJumpToToday),
                    ),
                ],
              ),
              if (start == null)
                _InfoBanner(l.agendaNoStartDate)
              else if (today! < first)
                _InfoBanner(l.agendaStartsIn(first - today))
              else if (today > last)
                _InfoBanner(l.agendaEnded),
              if (agenda.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(l.agendaNothingPlanned, textAlign: TextAlign.center),
                ),
              if (agenda.stays.isNotEmpty) _Header(l.agendaWhere),
              for (final s in agenda.stays)
                _ItemCard(
                  data: data,
                  item: s,
                  lines: [
                    if (s.placeName != null && s.placeName != s.title) s.placeName!,
                    timeSummary(l, s, start),
                  ],
                ),
              if (agenda.lodging.isNotEmpty || agenda.needsBed) _Header(l.kindAccommodation),
              for (final a in agenda.lodging)
                _ItemCard(
                  data: data,
                  item: a,
                  lines: [
                    if (a.placeName != null) a.placeName!,
                    l.agendaCheckIn(agenda.checksIn(a) ? formatClock(a.start!) : l.moment(start, a.start!)),
                    l.agendaCheckOut(agenda.checksOut(a) ? formatClock(a.end!) : l.moment(start, a.end!)),
                  ],
                ),
              if (agenda.needsBed)
                Card(
                  key: const ValueKey('agenda-no-bed'),
                  color: theme.colorScheme.errorContainer,
                  child: ListTile(
                    leading: Icon(Icons.hotel_outlined, color: theme.colorScheme.onErrorContainer),
                    title: Text(l.agendaNoBed, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                    subtitle: agenda.lodgingOptions.isEmpty
                        ? null
                        : Text(l.agendaOptionsCount(agenda.lodgingOptions.length),
                            style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                  ),
                ),
              for (final o in agenda.lodgingOptions)
                _ItemCard(data: data, item: o, lines: [if (o.placeName != null) o.placeName!, timeSummary(l, o, start)]),
              if (agenda.nextTransport case final t?) ...[
                _Header(l.agendaNextTransport),
                _ItemCard(
                  key: const ValueKey('agenda-next-transport'),
                  data: data,
                  item: t,
                  highlight: true,
                  lines: [
                    _route(data, t),
                    l.agendaDeparts(dayOf(t.start!) == day ? formatClock(t.start!) : l.moment(start, t.start!)),
                    l.agendaArrives(dayOf(t.end!) == day ? formatClock(t.end!) : l.moment(start, t.end!)),
                  ],
                ),
              ],
              if (agenda.events.isNotEmpty) _Header(l.agendaProgramme),
              for (final e in agenda.events)
                Opacity(
                  opacity: day == today && nowMinute != null && e.end! <= nowMinute ? 0.5 : 1,
                  child: _ItemCard(
                    data: data,
                    item: e,
                    time: dayOf(e.start!) == day ? formatClock(e.start!) : '…',
                    lines: [
                      if (e.kind == ItemKind.transport) _route(data, e) else if (e.placeName != null) e.placeName!,
                      timeSummary(l, e, start),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _route(TripData data, PlanItem t) => transportRoute(data, t);
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}

class _InfoBanner extends StatelessWidget {
  final String text;
  const _InfoBanner(this.text);

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(top: 12),
        child: ListTile(leading: const Icon(Icons.info_outline), title: Text(text)),
      );
}

/// One plan item on the agenda: icon, title, a few detail lines and its
/// tickets as chips that open the file directly. Tapping the card opens the
/// item sheet.
class _ItemCard extends ConsumerWidget {
  final TripData data;
  final PlanItem item;
  final List<String> lines;
  final String? time;
  final bool highlight;

  const _ItemCard({
    super.key,
    required this.data,
    required this.item,
    required this.lines,
    this.time,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final tickets = ticketsFor(data, item.id);
    final repo = ref.read(repositoryProvider);
    return Card(
      key: ValueKey('agenda-item-${item.id}'),
      color: highlight ? theme.colorScheme.primaryContainer : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showItemSheet(context, ref, data.trip.id, item.id),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (time != null)
                SizedBox(
                  width: 48,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(time!, style: theme.textTheme.labelLarge),
                  ),
                ),
              CircleAvatar(
                radius: 18,
                backgroundColor: kindColor(item.kind).withValues(alpha: item.isOption ? 0.4 : 1),
                child: Icon(itemIcon(item), color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(item.title, style: theme.textTheme.titleMedium)),
                      if (item.status == ItemStatus.booked)
                        Tooltip(message: l.statusBooked, child: const Icon(Icons.verified, size: 18)),
                    ]),
                    for (final line in lines) Text(line, style: theme.textTheme.bodyMedium),
                    if (item.kind == ItemKind.transport)
                      TransportDetailsPanel(item: item, onCopied: () => showSnack(context, l.bookingRefCopied)),
                    if (tickets.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(spacing: 6, runSpacing: 4, children: [
                          for (final a in tickets)
                            ActionChip(
                              key: ValueKey('ticket-${a.id}'),
                              visualDensity: VisualDensity.compact,
                              tooltip: l.agendaOpenFile(a.fileName),
                              avatar: Icon(
                                a.isImage
                                    ? Icons.image
                                    : (a.mime == 'application/pdf' ? Icons.picture_as_pdf : Icons.confirmation_number),
                                size: 16,
                              ),
                              label: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 180),
                                child: Text(a.fileName, overflow: TextOverflow.ellipsis),
                              ),
                              onPressed: () async {
                                final ok = await ref.read(fileOpenerProvider)(repo.files.fileFor(a).path, a.mime);
                                if (!ok && context.mounted) showSnack(context, l.agendaOpenFailed(a.fileName));
                              },
                            ),
                        ]),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
