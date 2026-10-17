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
import '../common/l10n.dart';
import '../trips/trips_page.dart';

/// "Plan with Claude": copy the format guide (plus the trip) for a chat
/// assistant, then import its answer. [data] is null on the trip list.
Future<void> showPlanExchangeSheet(BuildContext context, WidgetRef ref, TripData? data) async {
  final l = context.l10n;
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
            child: Text(l.exchangeSteps, style: Theme.of(c).textTheme.bodyMedium),
          ),
          if (data != null)
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: Text(l.copyTripForClaude),
              subtitle: Text(l.copyTripForClaudeSub),
              onTap: () => Navigator.pop(c, 'copy-trip'),
            ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l.copyGuideOnly),
            subtitle: Text(l.copyGuideOnlySub),
            onTap: () => Navigator.pop(c, 'copy-spec'),
          ),
          ListTile(
            leading: const Icon(Icons.content_paste),
            title: Text(l.pastePlan),
            onTap: () => Navigator.pop(c, 'paste'),
          ),
          ListTile(
            leading: const Icon(Icons.file_open_outlined),
            title: Text(l.openPlanFile),
            onTap: () => Navigator.pop(c, 'file'),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case 'copy-trip' || 'copy-spec':
      final text = await planPrompt(l, choice == 'copy-trip' ? data : null);
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) showSnack(context, l.copiedForClaude);
    case 'paste':
      final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
      if (!context.mounted) return;
      if (text.trim().isEmpty) {
        showSnack(context, l.clipboardEmpty);
        return;
      }
      await importPlanText(context, ref, text, targetTripId: data?.trip.id);
    case 'file':
      final f = await FilePicker.pickFile(dialogTitle: l.choosePlan, type: FileType.any);
      if (f == null) return;
      try {
        final text = utf8.decode(await f.xFile.readAsBytes(), allowMalformed: true);
        if (context.mounted) await importPlanText(context, ref, text, targetTripId: data?.trip.id);
      } catch (e) {
        if (context.mounted) showSnack(context, l.fileNotReadable('$e'));
      }
  }
}

/// The text to paste into the assistant: the format guide, and the current
/// trip if there is one. The guide is English; the closing line is in the
/// user's language, so Claude answers in it.
Future<String> planPrompt(AppLocalizations l, TripData? data) async {
  final spec = await rootBundle.loadString('assets/plan_format.md');
  if (data == null) return '$spec\n---\n\n${l.promptNewTrip}';
  return '$spec\n---\n\n## Current trip\n\n```json\n${PlanExchange.exportText(data)}\n```\n\n${l.promptMyWishes}';
}

/// Parses [text], shows what the plan would change and applies it on
/// confirmation (one undoable step for existing trips).
Future<void> importPlanText(BuildContext context, WidgetRef ref, String text, {String? targetTripId}) async {
  final l = context.l10n;
  final PlanDoc doc;
  try {
    doc = PlanExchange.parse(text);
  } on FormatException catch (e) {
    showSnack(context, l.invalidPlan(l.planError(e)));
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
    showSnack(context, l.planApplied);
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
      _imp = PlanExchange.apply(widget.doc,
          into: into, now: DateTime.now(), newId: newId, newTripTitle: context.l10n.importedTripTitle);
    });
  }

  String _newTitle() {
    final t = (widget.doc.trip['title'] as String?)?.trim();
    return t == null || t.isEmpty ? context.l10n.importedTripTitle : t;
  }

  @override
  Widget build(BuildContext context) {
    final imp = _imp;
    final theme = Theme.of(context);
    final missing = imp == null ? 0 : _needsCoordinates(imp.items).length;
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.applyPlanTitle),
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
                    decoration: InputDecoration(labelText: l.importTarget),
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(l.newTripNamed(_newTitle()), overflow: TextOverflow.ellipsis),
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
                  if (imp.isEmpty) Text(l.planNoChanges),
                  if (imp.tripChanged) Text(l.planTripChanged),
                  if (imp.itemsCreated > 0) Text(l.planItemsCreated(imp.itemsCreated)),
                  if (imp.itemsUpdated > 0) Text(l.planItemsUpdated(imp.itemsUpdated)),
                  if (imp.removeItemIds.isNotEmpty) Text(l.planItemsRemoved(imp.removeItemIds.length)),
                  if (imp.notesCreated > 0) Text(l.planNotesCreated(imp.notesCreated)),
                  if (imp.notesUpdated > 0) Text(l.planNotesUpdated(imp.notesUpdated)),
                  if (imp.removeCardIds.isNotEmpty) Text(l.planNotesRemoved(imp.removeCardIds.length)),
                  if (_target.isNotEmpty && widget.doc.tripId != null && widget.doc.tripId != _target)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(l.planFromOtherTrip, style: theme.textTheme.bodySmall),
                    ),
                  if (missing > 0)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _geocode,
                      onChanged: _busy != null ? null : (v) => setState(() => _geocode = v ?? false),
                      title: Text(l.findCoordinates(missing)),
                      subtitle: Text(l.findCoordinatesSub),
                    ),
                  if (imp.warnings.isNotEmpty)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      leading: Icon(Icons.warning_amber, color: theme.colorScheme.error),
                      title: Text(l.planWarningsCount(imp.warnings.length)),
                      children: [
                        for (final w in imp.warnings)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(l.planWarning(w), style: theme.textTheme.bodySmall),
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
        TextButton(onPressed: _busy != null ? null : () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          onPressed: imp == null || imp.isEmpty || _busy != null ? null : () => _apply(imp),
          child: Text(l.apply),
        ),
      ],
    );
  }

  Future<void> _apply(PlanImport imp) async {
    final l = context.l10n;
    var items = imp.items;
    if (_geocode && _needsCoordinates(items).isNotEmpty) {
      setState(() => _busy = l.searchingCoordinates);
      items = await fillCoordinates(items, Geocoder(), lang: l.localeName);
    }
    if (!mounted) return;
    setState(() => _busy = l.saving);
    await writePlanImport(ref.read(planActionsProvider), imp, items: items, label: l.stepPlanImported);
    if (mounted) Navigator.pop(context, imp.trip.id);
  }
}

/// Writes [imp] (with [items] replacing its items, e.g. after geocoding).
/// Changes to an existing trip are one undoable step named [label].
Future<void> writePlanImport(PlanActions actions, PlanImport imp,
    {List<PlanItem>? items, required String label}) async {
  final list = items ?? imp.items;
  final repo = actions.ref.read(repositoryProvider);
  if (imp.isNewTrip) {
    await repo.putTripData(TripData(trip: imp.trip, items: list, cards: imp.cards));
    return;
  }
  await actions.record(imp.trip.id, label, (r) async {
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
Future<List<PlanItem>> fillCoordinates(List<PlanItem> items, Geocoder geocoder, {String lang = 'en'}) async {
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
        cache[q] = (await geocoder.search(q, lang: lang)).firstOrNull;
      } catch (_) {
        cache[q] = null;
      }
    }
    final r = cache[q];
    out.add(r == null ? i : i.copyWith(lat: r.lat, lng: r.lng));
  }
  return out;
}
