import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/geocoding.dart';
import '../../domain/models.dart';
import '../../domain/plan_exchange.dart';
import '../../state/providers.dart';
import '../common/dialogs.dart';
import '../trips/trips_page.dart';

/// "Plan with Claude": copy the format guide (plus the trip) for a chat
/// assistant, then import its answer. [data] is null on the trip list.
Future<void> showPlanExchangeSheet(BuildContext context, WidgetRef ref, TripData? data) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '1. Kopieren und in der Claude-App einfügen\n'
              '2. Deine Wünsche dazuschreiben und planen lassen\n'
              '3. Claudes Antwort kopieren (oder an Tripboard teilen) und hier übernehmen',
              style: Theme.of(c).textTheme.bodyMedium,
            ),
          ),
          if (data != null)
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('Reise für Claude kopieren'),
              subtitle: const Text('Anleitung + aktueller Plan'),
              onTap: () => Navigator.pop(c, 'copy-trip'),
            ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Nur Anleitung kopieren'),
            subtitle: const Text('Für eine neue Reise oder als Projekt-Anweisung in Claude'),
            onTap: () => Navigator.pop(c, 'copy-spec'),
          ),
          ListTile(
            leading: const Icon(Icons.content_paste),
            title: const Text('Plan aus Zwischenablage übernehmen'),
            onTap: () => Navigator.pop(c, 'paste'),
          ),
          ListTile(
            leading: const Icon(Icons.file_open_outlined),
            title: const Text('Plan-Datei öffnen'),
            onTap: () => Navigator.pop(c, 'file'),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case 'copy-trip' || 'copy-spec':
      final text = await planPrompt(choice == 'copy-trip' ? data : null);
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) showSnack(context, 'Kopiert – jetzt in der Claude-App einfügen');
    case 'paste':
      final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
      if (!context.mounted) return;
      if (text.trim().isEmpty) {
        showSnack(context, 'Zwischenablage ist leer');
        return;
      }
      await importPlanText(context, ref, text, targetTripId: data?.trip.id);
    case 'file':
      final f = await FilePicker.pickFile(dialogTitle: 'Plan wählen', type: FileType.any);
      if (f == null) return;
      try {
        final text = utf8.decode(await f.xFile.readAsBytes(), allowMalformed: true);
        if (context.mounted) await importPlanText(context, ref, text, targetTripId: data?.trip.id);
      } catch (e) {
        if (context.mounted) showSnack(context, 'Datei nicht lesbar: $e');
      }
  }
}

/// The text to paste into the assistant: the format guide, and the current
/// trip if there is one.
Future<String> planPrompt(TripData? data) async {
  final spec = await rootBundle.loadString('assets/plan_format.md');
  if (data == null) return '$spec\n---\n\nNeue Reise. Meine Wünsche: ';
  return '$spec\n---\n\n## Current trip\n\n```json\n${PlanExchange.exportText(data)}\n```\n\nMeine Wünsche: ';
}

/// Parses [text], shows what the plan would change and applies it on
/// confirmation (one undoable step for existing trips).
Future<void> importPlanText(BuildContext context, WidgetRef ref, String text, {String? targetTripId}) async {
  final PlanDoc doc;
  try {
    doc = PlanExchange.parse(text);
  } on FormatException catch (e) {
    showSnack(context, 'Kein gültiger Plan: ${e.message}');
    return;
  }
  final repo = ref.read(repositoryProvider);
  final trips = await repo.watchTrips().first;
  final ids = {for (final t in trips) t.id};
  final initial = targetTripId ?? (ids.contains(doc.tripId) ? doc.tripId : null);
  if (!context.mounted) return;
  final tripId = await showDialog<String>(
    context: context,
    builder: (_) => _ImportDialog(doc: doc, trips: trips, initialTarget: initial),
  );
  if (tripId == null || !context.mounted) return;
  if (tripId == targetTripId) {
    showSnack(context, 'Plan übernommen');
  } else {
    openTrip(context, ref, tripId);
  }
}

class _ImportDialog extends ConsumerStatefulWidget {
  final PlanDoc doc;
  final List<Trip> trips;
  final String? initialTarget;
  const _ImportDialog({required this.doc, required this.trips, this.initialTarget});

  @override
  ConsumerState<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<_ImportDialog> {
  /// Selected trip id, '' = new trip.
  late String _target = widget.initialTarget ?? '';
  PlanImport? _imp;
  bool _geocode = true;
  String? _busy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final into = _target.isEmpty ? null : await ref.read(repositoryProvider).loadTrip(_target);
    if (!mounted) return;
    setState(() {
      _imp = PlanExchange.apply(widget.doc, into: into, now: DateTime.now(), newId: newId);
    });
  }

  String _newTitle() {
    final t = (widget.doc.trip['title'] as String?)?.trim();
    return t == null || t.isEmpty ? 'Importierte Reise' : t;
  }

  @override
  Widget build(BuildContext context) {
    final imp = _imp;
    final theme = Theme.of(context);
    final missing = imp == null ? 0 : _needsCoordinates(imp.items).length;
    return AlertDialog(
      title: const Text('Plan übernehmen'),
      content: SizedBox(
        width: 480,
        child: imp == null
            ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
            : ListView(
                shrinkWrap: true,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _target,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Ziel'),
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text('Neue Reise „${_newTitle()}“', overflow: TextOverflow.ellipsis),
                      ),
                      for (final t in widget.trips)
                        DropdownMenuItem(value: t.id, child: Text(t.title, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: _busy != null
                        ? null
                        : (v) {
                            setState(() {
                              _target = v ?? '';
                              _imp = null;
                            });
                            _load();
                          },
                  ),
                  const SizedBox(height: 16),
                  if (imp.isEmpty) const Text('Der Plan enthält keine Änderungen.'),
                  if (imp.tripChanged) const Text('• Reisedaten (Titel/Start/Länge) ändern sich'),
                  if (imp.itemsCreated > 0) Text('• ${imp.itemsCreated} neue Einträge'),
                  if (imp.itemsUpdated > 0) Text('• ${imp.itemsUpdated} Einträge geändert'),
                  if (imp.removeItemIds.isNotEmpty) Text('• ${imp.removeItemIds.length} Einträge gelöscht'),
                  if (imp.notesCreated > 0) Text('• ${imp.notesCreated} neue Notizen'),
                  if (imp.notesUpdated > 0) Text('• ${imp.notesUpdated} Notizen geändert'),
                  if (imp.removeCardIds.isNotEmpty) Text('• ${imp.removeCardIds.length} Notizen gelöscht'),
                  if (_target.isNotEmpty && widget.doc.tripId != null && widget.doc.tripId != _target)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Der Plan stammt aus einer anderen Reise – alles wird neu angelegt.',
                          style: theme.textTheme.bodySmall),
                    ),
                  if (missing > 0)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _geocode,
                      onChanged: _busy != null ? null : (v) => setState(() => _geocode = v ?? false),
                      title: Text('Koordinaten für $missing Einträge suchen'),
                      subtitle: const Text('Über OpenStreetMap, braucht Internet'),
                    ),
                  if (imp.warnings.isNotEmpty)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      leading: Icon(Icons.warning_amber, color: theme.colorScheme.error),
                      title: Text('${imp.warnings.length} Hinweise'),
                      children: [
                        for (final w in imp.warnings)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(w, style: theme.textTheme.bodySmall),
                            ),
                          ),
                      ],
                    ),
                  if (_busy != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(children: [
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_busy!)),
                      ]),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(onPressed: _busy != null ? null : () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: imp == null || imp.isEmpty || _busy != null ? null : () => _apply(imp),
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }

  Future<void> _apply(PlanImport imp) async {
    var items = imp.items;
    if (_geocode && _needsCoordinates(items).isNotEmpty) {
      setState(() => _busy = 'Suche Koordinaten …');
      items = await fillCoordinates(items, Geocoder());
    }
    if (!mounted) return;
    setState(() => _busy = 'Speichere …');
    await writePlanImport(ref.read(planActionsProvider), imp, items: items);
    if (mounted) Navigator.pop(context, imp.trip.id);
  }
}

/// Writes [imp] (with [items] replacing its items, e.g. after geocoding).
/// Changes to an existing trip are one undoable step.
Future<void> writePlanImport(PlanActions actions, PlanImport imp, {List<PlanItem>? items}) async {
  final list = items ?? imp.items;
  final repo = actions.ref.read(repositoryProvider);
  if (imp.isNewTrip) {
    await repo.putTripData(TripData(trip: imp.trip, items: list, cards: imp.cards));
    return;
  }
  await actions.record(imp.trip.id, 'Plan importiert', (r) async {
    if (imp.tripChanged) await r.saveTrip(imp.trip);
    // Reload before each delete: deleting unlinks other items, and a stale
    // copy would bring old links back.
    for (final id in imp.removeItemIds) {
      final data = await r.loadTrip(imp.trip.id);
      if (data != null) await r.deleteItem(data, id);
    }
    for (final id in imp.removeCardIds) {
      final data = await r.loadTrip(imp.trip.id);
      if (data != null) await r.deleteCard(data, id);
    }
    await r.saveItems(list);
    for (final c in imp.cards) {
      await r.saveCard(c);
    }
  });
}

/// Search text for items without coordinates: their place, or a stay's title.
String? _geoQuery(PlanItem i) {
  if (i.hasLocation || i.kind == ItemKind.transport) return null;
  final q = i.placeName ?? (i.kind == ItemKind.stay ? i.title : null);
  return q == null || q.trim().length < 2 ? null : q.trim();
}

List<PlanItem> _needsCoordinates(List<PlanItem> items) =>
    [for (final i in items) if (_geoQuery(i) != null) i];

/// Looks up missing coordinates (first OSM match); lookups that fail are skipped.
Future<List<PlanItem>> fillCoordinates(List<PlanItem> items, Geocoder geocoder) async {
  final cache = <String, PlaceResult?>{};
  final out = <PlanItem>[];
  for (final i in items) {
    final q = _geoQuery(i);
    if (q == null) {
      out.add(i);
      continue;
    }
    if (!cache.containsKey(q)) {
      try {
        cache[q] = (await geocoder.search(q)).firstOrNull;
      } catch (_) {
        cache[q] = null;
      }
    }
    final r = cache[q];
    out.add(r == null ? i : i.copyWith(lat: r.lat, lng: r.lng));
  }
  return out;
}
