import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/analysis.dart';
import '../../domain/models.dart';
import '../../domain/scheduler.dart';
import '../../domain/time.dart';
import '../../state/providers.dart';
import '../editor/card_editor_page.dart';
import '../editor/item_editor_page.dart';
import 'conflict_tile.dart';
import 'dialogs.dart';
import 'style.dart';

String timeSummary(PlanItem i, DateTime? tripStart) {
  if (!i.isScheduled) return 'Noch nicht eingeplant';
  final s = formatMoment(tripStart, i.start!);
  final e = dayOf(i.start!) == dayOf(i.end!) ? formatClock(i.end!) : formatMoment(tripStart, i.end!);
  final extra = switch (i.kind) {
    ItemKind.stay => ' · ${pluralDays(daysTouched(i.start!, i.end!))} · ${pluralNights(nightsIn(i.start!, i.end!))}',
    ItemKind.accommodation => ' · ${pluralNights(nightsIn(i.start!, i.end!))}',
    _ => '',
  };
  return '$s → $e$extra';
}

/// Makes accommodation [item] the chosen one for its nights (see
/// [chooseOption]) as one undoable step. With [undoSnack] it offers
/// "Rückgängig" – not from inside the item sheet, which would hide the
/// snackbar; the sheet shows the new status itself.
Future<void> chooseAccommodation(BuildContext context, WidgetRef ref, TripData data, PlanItem item,
    {bool book = false, bool undoSnack = true}) async {
  final changed = chooseOption(data.items, item.id, book: book);
  if (changed.isEmpty) return;
  final messenger = ScaffoldMessenger.of(context);
  final actions = ref.read(planActionsProvider);
  final label = book ? '„${item.title}“ als gebucht markiert' : '„${item.title}“ gewählt';
  await actions.saveItems(data, changed, label);
  if (!undoSnack) return;
  final step = actions.lastStep(data.trip.id);
  showUndoSnack(messenger, label, () => actions.undoStep(data.trip.id, step));
}

/// The item sheet's "Gebucht" toggle as one undoable step (see [setBooked]).
Future<void> toggleBooked(WidgetRef ref, TripData data, PlanItem item) {
  final booked = item.status != ItemStatus.booked;
  final label = booked ? '„${item.title}“ als gebucht markiert' : '„${item.title}“ nicht mehr gebucht';
  return ref.read(planActionsProvider).saveItems(data, setBooked(data.items, item.id, booked), label);
}

/// Fixes or releases [item] as one undoable step.
Future<void> toggleFixed(WidgetRef ref, TripData data, PlanItem item) {
  final label = item.fixed ? '„${item.title}“ nicht mehr fix' : '„${item.title}“ fixiert';
  return ref.read(planActionsProvider).saveItems(data, [item.copyWith(fixed: !item.fixed)], label);
}

/// Moves [item] by [days] whole days with the scheduler, rippling like a
/// drag on the timeline in the current shift mode. One undoable step.
Future<void> shiftItemDays(WidgetRef ref, TripData data, PlanItem item, int days) {
  final r = Scheduler.move(data.items, item.id, days * minutesPerDay, ref.read(tripUiProvider).shiftMode);
  final label = '„${item.title}“ ${days > 0 ? '+' : '−'}${pluralDays(days.abs())}';
  return ref.read(planActionsProvider).applySchedule(data, r, label);
}

/// Selects [id] and shows its details with links to the other views.
Future<void> showItemSheet(BuildContext context, WidgetRef ref, String tripId, String id) {
  ref.read(tripUiProvider.notifier).select(id);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.25,
      maxChildSize: 0.95,
      builder: (c, scroll) => _ItemSheet(tripId: tripId, id: id, scroll: scroll),
    ),
  );
}

class _ItemSheet extends ConsumerWidget {
  final String tripId;
  final String id;
  final ScrollController scroll;
  const _ItemSheet({required this.tripId, required this.id, required this.scroll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(tripDataProvider(tripId)).value;
    final item = data?.item(id);
    if (data == null || item == null) return const SizedBox(height: 120);
    final tripStart = data.trip.startDate;
    final conflicts = findConflicts(data.items).where((c) => c.involves(id)).toList();
    final children = [for (final i in data.items) if (i.parentId == id) i];
    final lodging = children.where((i) => i.kind == ItemKind.accommodation).toList();
    final activities = children.where((i) => i.kind == ItemKind.activity).toList()
      ..sort((a, b) => (a.start ?? 0).compareTo(b.start ?? 0));
    final transports = [for (final i in data.items) if (i.fromId == id || i.toId == id) i];
    final cards = [for (final c in data.cards) if (c.itemId == id) c];
    final atts = data.attachmentsOf(id);
    final ui = ref.read(tripUiProvider.notifier);
    final view = ref.watch(tripUiProvider.select((u) => u.view));
    final theme = Theme.of(context);

    void goto(TripView v) {
      ui.select(id);
      ui.setView(v);
      Navigator.pop(context);
    }

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Row(children: [
          CircleAvatar(
            backgroundColor: kindColor(item.kind).withValues(alpha: item.isOption ? 0.4 : 1),
            child: Icon(itemIcon(item), color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(item.title, style: theme.textTheme.titleLarge)),
          if (item.fixed) const Tooltip(message: 'Fixer Termin', child: Icon(Icons.lock)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 4, children: [
          Chip(
            avatar: Icon(statusIcon(item.status), size: 16),
            label: Text(item.status.label),
            visualDensity: VisualDensity.compact,
          ),
          Chip(label: Text('Ebene ${item.kind.layer}: ${item.kind.label}'), visualDensity: VisualDensity.compact),
          if (item.mode != null) Chip(label: Text(item.mode!.label), visualDensity: VisualDensity.compact),
        ]),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule),
          title: Text(timeSummary(item, tripStart)),
        ),
        if (item.kind == ItemKind.transport)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.route),
            title: Text('${data.item(item.fromId)?.title ?? '?'} → ${data.item(item.toId)?.title ?? '?'}'),
          ),
        if (item.parentId != null && data.item(item.parentId) != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.subdirectory_arrow_right),
            title: Text('Gehört zu ${data.item(item.parentId)!.title}'),
            onTap: () {
              Navigator.pop(context);
              showItemSheet(context, ref, tripId, item.parentId!);
            },
          ),
        if (item.placeName != null)
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.place_outlined), title: Text(item.placeName!)),
        for (final c in conflicts) ConflictTile(conflict: c, data: data),
        const SizedBox(height: 4),
        _QuickActions(data: data, item: item),
        const SizedBox(height: 8),
        // Jumps to the other views; the current one is already showing it.
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              openItemEditor(context, data, item: item);
            },
            icon: const Icon(Icons.edit),
            label: const Text('Bearbeiten'),
          ),
          if (view != TripView.timeline && item.isScheduled)
            OutlinedButton.icon(onPressed: () => goto(TripView.timeline), icon: const Icon(Icons.view_timeline), label: const Text('Zeitplan')),
          if (view != TripView.map && (item.hasLocation || item.kind == ItemKind.transport))
            OutlinedButton.icon(onPressed: () => goto(TripView.map), icon: const Icon(Icons.map), label: const Text('Karte')),
          if (view != TripView.canvas)
            OutlinedButton.icon(onPressed: () => goto(TripView.canvas), icon: const Icon(Icons.dashboard), label: const Text('Canvas')),
        ]),
        if (item.kind == ItemKind.accommodation &&
            item.status != ItemStatus.booked &&
            item.status != ItemStatus.planned) ...[
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => chooseAccommodation(context, ref, data, item, undoSnack: false),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Diese Option wählen'),
          ),
        ],
        if (item.notes.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(item.notes),
        ],
        if (item.kind == ItemKind.stay) ...[
          _section(context, 'Unterkünfte', ItemKind.accommodation, data, id),
          for (final l in lodging) _childTile(context, ref, data, l, options: lodging),
          _section(context, 'Aktivitäten', ItemKind.activity, data, id),
          for (final a in activities) _childTile(context, ref, data, a),
          if (transports.isNotEmpty) _header(context, 'Transport'),
          for (final t in transports) _childTile(context, ref, data, t),
        ],
        if (item.links.isNotEmpty) _header(context, 'Links'),
        for (final l in item.links)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.link),
            title: Text(l, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => launchUrl(Uri.parse(l), mode: LaunchMode.externalApplication),
          ),
        if (atts.isNotEmpty) _header(context, 'Tickets & Anhänge'),
        for (final a in atts)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(a.isImage ? Icons.image : (a.mime == 'application/pdf' ? Icons.picture_as_pdf : Icons.attach_file)),
            title: Text(a.fileName),
            onTap: () => OpenFilex.open(ref.read(repositoryProvider).files.fileFor(a).path, type: a.mime),
          ),
        if (cards.isNotEmpty) _header(context, 'Notizen'),
        for (final c in cards)
          Card(
            color: noteBackground(context, c.color),
            child: ListTile(
              title: Text(c.title.isEmpty ? (c.text.split('\n').first) : c.title),
              subtitle: c.type == CardType.checklist
                  ? Text('${c.checklist.where((e) => e.done).length}/${c.checklist.length} erledigt')
                  : null,
              onTap: () => openCardEditor(context, data, card: c),
            ),
          ),
      ],
    );
  }

  Widget _header(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Text(t, style: Theme.of(context).textTheme.titleSmall),
      );

  Widget _section(BuildContext context, String title, ItemKind kind, TripData data, String parentId) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          TextButton.icon(
            onPressed: () => openItemEditor(context, data, newKind: kind, parentHint: parentId),
            icon: const Icon(Icons.add, size: 18),
            label: Text(kind == ItemKind.accommodation ? 'Option' : 'Hinzufügen'),
          ),
        ]),
      );

  Widget _childTile(BuildContext context, WidgetRef ref, TripData data, PlanItem i, {List<PlanItem>? options}) {
    final canChoose = options != null && i.isOption;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(itemIcon(i), color: kindColor(i.kind).withValues(alpha: i.isOption ? 0.5 : 1)),
      title: Text(i.title,
          style: i.isOption ? const TextStyle(fontStyle: FontStyle.italic) : null),
      subtitle: Text('${i.status.label} · ${timeSummary(i, data.trip.startDate)}'),
      trailing: canChoose
          ? TextButton(
              onPressed: () => chooseAccommodation(context, ref, data, i, undoSnack: false),
              child: const Text('Wählen'),
            )
          : null,
      onTap: () {
        Navigator.pop(context);
        showItemSheet(context, ref, tripId, i.id);
      },
    );
  }
}

/// One-tap changes without opening the editor: booked and fixed toggles,
/// shifting by a day and deleting. Each is one undoable step; the sheet
/// shows the result directly, the app bar's undo reverts it.
class _QuickActions extends ConsumerWidget {
  final TripData data;
  final PlanItem item;
  const _QuickActions({required this.data, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final canShift = item.isScheduled && !item.fixed;
    return Wrap(spacing: 6, runSpacing: 4, children: [
      FilterChip(
        key: const ValueKey('quick-booked'),
        avatar: Icon(statusIcon(ItemStatus.booked), size: 16),
        showCheckmark: false,
        label: const Text('Gebucht'),
        selected: item.status == ItemStatus.booked,
        onSelected: (_) => toggleBooked(ref, data, item),
      ),
      FilterChip(
        key: const ValueKey('quick-fixed'),
        avatar: Icon(item.fixed ? Icons.lock : Icons.lock_open, size: 16),
        showCheckmark: false,
        label: const Text('Fix'),
        tooltip: 'Fixe Termine bleiben beim Verschieben stehen',
        selected: item.fixed,
        onSelected: (_) => toggleFixed(ref, data, item),
      ),
      if (item.isScheduled) ...[
        ActionChip(
          key: const ValueKey('quick-earlier'),
          label: const Text('−1 Tag'),
          tooltip: item.fixed ? 'Fixe Termine werden nicht verschoben' : null,
          onPressed: canShift ? () => shiftItemDays(ref, data, item, -1) : null,
        ),
        ActionChip(
          key: const ValueKey('quick-later'),
          label: const Text('+1 Tag'),
          tooltip: item.fixed ? 'Fixe Termine werden nicht verschoben' : null,
          onPressed: canShift ? () => shiftItemDays(ref, data, item, 1) : null,
        ),
      ],
      ActionChip(
        key: const ValueKey('quick-delete'),
        avatar: Icon(Icons.delete_outline, size: 16, color: scheme.error),
        label: Text('Löschen', style: TextStyle(color: scheme.error)),
        onPressed: () => _delete(context, ref),
      ),
    ]);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    if (!await confirm(context, '„${item.title}“ löschen?')) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final actions = ref.read(planActionsProvider);
    final ui = ref.read(tripUiProvider.notifier);
    final tripId = data.trip.id;
    // The sheet (and this widget's ref) is gone after the pop.
    Navigator.pop(context);
    await actions.deleteItem(data, item.id);
    final step = actions.lastStep(tripId);
    ui.select(null);
    showUndoSnack(messenger, '„${item.title}“ gelöscht', () => actions.undoStep(tripId, step));
  }
}
