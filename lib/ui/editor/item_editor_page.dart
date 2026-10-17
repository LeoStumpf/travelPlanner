import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/analysis.dart';
import '../../domain/models.dart';
import '../../domain/scheduler.dart';
import '../../domain/time.dart';
import '../../state/providers.dart';
import '../common/dialogs.dart';
import '../common/style.dart';
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
                .copyWith(lat: lat, lng: lng, placeName: lat == null ? null : 'Auf der Karte gewählt'),
        isNew: item == null,
      ),
    ));

PlanItem _newItem(TripData data, ItemKind kind, int? atDay, String? parentHint, String? title) {
  final chain = stayChain(data.items);
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
    super.dispose();
  }

  void _update(PlanItem Function(PlanItem) f) => setState(() => _i = f(_i));

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(tripDataProvider(widget.tripId)).value;
    if (data == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final start = data.trip.startDate;
    final stays = [
      for (final s in data.items)
        if (s.kind == ItemKind.stay && s.id != _i.id) s,
    ]..sort((a, b) => (a.start ?? 1 << 40).compareTo(b.start ?? 1 << 40));

    return PopScope<String>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onPopBlocked(data);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isNew ? 'Neu: ${_i.kind.label}' : _i.kind.label),
          actions: [
            if (!widget.isNew)
              IconButton(
                tooltip: 'Löschen',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (await confirm(context, '„${_i.title}“ löschen?')) {
                    if (!context.mounted) return;
                    final messenger = ScaffoldMessenger.of(context);
                    final actions = ref.read(planActionsProvider);
                    await actions.deleteItem(data, _i.id);
                    ref.read(tripUiProvider.notifier).select(null);
                    showUndoSnack(messenger, '„${_i.title}“ gelöscht', () => actions.undo(widget.tripId));
                    if (context.mounted) _leave();
                  }
                },
              ),
            TextButton(onPressed: () => _save(data), child: const Text('Speichern')),
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
                    ButtonSegment(value: k, icon: Icon(kindIcon(k), size: 18), tooltip: k.label),
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
                labelText: 'Titel',
                hintText: switch (_i.kind) {
                  ItemKind.stay => 'z. B. Kandy',
                  ItemKind.transport => 'z. B. Zug Kandy → Ella',
                  ItemKind.accommodation => 'z. B. Tree House Ella',
                  ItemKind.activity => 'z. B. Safari im Yala NP',
                },
                prefixIcon: Icon(itemIcon(_i), color: kindColor(_i.kind)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Status', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            SegmentedButton<ItemStatus>(
              segments: [
                for (final s in ItemStatus.values)
                  ButtonSegment(value: s, label: Text(s.label, style: const TextStyle(fontSize: 12))),
              ],
              selected: {_i.status},
              showSelectedIcon: false,
              onSelectionChanged: (s) => _update((i) => i.copyWith(status: s.first)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(_i.fixed ? Icons.lock : Icons.lock_open),
              title: const Text('Fixer Termin'),
              subtitle: const Text('Bewegt sich nicht, wenn davor etwas verschoben wird (z. B. gebuchte Tour, Rückflug)'),
              value: _i.fixed,
              onChanged: (v) => _update((i) => i.copyWith(fixed: v)),
            ),
            const Divider(),
            ..._relationFields(stays),
            if (_i.kind != ItemKind.transport) _placeTile(),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Im Zeitplan'),
              subtitle: Text(_scheduled ? 'Hat Tage/Uhrzeiten' : 'Nur gesammelt – noch ohne Termin'),
              value: _scheduled,
              onChanged: (v) => setState(() => _scheduled = v),
            ),
            if (_scheduled) ..._timeFields(start),
            const Divider(),
            TextField(
              controller: _notes,
              minLines: 3,
              maxLines: 12,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Notizen', alignLabelWithHint: true, border: OutlineInputBorder()),
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
    DropdownButtonFormField<String?> stayDropdown(String label, String? value, ValueChanged<String?> onChanged) =>
        DropdownButtonFormField<String?>(
          initialValue: stays.any((s) => s.id == value) ? value : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            const DropdownMenuItem(value: null, child: Text('—')),
            for (final s in stays) DropdownMenuItem(value: s.id, child: Text(s.title.isEmpty ? '(ohne Titel)' : s.title)),
          ],
          onChanged: onChanged,
        );

    switch (_i.kind) {
      case ItemKind.stay:
        return const [];
      case ItemKind.accommodation:
      case ItemKind.activity:
        return [
          stayDropdown('Gehört zu Ort', _i.parentId, (v) => _update((i) => i.copyWith(parentId: v))),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 8),
            child: Text('Wird mitverschoben, wenn sich der Ort verschiebt.', style: TextStyle(fontSize: 12)),
          ),
        ];
      case ItemKind.transport:
        return [
          DropdownButtonFormField<TransportMode>(
            initialValue: _i.mode ?? TransportMode.train,
            decoration: const InputDecoration(labelText: 'Verkehrsmittel'),
            items: [
              for (final m in TransportMode.values)
                DropdownMenuItem(
                  value: m,
                  child: Row(children: [Icon(modeIcon(m), size: 18), const SizedBox(width: 8), Text(m.label)]),
                ),
            ],
            onChanged: (m) => _update((i) => i.copyWith(mode: m)),
          ),
          stayDropdown('Von', _i.fromId, (v) => _update((i) => i.copyWith(fromId: v))),
          stayDropdown('Nach', _i.toId, (v) => _update((i) => i.copyWith(toId: v))),
          const SizedBox(height: 8),
        ];
    }
  }

  Widget _placeTile() => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.travel_explore),
        title: Text(_i.placeName ?? 'Ort auf der Karte festlegen'),
        subtitle: _i.hasLocation
            ? Text('${_i.lat!.toStringAsFixed(4)}, ${_i.lng!.toStringAsFixed(4)}')
            : const Text('Grob reicht – die Stadt genügt'),
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

  List<Widget> _timeFields(DateTime? tripStart) {
    final kind = _i.kind;
    final nights = nightsIn(_start, _end);
    final days = daysTouched(_start, _end);

    void setNights(int n) {
      if (n < 0) return;
      setState(() => _end = at(dayOf(_start) + n, minuteOfDay(_end)));
    }

    final startLabel = switch (kind) {
      ItemKind.stay => 'Ankunft',
      ItemKind.accommodation => 'Check-in',
      ItemKind.transport => 'Abfahrt',
      ItemKind.activity => 'Beginn',
    };
    final endLabel = switch (kind) {
      ItemKind.stay => 'Abreise',
      ItemKind.accommodation => 'Check-out',
      ItemKind.transport => 'Ankunft',
      ItemKind.activity => 'Ende',
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
          _end = v + (dur > 0 ? dur : 60);
        }),
      ),
      MomentField(
        label: endLabel,
        tripStart: tripStart,
        value: _end,
        onChanged: (v) => setState(() => _end = v <= _start ? _start + 60 : v),
      ),
      if (kind == ItemKind.stay || kind == ItemKind.accommodation)
        Row(
          children: [
            Text(kind == ItemKind.stay ? '${pluralDays(days)} · ' : ''),
            Text(pluralNights(nights), style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton.outlined(onPressed: nights > 0 ? () => setNights(nights - 1) : null, icon: const Icon(Icons.remove)),
            const SizedBox(width: 8),
            IconButton.outlined(onPressed: () => setNights(nights + 1), icon: const Icon(Icons.add)),
          ],
        ),
      if (kind == ItemKind.stay)
        const Text(
          'Tage zählen jeden angebrochenen Tag. Früh ankommen und spät abreisen = mehr Tage bei gleich vielen Nächten.',
          style: TextStyle(fontSize: 12),
        ),
    ];
  }

  Widget _linksSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Links', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            IconButton(
              tooltip: 'Link hinzufügen',
              icon: const Icon(Icons.add_link),
              onPressed: () async {
                final url = await promptText(context, 'Link hinzufügen', hint: 'https://…', keyboard: TextInputType.url);
                if (url == null || url.trim().isEmpty) return;
                final u = url.trim().startsWith('http') ? url.trim() : 'https://${url.trim()}';
                _update((i) => i.copyWith(links: [...i.links, u]));
              },
            ),
          ]),
          for (final l in _i.links)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.link),
              title: Text(l, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => launchUrl(Uri.parse(l), mode: LaunchMode.externalApplication),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => _update((i) => i.copyWith(links: [...i.links]..remove(l))),
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
    var item = _i.copyWith(
      title: _title.text.trim().isEmpty ? _i.kind.label : _title.text.trim(),
      notes: _notes.text,
      start: _scheduled ? _start : null,
      end: _scheduled ? _end : null,
    );
    if (item.kind != ItemKind.transport) item = item.copyWith(fromId: null, toId: null, mode: null);
    if (item.kind == ItemKind.stay || item.kind == ItemKind.transport) item = item.copyWith(parentId: null);

    final old = data.item(item.id);
    ScheduleResult? r;
    if (old == null) {
      r = Scheduler.insert(data.items, item, mode);
    } else if (item.isScheduled && old.isScheduled && (old.start != item.start || old.end != item.end)) {
      // Other fields first, then let the scheduler move it (and what follows).
      final others = [for (final i in data.items) i.id == item.id ? item.copyWith(start: old.start, end: old.end) : i];
      r = Scheduler.reschedule(others, item.id, item.start!, item.end!, mode);
    }

    final changed = r == null ? [item] : [item, ...r.changed.where((c) => c.id != item.id)];
    final finalItem = r?.items.firstWhere((x) => x.id == item.id) ?? item;
    changed[0] = finalItem;
    await actions.saveItems(data, changed, widget.isNew ? '„${item.title}“ angelegt' : '„${item.title}“ geändert');
    _saved = true;
    ref.read(tripUiProvider.notifier).select(item.id);
    if (!mounted) return;
    final moved = changed.length - 1;
    if (moved > 0) {
      showSnack(
        context,
        '${moved == 1 ? '1 weiteres Element' : '$moved weitere Elemente'} verschoben (${mode.shortLabel})',
        action: SnackBarAction(label: 'Rückgängig', onPressed: () => actions.undo(widget.tripId)),
      );
    }
    _leave(item.id);
  }
}
