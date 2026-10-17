import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/analysis.dart';
import '../../domain/models.dart';
import '../../domain/scheduler.dart';
import '../../domain/time.dart';
import '../../domain/zones.dart';
import '../../state/providers.dart';
import '../common/dialogs.dart';
import '../common/l10n.dart';
import '../common/style.dart';
import '../common/zone_picker.dart';
import 'attachments_section.dart';
import 'place_search.dart';
import 'time_fields.dart';

/// Opens the editor for [item], or for a new item of [newKind].
/// Returns the id of the saved item (null when cancelled).
Future<String?> openItemEditor(
  BuildContext context,
  TripData data, {
  PlanItem? item,
  ItemKind? newKind,
  int? atDay,
  String? parentHint,
  String? title,
  double? lat,
  double? lng,
}) =>
    Navigator.of(context).push<String>(MaterialPageRoute(
      fullscreenDialog: item == null,
      builder: (_) => ItemEditorPage(
        tripId: data.trip.id,
        initial: item ??
            _newItem(data, newKind ?? ItemKind.stay, atDay, parentHint, title)
                .copyWith(lat: lat, lng: lng, placeName: lat == null ? null : context.l10n.pickedOnMap),
        isNew: item == null,
      ),
    ));

/// Opens the editor for a new transport from stay [from] to stay [to]
/// (either may be null), timed by [suggestTransportTimes].
Future<String?> openTransportEditor(BuildContext context, TripData data, {PlanItem? from, PlanItem? to}) {
  final base = _newItem(data, ItemKind.transport, null, null, null);
  final times = suggestTransportTimes(from, to, zones: data.zones);
  final title = switch ((from, to)) {
    (final f?, final t?) => '${f.title} → ${t.title}',
    (null, final t?) => context.l10n.transportTo(t.title),
    (final f?, null) => context.l10n.transportFrom(f.title),
    _ => '',
  };
  final initial = base.copyWith(
    fromId: from?.id,
    toId: to?.id,
    title: title,
    start: times?.$1 ?? base.start,
    end: times?.$2 ?? base.end,
  );
  return Navigator.of(context).push<String>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => ItemEditorPage(tripId: data.trip.id, initial: initial, isNew: true),
  ));
}

PlanItem _newItem(TripData data, ItemKind kind, int? atDay, String? parentHint, String? title) {
  final chain = stayChain(data.items, zones: data.zones);
  final hint = data.item(parentHint);
  // Stay the new thing relates to: the selected one, else the last one.
  final stay = hint?.kind == ItemKind.stay
      ? hint
      : (hint != null ? data.item(hint.parentId ?? hint.fromId) : null) ?? chain.lastOrNull;
  final base = PlanItem(
    id: newId(),
    tripId: data.trip.id,
    kind: kind,
    title: title ?? '',
    status: ItemStatus.planned,
    createdAt: DateTime.now(),
  );
  switch (kind) {
    case ItemKind.stay:
      final day = atDay ?? (chain.isEmpty ? 0 : lastDayOf(chain.last.end!));
      return base.copyWith(start: at(day, defaultStayArrival), end: at(day + 2, defaultStayDeparture));
    case ItemKind.accommodation:
      if (stay == null || !stay.isScheduled) {
        final d = atDay ?? 0;
        return base.copyWith(start: at(d, defaultCheckIn), end: at(d + 1, defaultCheckOut));
      }
      final first = atDay ?? dayOf(stay.start!);
      final last = lastDayOf(stay.end!);
      return base.copyWith(
        parentId: stay.id,
        start: at(first, defaultCheckIn),
        end: at(last > first ? last : first + 1, defaultCheckOut),
        status: ItemStatus.option,
      );
    case ItemKind.activity:
      final d = atDay ?? (stay?.isScheduled == true ? dayOf(stay!.start!) + 1 : 0);
      return base.copyWith(parentId: stay?.id, start: at(d, 10 * 60), end: at(d, 12 * 60), status: ItemStatus.idea);
    case ItemKind.transport:
      final from = stay;
      final idx = from == null ? -1 : chain.indexWhere((s) => s.id == from.id);
      final to = idx >= 0 && idx + 1 < chain.length ? chain[idx + 1] : null;
      final d = atDay ?? (from?.isScheduled == true ? lastDayOf(from!.end!) : 0);
      return base.copyWith(
        fromId: from?.id,
        toId: to?.id,
        mode: TransportMode.train,
        title: from != null && to != null ? '${from.title} → ${to.title}' : base.title,
        start: at(d, 10 * 60),
        end: at(d, 13 * 60),
      );
  }
}

class ItemEditorPage extends ConsumerStatefulWidget {
  final String tripId;
  final PlanItem initial;
  final bool isNew;

  const ItemEditorPage({super.key, required this.tripId, required this.initial, required this.isNew});

  @override
  ConsumerState<ItemEditorPage> createState() => _ItemEditorPageState();
}

class _ItemEditorPageState extends ConsumerState<ItemEditorPage> {
  late PlanItem _i = widget.initial;
  late final _title = TextEditingController(text: _i.title);
  late final _notes = TextEditingController(text: _i.notes);
  // Transport ticket details.
  late final _departure = TextEditingController(text: _i.departureStation);
  late final _arrival = TextEditingController(text: _i.arrivalStation);
  late final _number = TextEditingController(text: _i.transportNumber);
  late final _seat = TextEditingController(text: _i.seat);
  late final _bookingRef = TextEditingController(text: _i.bookingRef);
  late bool _scheduled = _i.isScheduled;
  late int _start = _i.start ?? at(0, defaultStayArrival);
  late int _end = _i.end ?? at(2, defaultStayDeparture);
  bool _saved = false;
  // Set once the user chose to leave (saved, discarded or deleted).
  bool _leaving = false;
  // True while a save runs, so a second tap or back press cannot save or pop twice.
  bool _busy = false;
  late final String _initialSnapshot;

  @override
  void initState() {
    super.initState();
    _initialSnapshot = _snapshot();
  }

  /// Everything the user can change, in a comparable form.
  String _snapshot() => jsonEncode({
        'item': _i.toJson(),
        'title': _title.text.trim(),
        'notes': _notes.text,
        'details': [for (final c in _detailControllers) c.text.trim()],
        'scheduled': _scheduled,
        if (_scheduled) 'start': _start,
        if (_scheduled) 'end': _end,
      });

  bool _isDirty(TripData data) =>
      _snapshot() != _initialSnapshot ||
      // Attachments of an existing item are stored right away; those of a new one are lost unless it is saved.
      (widget.isNew && data.attachmentsOf(_i.id).isNotEmpty);

  /// Back gesture / app bar back: leave directly when nothing changed, else ask.
  Future<void> _onPopBlocked(TripData data) async {
    if (_leaving || _busy) return;
    if (!_isDirty(data)) return _leave();
    final choice = await askLeave(context);
    if (!mounted) return;
    switch (choice) {
      case LeaveChoice.save:
        await _save(data);
      case LeaveChoice.discard:
        _leave();
      case LeaveChoice.keepEditing:
        break;
    }
  }

  void _leave([String? result]) {
    _leaving = true;
    // A new item that was never saved must not leave attachments behind.
    // Done here and not in dispose(), where ref must not be used any more.
    if (widget.isNew && !_saved) {
      final data = ref.read(tripDataProvider(widget.tripId)).value;
      final repo = ref.read(repositoryProvider);
      for (final a in data?.attachmentsOf(_i.id) ?? const <Attachment>[]) {
        repo.deleteAttachment(a);
      }
    }
    Navigator.pop(context, result);
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    for (final c in _detailControllers) {
      c.dispose();
    }
    super.dispose();
  }

  List<TextEditingController> get _detailControllers => [_departure, _arrival, _number, _seat, _bookingRef];

  void _update(PlanItem Function(PlanItem) f) => setState(() => _i = f(_i));

  /// Zones of the trip with the item as currently edited (its links and
  /// zone fields may differ from the stored one).
  TripZones _zonesWith(TripData data, PlanItem item) =>
      TripZones.of(data.trip, [for (final i in data.items) if (i.id != item.id) i, item]);

  /// After a transport's zones or stays changed, its end may lie before its
  /// start in real time; then it is moved to an hour after the start, like
  /// the time fields do.
  void _keepEndAfterStart(TripData data) {
    if (!_scheduled || _i.kind != ItemKind.transport) return;
    final zones = _zonesWith(data, _i);
    final probe = _i.copyWith(start: _start, end: _end);
    if (zones.absEnd(probe) < zones.absStart(probe) + 60) _end = zones.earliestEnd(probe, 60);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(tripDataProvider(widget.tripId)).value;
    if (data == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final start = data.trip.startDate;
    final stays = [
      for (final s in data.items)
        if (s.kind == ItemKind.stay && s.id != _i.id) s,
    ]..sort((a, b) => (a.start ?? 1 << 40).compareTo(b.start ?? 1 << 40));
    final l = context.l10n;

    return PopScope<String>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onPopBlocked(data);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isNew ? l.newItemTitle(l.kind(_i.kind)) : l.kind(_i.kind)),
          actions: [
            if (!widget.isNew)
              IconButton(
                tooltip: l.delete,
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (await confirm(context, l.deleteQuestion(_i.title))) {
                    if (!context.mounted) return;
                    final messenger = ScaffoldMessenger.of(context);
                    final actions = ref.read(planActionsProvider);
                    final label = l.stepDeleted(_i.title);
                    await actions.deleteItem(data, _i.id, label);
                    final step = actions.lastStep(widget.tripId);
                    ref.read(tripUiProvider.notifier).select(null);
                    showUndoSnack(messenger, label, () => actions.undoStep(widget.tripId, step));
                    if (context.mounted) _leave();
                  }
                },
              ),
            TextButton(onPressed: () => _save(data), child: Text(l.save)),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (widget.isNew)
              SegmentedButton<ItemKind>(
                showSelectedIcon: false,
                segments: [
                  for (final k in ItemKind.values)
                    ButtonSegment(value: k, icon: Icon(kindIcon(k), size: 18), tooltip: l.kind(k)),
                ],
                selected: {_i.kind},
                onSelectionChanged: (s) => _update((i) => i.copyWith(kind: s.first)),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              autofocus: widget.isNew && _i.title.isEmpty,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.titleHint,
                hintText: switch (_i.kind) {
                  ItemKind.stay => l.titleHintStay,
                  ItemKind.transport => l.titleHintTransport,
                  ItemKind.accommodation => l.titleHintAccommodation,
                  ItemKind.activity => l.titleHintActivity,
                },
                prefixIcon: Icon(itemIcon(_i), color: kindColor(_i.kind)),
              ),
            ),
            const SizedBox(height: 16),
            Text(l.statusLabel, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            SegmentedButton<ItemStatus>(
              segments: [
                for (final s in ItemStatus.values)
                  ButtonSegment(value: s, label: Text(l.status(s), style: const TextStyle(fontSize: 12))),
              ],
              selected: {_i.status},
              showSelectedIcon: false,
              onSelectionChanged: (s) => _update((i) => i.copyWith(status: s.first)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(_i.fixed ? Icons.lock : Icons.lock_open),
              title: Text(l.fixedAppointment),
              subtitle: Text(l.fixedSubtitle),
              value: _i.fixed,
              onChanged: (v) => _update((i) => i.copyWith(fixed: v)),
            ),
            const Divider(),
            ..._relationFields(stays),
            ..._zoneFields(data),
            if (_i.kind == ItemKind.transport) ..._detailFields(),
            if (_i.kind != ItemKind.transport) _placeTile(),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.inSchedule),
              subtitle: Text(_scheduled ? l.hasTimes : l.collectedOnly),
              value: _scheduled,
              onChanged: (v) => setState(() => _scheduled = v),
            ),
            if (_scheduled) ..._timeFields(start, _zonesWith(data, _i)),
            const Divider(),
            TextField(
              controller: _notes,
              minLines: 3,
              maxLines: 12,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.notesLabel, alignLabelWithHint: true, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            _linksSection(),
            const SizedBox(height: 12),
            AttachmentsSection(tripId: widget.tripId, ownerId: _i.id, attachments: data.attachmentsOf(_i.id)),
          ],
        ),
      ),
    );
  }

  List<Widget> _relationFields(List<PlanItem> stays) {
    final l = context.l10n;
    DropdownButtonFormField<String?> stayDropdown(String label, String? value, ValueChanged<String?> onChanged) =>
        DropdownButtonFormField<String?>(
          initialValue: stays.any((s) => s.id == value) ? value : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            const DropdownMenuItem(value: null, child: Text('—')),
            for (final s in stays) DropdownMenuItem(value: s.id, child: Text(s.title.isEmpty ? l.noTitle : s.title)),
          ],
          onChanged: onChanged,
        );

    switch (_i.kind) {
      case ItemKind.stay:
        return const [];
      case ItemKind.accommodation:
      case ItemKind.activity:
        return [
          stayDropdown(l.belongsToPlace, _i.parentId, (v) => _update((i) => i.copyWith(parentId: v))),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(l.movesWithPlace, style: const TextStyle(fontSize: 12)),
          ),
        ];
      case ItemKind.transport:
        return [
          DropdownButtonFormField<TransportMode>(
            initialValue: _i.mode ?? TransportMode.train,
            decoration: InputDecoration(labelText: l.transportMode),
            items: [
              for (final m in TransportMode.values)
                DropdownMenuItem(
                  value: m,
                  child: Row(children: [Icon(modeIcon(m), size: 18), const SizedBox(width: 8), Text(l.mode(m))]),
                ),
            ],
            onChanged: (m) => _update((i) => i.copyWith(mode: m)),
          ),
          stayDropdown(l.fromLabel, _i.fromId, (v) => _update((i) => i.copyWith(fromId: v))),
          stayDropdown(l.toLabel, _i.toId, (v) => _update((i) => i.copyWith(toId: v))),
          const SizedBox(height: 8),
        ];
    }
  }

  /// Time zone of a stay, or departure / arrival zone of a transport. The
  /// transport's zones show only once the trip uses zones at all; they
  /// default to the zones of the linked stays.
  List<Widget> _zoneFields(TripData data) {
    final l = context.l10n;
    final home = data.trip.homeZone;
    final zones = _zonesWith(data, _i);
    switch (_i.kind) {
      case ItemKind.stay:
        return [
          ZoneTile(
            key: const ValueKey('field-tz'),
            label: l.timeZoneLabel,
            zone: _i.tz,
            noneLabel: home == null ? l.zoneNone : l.zoneNoneHome(home),
            subtitle: l.stayZoneHint,
            suggestions: data.usedZones,
            onChanged: (z) => _update((i) => i.copyWith(tz: z)),
          ),
        ];
      case ItemKind.transport:
        if (!zones.isActive) return const [];
        String auto(String? z) => z == null ? l.zoneAutomaticNone : l.zoneAutomatic(z);
        final depAuto = zones.startZone(_i.copyWith(tz: null));
        final arrAuto = zones.endZone(_i.copyWith(endTz: null));
        return [
          ZoneTile(
            key: const ValueKey('field-tz'),
            label: l.departureZoneLabel,
            zone: _i.tz,
            noneLabel: auto(depAuto),
            suggestions: data.usedZones,
            onChanged: (z) => setState(() {
              _i = _i.copyWith(tz: z);
              _keepEndAfterStart(data);
            }),
          ),
          ZoneTile(
            key: const ValueKey('field-end-tz'),
            label: l.arrivalZoneLabel,
            zone: _i.endTz,
            noneLabel: auto(arrAuto),
            subtitle: l.transportZoneHint,
            suggestions: data.usedZones,
            onChanged: (z) => setState(() {
              _i = _i.copyWith(endTz: z);
              _keepEndAfterStart(data);
            }),
          ),
        ];
      case ItemKind.accommodation:
      case ItemKind.activity:
        return const [];
    }
  }

  /// Ticket details of a transport; all optional.
  List<Widget> _detailFields() {
    final l = context.l10n;
    Widget text(Key key, TextEditingController c, String label, IconData icon,
            {TextCapitalization caps = TextCapitalization.words}) =>
        TextField(
          key: key,
          controller: c,
          textCapitalization: caps,
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        );
    return [
      const Divider(),
      Text(l.transportDetails, style: Theme.of(context).textTheme.titleSmall),
      text(const ValueKey('field-departure'), _departure, l.departureStationLabel, Icons.trip_origin),
      text(const ValueKey('field-arrival'), _arrival, l.arrivalStationLabel, Icons.place),
      Row(children: [
        Expanded(
          child: text(const ValueKey('field-number'), _number, l.transportNumberLabel, Icons.tag,
              caps: TextCapitalization.characters),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: text(const ValueKey('field-seat'), _seat, l.seatLabel, Icons.event_seat,
              caps: TextCapitalization.sentences),
        ),
      ]),
      text(const ValueKey('field-booking-ref'), _bookingRef, l.bookingRefLabel, Icons.confirmation_number_outlined,
          caps: TextCapitalization.characters),
      const SizedBox(height: 8),
    ];
  }

  Widget _placeTile() => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.travel_explore),
        title: Text(_i.placeName ?? context.l10n.setPlaceOnMap),
        subtitle: _i.hasLocation
            ? Text('${_i.lat!.toStringAsFixed(4)}, ${_i.lng!.toStringAsFixed(4)}')
            : Text(context.l10n.roughIsEnough),
        trailing: _i.hasLocation
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => _update((i) => i.copyWith(lat: null, lng: null, placeName: null)),
              )
            : null,
        onTap: () async {
          final r = await searchPlace(context, initial: _title.text.trim());
          if (r == null) return;
          _update((i) => i.copyWith(lat: r.lat, lng: r.lng, placeName: r.detail.isEmpty ? r.name : '${r.name}, ${r.detail}'));
          if (_title.text.trim().isEmpty) _title.text = r.name;
        },
      );

  List<Widget> _timeFields(DateTime? tripStart, TripZones zones) {
    final kind = _i.kind;
    // End must come at least an hour after the start in real time, which
    // for a transport across zones is not the same as on the clock.
    int validEnd(int s, int e) {
      final probe = _i.copyWith(start: s, end: e);
      return zones.absEnd(probe) < zones.absStart(probe) + 60 ? zones.earliestEnd(probe, 60) : e;
    }
    final timed = _i.copyWith(start: _start, end: _end);
    String? local(String? zone, int minute) =>
        zone == null ? null : _localLabel(zone, formatUtcOffset(zones.offsetAt(zone, minute)));
    final nights = nightsIn(_start, _end);
    final days = daysTouched(_start, _end);
    final l = context.l10n;

    void setNights(int n) {
      if (n < 0) return;
      setState(() => _end = at(dayOf(_start) + n, minuteOfDay(_end)));
    }

    final startLabel = switch (kind) {
      ItemKind.stay => l.labelArrival,
      ItemKind.accommodation => l.labelCheckIn,
      ItemKind.transport => l.labelDeparture,
      ItemKind.activity => l.labelStart,
    };
    final endLabel = switch (kind) {
      ItemKind.stay => l.labelLeave,
      ItemKind.accommodation => l.labelCheckOut,
      ItemKind.transport => l.labelArrival,
      ItemKind.activity => l.labelEnd,
    };

    return [
      MomentField(
        label: startLabel,
        tripStart: tripStart,
        value: _start,
        onChanged: (v) => setState(() {
          // Keep the duration when moving the start.
          final dur = _end - _start;
          _start = v;
          _end = validEnd(v, v + dur);
        }),
      ),
      if (zones.isActive) _zoneCaption(local(zones.startZone(timed), _start), const ValueKey('start-zone')),
      MomentField(
        label: endLabel,
        tripStart: tripStart,
        value: _end,
        onChanged: (v) => setState(() => _end = validEnd(_start, v)),
      ),
      if (zones.isActive && kind == ItemKind.transport) ...[
        _zoneCaption(local(zones.endZone(timed), _end), const ValueKey('end-zone')),
        _zoneCaption(l.realDuration(l.duration(zones.absDuration(timed), withMinutes: true)),
            const ValueKey('real-duration')),
      ],
      if (kind == ItemKind.stay || kind == ItemKind.accommodation)
        Row(
          children: [
            Text(kind == ItemKind.stay ? '${l.days(days)} · ' : ''),
            Text(l.nights(nights), style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton.outlined(onPressed: nights > 0 ? () => setNights(nights - 1) : null, icon: const Icon(Icons.remove)),
            const SizedBox(width: 8),
            IconButton.outlined(onPressed: () => setNights(nights + 1), icon: const Icon(Icons.add)),
          ],
        ),
      if (kind == ItemKind.stay)
        Text(
          l.daysExplanation,
          style: const TextStyle(fontSize: 12),
        ),
    ];
  }

  String _localLabel(String zone, String offset) => context.l10n.localTimeIn('$zone ($offset)');

  Widget _zoneCaption(String? text, Key key) => text == null
      ? const SizedBox.shrink()
      : Padding(
          key: key,
          padding: const EdgeInsets.only(left: 84, bottom: 4),
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        );

  Widget _linksSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(context.l10n.sectionLinks, style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            IconButton(
              tooltip: context.l10n.addLink,
              icon: const Icon(Icons.add_link),
              onPressed: () async {
                final url =
                    await promptText(context, context.l10n.addLink, hint: 'https://…', keyboard: TextInputType.url);
                if (url == null || url.trim().isEmpty) return;
                final u = url.trim().startsWith('http') ? url.trim() : 'https://${url.trim()}';
                _update((i) => i.copyWith(links: [...i.links, u]));
              },
            ),
          ]),
          for (final link in _i.links)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.link),
              title: Text(link, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => _update((i) => i.copyWith(links: [...i.links]..remove(link))),
              ),
            ),
        ],
      );

  Future<void> _save(TripData data) async {
    if (_leaving || _busy) return;
    _busy = true;
    try {
      await _store(data);
    } finally {
      _busy = false;
    }
  }

  Future<void> _store(TripData data) async {
    final mode = ref.read(tripUiProvider).shiftMode;
    final actions = ref.read(planActionsProvider);
    final l = context.l10n;
    _keepEndAfterStart(data);
    var item = _i.copyWith(
      title: _title.text.trim().isEmpty ? l.kind(_i.kind) : _title.text.trim(),
      notes: _notes.text,
      start: _scheduled ? _start : null,
      end: _scheduled ? _end : null,
    );
    String? opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    item = item.copyWith(
      departureStation: opt(_departure),
      arrivalStation: opt(_arrival),
      transportNumber: opt(_number),
      seat: opt(_seat),
      bookingRef: opt(_bookingRef),
    );
    if (item.kind != ItemKind.transport) {
      item = item.copyWith(
        fromId: null,
        toId: null,
        mode: null,
        departureStation: null,
        arrivalStation: null,
        transportNumber: null,
        seat: null,
        bookingRef: null,
      );
    }
    if (item.kind == ItemKind.stay || item.kind == ItemKind.transport) item = item.copyWith(parentId: null);
    // Only stays and transports carry zones of their own (zones.dart).
    if (item.kind != ItemKind.stay && item.kind != ItemKind.transport) item = item.copyWith(tz: null);
    if (item.kind != ItemKind.transport) item = item.copyWith(endTz: null);

    final old = data.item(item.id);
    final zones = _zonesWith(data, item);
    ScheduleResult? r;
    if (old == null) {
      r = Scheduler.insert(data.items, item, mode, zones: zones);
    } else if (item.isScheduled && old.isScheduled && (old.start != item.start || old.end != item.end)) {
      // Other fields first, then let the scheduler move it (and what follows).
      final others = [for (final i in data.items) i.id == item.id ? item.copyWith(start: old.start, end: old.end) : i];
      r = Scheduler.reschedule(others, item.id, item.start!, item.end!, mode, zones: zones);
    }

    final changed = r == null ? [item] : [item, ...r.changed.where((c) => c.id != item.id)];
    final finalItem = r?.items.firstWhere((x) => x.id == item.id) ?? item;
    changed[0] = finalItem;
    await actions.saveItems(data, changed, widget.isNew ? l.stepItemCreated(item.title) : l.stepItemChanged(item.title));
    _saved = true;
    ref.read(tripUiProvider.notifier).select(item.id);
    if (!mounted) return;
    final moved = changed.length - 1;
    if (moved > 0) {
      showSnack(
        context,
        l.othersMoved(moved, l.shiftModeShort(mode)),
        action: SnackBarAction(label: l.undo, onPressed: () => actions.undo(widget.tripId)),
      );
    }
    _leave(item.id);
  }
}
