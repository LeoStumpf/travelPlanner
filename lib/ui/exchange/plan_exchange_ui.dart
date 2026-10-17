import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/geocoding.dart';
import '../../domain/analysis.dart';
import '../../domain/models.dart';
import '../../domain/places.dart';
import '../../domain/plan_exchange.dart';
import '../../domain/zones.dart';
import '../../state/providers.dart';
import '../common/dialogs.dart';
import '../common/l10n.dart';
import '../common/style.dart';
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

/// Hashes of plan texts the user has already seen in the import dialog or
/// been offered from the clipboard; those are not offered again.
final seenPlanTexts = <int>{};

/// Parses [text], shows what the plan would change and applies it on
/// confirmation (one undoable step for existing trips).
Future<void> importPlanText(BuildContext context, WidgetRef ref, String text, {String? targetTripId}) async {
  final l = context.l10n;
  seenPlanTexts.add(text.trim().hashCode);
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
  TripData? _into;
  List<PlanChange> _changes = const [];
  int _conflictsBefore = 0;
  List<Conflict> _conflictsAfter = const [];
  bool _geocode = true;
  String? _busy;

  /// Set once the plan is written and some places were not found: the
  /// dialog then lists them instead of closing.
  GeocodeOutcome? _geocoded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Always awaits, so this never runs inside initState.
    final into = await (_target.isEmpty ? Future<TripData?>.value() : ref.read(repositoryProvider).loadTrip(_target));
    if (!mounted) return;
    final imp = PlanExchange.apply(widget.doc,
        into: into, now: DateTime.now(), newId: newId, newTripTitle: context.l10n.importedTripTitle);
    final after = PlanExchange.itemsAfter(imp, into);
    setState(() {
      _imp = imp;
      _into = into;
      _changes = PlanExchange.changes(imp, into);
      _conflictsBefore = into == null ? 0 : findConflicts(into.items, zones: TripZones.of(into.trip, into.items)).length;
      _conflictsAfter = findConflicts(after, zones: TripZones.of(imp.trip, after));
    });
  }

  String _newTitle() {
    final t = (widget.doc.trip['title'] as String?)?.trim();
    return t == null || t.isEmpty ? context.l10n.importedTripTitle : t;
  }

  @override
  Widget build(BuildContext context) {
    final done = _geocoded;
    if (done != null) return _notFoundDialog(context, done);
    final imp = _imp;
    final theme = Theme.of(context);
    final missing = imp == null ? 0 : imp.items.where((i) => geoQuery(i) != null).length;
    final l = context.l10n;
    List<PlanChange> group(PlanChangeType t, bool notes) =>
        [for (final c in _changes) if (c.type == t && c.isNote == notes) c];
    final into = _into;
    final tripFields = imp == null || into == null ? const <PlanField>{} : PlanExchange.tripChanges(into.trip, imp.trip);
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
                  if (imp.tripChanged)
                    Text(l.planTripChangedFields(tripFields.map(l.planField).join(', '))),
                  ..._section(l.planItemsCreated(imp.itemsCreated), group(PlanChangeType.created, false)),
                  ..._section(l.planItemsUpdated(imp.itemsUpdated), group(PlanChangeType.updated, false)),
                  ..._section(l.planItemsRemoved(imp.removeItemIds.length), group(PlanChangeType.removed, false)),
                  ..._section(l.planNotesCreated(imp.notesCreated), group(PlanChangeType.created, true)),
                  ..._section(l.planNotesUpdated(imp.notesUpdated), group(PlanChangeType.updated, true)),
                  ..._section(l.planNotesRemoved(imp.removeCardIds.length), group(PlanChangeType.removed, true)),
                  if (_target.isNotEmpty && widget.doc.tripId != null && widget.doc.tripId != _target)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(l.planFromOtherTrip, style: theme.textTheme.bodySmall),
                    ),
                  if (!imp.isEmpty) _conflictTile(context),
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

  /// A count line with the entries it counts below it, by title: changed
  /// ones with what changes, deleted ones in red.
  List<Widget> _section(String heading, List<PlanChange> entries) {
    if (entries.isEmpty) return const [];
    final theme = Theme.of(context);
    final l = context.l10n;
    final error = theme.colorScheme.error;
    return [
      Padding(padding: const EdgeInsets.only(top: 4), child: Text(heading)),
      for (final c in entries)
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                c.kind == null ? Icons.sticky_note_2_outlined : kindIcon(c.kind!),
                size: 16,
                color: c.type == PlanChangeType.removed ? error : (c.kind == null ? null : kindColor(c.kind!)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: c.title.isEmpty ? '–' : c.title,
                      style: c.type == PlanChangeType.removed
                          ? TextStyle(color: error, decoration: TextDecoration.lineThrough, decorationColor: error)
                          : null,
                    ),
                    if (c.fields.isNotEmpty)
                      TextSpan(
                        text: '  ${c.fields.map(l.planField).join(', ')}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                  ]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
    ];
  }

  /// How many conflicts the trip has once the plan is in, compared to now;
  /// expands to the list.
  Widget _conflictTile(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final after = _conflictsAfter;
    final worse = after.length > _conflictsBefore;
    final title = Text(l.planConflictsAfter(after.length));
    final subtitle = _into == null ? null : Text(l.planConflictsBefore(_conflictsBefore));
    final icon = after.isEmpty
        ? Icon(Icons.check_circle_outline, color: theme.colorScheme.primary)
        : Icon(Icons.warning_amber, color: worse ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant);
    if (after.isEmpty) {
      return ListTile(contentPadding: EdgeInsets.zero, leading: icon, title: title, subtitle: subtitle);
    }
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: icon,
      title: title,
      subtitle: subtitle,
      children: [
        for (final c in after)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(l.conflict(c), style: theme.textTheme.bodySmall),
            ),
          ),
      ],
    );
  }

  /// After applying: which places the search could not find.
  Widget _notFoundDialog(BuildContext context, GeocodeOutcome g) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return AlertDialog(
      icon: Icon(Icons.wrong_location_outlined, color: theme.colorScheme.error),
      title: Text(l.geocodeNotFound(g.notFound.length, g.searched.length)),
      content: SizedBox(
        width: 480,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(l.geocodeNotFoundSub, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            for (final i in g.notFound)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(kindIcon(i.kind), color: kindColor(i.kind)),
                title: Text(i.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: i.placeName == null || i.placeName == i.title
                    ? null
                    : Text(i.placeName!, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(context, _imp!.trip.id), child: Text(l.ok)),
      ],
    );
  }

  Future<void> _apply(PlanImport imp) async {
    final l = context.l10n;
    var items = imp.items;
    GeocodeOutcome? geocoded;
    if (_geocode && items.any((i) => geoQuery(i) != null)) {
      setState(() => _busy = l.searchingCoordinates);
      geocoded = await fillCoordinates(items, ref.read(geocoderProvider),
          context: PlanExchange.itemsAfter(imp, _into), lang: l.localeName);
      items = geocoded.items;
    }
    if (!mounted) return;
    setState(() => _busy = l.saving);
    await writePlanImport(ref.read(planActionsProvider), imp, items: items, label: l.stepPlanImported);
    if (!mounted) return;
    if (geocoded != null && geocoded.notFound.isNotEmpty) {
      setState(() {
        _busy = null;
        _geocoded = geocoded;
      });
    } else {
      Navigator.pop(context, imp.trip.id);
    }
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
