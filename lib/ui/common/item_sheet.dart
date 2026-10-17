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
import 'l10n.dart';
import 'style.dart';

String timeSummary(AppLocalizations l, PlanItem i, DateTime? tripStart) {
  if (!i.isScheduled) return l.notScheduledYet;
  final s = l.moment(tripStart, i.start!);
  final e = dayOf(i.start!) == dayOf(i.end!) ? formatClock(i.end!) : l.moment(tripStart, i.end!);
  final extra = switch (i.kind) {
    ItemKind.stay => ' · ${l.days(daysTouched(i.start!, i.end!))} · ${l.nights(nightsIn(i.start!, i.end!))}',
    ItemKind.accommodation => ' · ${l.nights(nightsIn(i.start!, i.end!))}',
    _ => '',
  };
  return '$s → $e$extra';
}

/// Makes accommodation [item] the chosen one for its nights (see
/// [chooseOption]) as one undoable step. With [undoSnack] it offers
/// "Undo" – not from inside the item sheet, which would hide the
/// snackbar; the sheet shows the new status itself.
Future<void> chooseAccommodation(BuildContext context, WidgetRef ref, TripData data, PlanItem item,
    {bool book = false, bool undoSnack = true}) async {
  final changed = chooseOption(data.items, item.id, book: book);
  if (changed.isEmpty) return;
  final messenger = ScaffoldMessenger.of(context);
  final actions = ref.read(planActionsProvider);
  final l = context.l10n;
  final label = book ? l.stepMarkedBooked(item.title) : l.stepChosen(item.title);
  await actions.saveItems(data, changed, label);
  if (!undoSnack) return;
  final step = actions.lastStep(data.trip.id);
  showUndoSnack(messenger, label, () => actions.undoStep(data.trip.id, step));
}

/// The item sheet's "Booked" toggle as one undoable step (see [setBooked]).
Future<void> toggleBooked(AppLocalizations l, WidgetRef ref, TripData data, PlanItem item) {
  final booked = item.status != ItemStatus.booked;
  final label = booked ? l.stepMarkedBooked(item.title) : l.stepUnbooked(item.title);
  return ref.read(planActionsProvider).saveItems(data, setBooked(data.items, item.id, booked), label);
}

/// Fixes or releases [item] as one undoable step.
Future<void> toggleFixed(AppLocalizations l, WidgetRef ref, TripData data, PlanItem item) {
  final label = item.fixed ? l.stepUnfixed(item.title) : l.stepFixed(item.title);
  return ref.read(planActionsProvider).saveItems(data, [item.copyWith(fixed: !item.fixed)], label);
}

/// Moves [item] by [days] whole days with the scheduler, rippling like a
/// drag on the timeline in the current shift mode. One undoable step.
Future<void> shiftItemDays(AppLocalizations l, WidgetRef ref, TripData data, PlanItem item, int days) {
  final r = Scheduler.move(data.items, item.id, days * minutesPerDay, ref.read(tripUiProvider).shiftMode);
  final label = l.stepShiftedDays(item.title, days > 0 ? '+' : '−', l.days(days.abs()));
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
    final l = context.l10n;

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
          if (item.fixed) Tooltip(message: l.fixedAppointment, child: const Icon(Icons.lock)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 4, children: [
          Chip(
            avatar: Icon(statusIcon(item.status), size: 16),
            label: Text(l.status(item.status)),
            visualDensity: VisualDensity.compact,
          ),
          Chip(label: Text(l.layer(item.kind)), visualDensity: VisualDensity.compact),
          if (item.mode != null) Chip(label: Text(l.mode(item.mode!)), visualDensity: VisualDensity.compact),
        ]),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule),
          title: Text(timeSummary(l, item, tripStart)),
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
            title: Text(l.belongsTo(data.item(item.parentId)!.title)),
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
            label: Text(l.edit),
          ),
          if (view != TripView.timeline && item.isScheduled)
            OutlinedButton.icon(onPressed: () => goto(TripView.timeline), icon: const Icon(Icons.view_timeline), label: Text(l.viewTimeline)),
          if (view != TripView.map && (item.hasLocation || item.kind == ItemKind.transport))
            OutlinedButton.icon(onPressed: () => goto(TripView.map), icon: const Icon(Icons.map), label: Text(l.viewMap)),
          if (view != TripView.canvas)
            OutlinedButton.icon(onPressed: () => goto(TripView.canvas), icon: const Icon(Icons.dashboard), label: Text(l.viewCanvas)),
        ]),
        if (item.kind == ItemKind.accommodation &&
            item.status != ItemStatus.booked &&
            item.status != ItemStatus.planned) ...[
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => chooseAccommodation(context, ref, data, item, undoSnack: false),
            icon: const Icon(Icons.check_circle_outline),
            label: Text(l.chooseThisOption),
          ),
        ],
        if (item.notes.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(item.notes),
        ],
        if (item.kind == ItemKind.stay) ...[
          _section(context, l.sectionAccommodations, ItemKind.accommodation, data, id),
          for (final o in lodging) _childTile(context, ref, data, o, options: lodging),
          _section(context, l.sectionActivities, ItemKind.activity, data, id),
          for (final a in activities) _childTile(context, ref, data, a),
          _header(context, l.kindTransport),
          _transportActions(context, data, item),
          for (final t in transports) _childTile(context, ref, data, t),
        ],
        if (item.links.isNotEmpty) _header(context, l.sectionLinks),
        for (final link in item.links)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.link),
            title: Text(link, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication),
          ),
        if (atts.isNotEmpty) _header(context, l.sectionAttachments),
        for (final a in atts)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(a.isImage ? Icons.image : (a.mime == 'application/pdf' ? Icons.picture_as_pdf : Icons.attach_file)),
            title: Text(a.fileName),
            onTap: () => OpenFilex.open(ref.read(repositoryProvider).files.fileFor(a).path, type: a.mime),
          ),
        if (cards.isNotEmpty) _header(context, l.viewNotes),
        for (final c in cards)
          Card(
            color: noteBackground(context, c.color),
            child: ListTile(
              title: Text(c.title.isEmpty ? (c.text.split('\n').first) : c.title),
              subtitle: c.type == CardType.checklist
                  ? Text(l.checklistProgress(c.checklist.where((e) => e.done).length, c.checklist.length))
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
            label: Text(kind == ItemKind.accommodation ? context.l10n.statusOption : context.l10n.add),
          ),
        ]),
      );

  /// "+ Transport here" from the previous stay and "+ Onward transport"
  /// to the next one (by [stayChain]); without a neighbour the other end
  /// stays open in the editor.
  Widget _transportActions(BuildContext context, TripData data, PlanItem stay) {
    final (prev, next) = neighbourStays(data.items, stay.id);
    void open({PlanItem? from, PlanItem? to}) {
      Navigator.pop(context);
      openTransportEditor(context, data, from: from, to: to);
    }

    return Wrap(spacing: 8, children: [
      TextButton.icon(
        key: const ValueKey('transport-here'),
        onPressed: () => open(from: prev, to: stay),
        icon: const Icon(Icons.add, size: 18),
        label: Text(context.l10n.transportHere),
      ),
      TextButton.icon(
        key: const ValueKey('transport-onward'),
        onPressed: () => open(from: stay, to: next),
        icon: const Icon(Icons.add, size: 18),
        label: Text(context.l10n.transportOnward),
      ),
    ]);
  }

  Widget _childTile(BuildContext context, WidgetRef ref, TripData data, PlanItem i, {List<PlanItem>? options}) {
    final canChoose = options != null && i.isOption;
    final l = context.l10n;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(itemIcon(i), color: kindColor(i.kind).withValues(alpha: i.isOption ? 0.5 : 1)),
      title: Text(i.title,
          style: i.isOption ? const TextStyle(fontStyle: FontStyle.italic) : null),
      subtitle: Text('${l.status(i.status)} · ${timeSummary(l, i, data.trip.startDate)}'),
      trailing: canChoose
          ? TextButton(
              onPressed: () => chooseAccommodation(context, ref, data, i, undoSnack: false),
              child: Text(l.choose),
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
    final l = context.l10n;
    return Wrap(spacing: 6, runSpacing: 4, children: [
      FilterChip(
        key: const ValueKey('quick-booked'),
        avatar: Icon(statusIcon(ItemStatus.booked), size: 16),
        showCheckmark: false,
        label: Text(l.statusBooked),
        selected: item.status == ItemStatus.booked,
        onSelected: (_) => toggleBooked(l, ref, data, item),
      ),
      FilterChip(
        key: const ValueKey('quick-fixed'),
        avatar: Icon(item.fixed ? Icons.lock : Icons.lock_open, size: 16),
        showCheckmark: false,
        label: Text(l.fixedChip),
        tooltip: l.fixedTooltip,
        selected: item.fixed,
        onSelected: (_) => toggleFixed(l, ref, data, item),
      ),
      if (item.isScheduled) ...[
        ActionChip(
          key: const ValueKey('quick-earlier'),
          label: Text(l.minusOneDay),
          tooltip: item.fixed ? l.fixedNotMoved : null,
          onPressed: canShift ? () => shiftItemDays(l, ref, data, item, -1) : null,
        ),
        ActionChip(
          key: const ValueKey('quick-later'),
          label: Text(l.plusOneDay),
          tooltip: item.fixed ? l.fixedNotMoved : null,
          onPressed: canShift ? () => shiftItemDays(l, ref, data, item, 1) : null,
        ),
      ],
      ActionChip(
        key: const ValueKey('quick-delete'),
        avatar: Icon(Icons.delete_outline, size: 16, color: scheme.error),
        label: Text(l.delete, style: TextStyle(color: scheme.error)),
        onPressed: () => _delete(context, ref),
      ),
    ]);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    if (!await confirm(context, l.deleteQuestion(item.title))) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final actions = ref.read(planActionsProvider);
    final ui = ref.read(tripUiProvider.notifier);
    final tripId = data.trip.id;
    // The sheet (and this widget's ref) is gone after the pop.
    Navigator.pop(context);
    final label = l.stepDeleted(item.title);
    await actions.deleteItem(data, item.id, label);
    final step = actions.lastStep(tripId);
    ui.select(null);
    showUndoSnack(messenger, label, () => actions.undoStep(tripId, step));
  }
}
