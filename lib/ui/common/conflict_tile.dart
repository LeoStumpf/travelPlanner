import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/analysis.dart';
import '../../domain/models.dart';
import '../../domain/zones.dart';
import '../../state/providers.dart';
import 'dialogs.dart';
import 'item_sheet.dart';
import 'l10n.dart';
import 'style.dart';

/// A conflict with its one-tap fix – or, without one, why there is none –
/// and chips to open both items involved.
class ConflictTile extends ConsumerWidget {
  final Conflict conflict;
  final TripData data;
  final VoidCallback? onTap;
  final VoidCallback? onFixed;

  /// Opens one of the involved items; null hides the chips.
  final ValueChanged<String>? onOpen;

  /// The item whose sheet shows this tile: it gets no chip of its own.
  final String? currentId;

  const ConflictTile({
    super.key,
    required this.conflict,
    required this.data,
    this.onTap,
    this.onFixed,
    this.onOpen,
    this.currentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = Theme.of(context).colorScheme.error;
    final fix = conflict.fix;
    final l = context.l10n;
    final involved = [
      for (final id in [conflict.itemId, ?conflict.otherId])
        if (id != currentId) ?data.item(id),
    ];
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(Icons.warning_amber, color: error),
      title: Text(l.conflict(conflict), style: TextStyle(color: error)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fix != null)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.auto_fix_high, size: 18),
                label: Text(l.conflictFix(fix)),
                onPressed: () async {
                  final actions = ref.read(planActionsProvider);
                  final label = l.conflictFix(fix);
                  await actions.saveItems(data, fix.apply(data.items), label);
                  onFixed?.call();
                  if (context.mounted) {
                    showSnack(
                      context,
                      l.fixedApplied(label),
                      action: SnackBarAction(label: l.undo, onPressed: () => actions.undo(data.trip.id)),
                    );
                  }
                },
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(padding: EdgeInsets.only(top: 1, right: 6), child: Icon(Icons.info_outline, size: 16)),
                  Expanded(child: Text(l.conflictNoFix(conflict), key: const ValueKey('conflict-no-fix'))),
                ],
              ),
            ),
          if (onOpen != null && involved.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(spacing: 6, runSpacing: 4, children: [
                for (final i in involved)
                  ActionChip(
                    key: ValueKey('conflict-open-${i.id}'),
                    avatar: Icon(itemIcon(i), size: 16, color: kindColor(i.kind)),
                    label: Text(i.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    tooltip: l.openItemTitled(i.title),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onOpen!(i.id),
                  ),
              ]),
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// All conflicts of the trip in a bottom sheet. Tapping a tile opens its
/// item, the chips open either item involved.
void showConflictsSheet(BuildContext context, WidgetRef ref, TripData data) {
  final conflicts = findConflicts(data.items, zones: data.zones);
  void open(BuildContext sheet, String id) {
    Navigator.pop(sheet);
    showItemSheet(context, ref, data.trip.id, id);
  }

  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (c) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (conflicts.isEmpty) ListTile(title: Text(context.l10n.noConflicts)),
        for (final k in conflicts)
          ConflictTile(
            conflict: k,
            data: data,
            onFixed: () => Navigator.pop(c),
            onTap: () => open(c, k.itemId),
            onOpen: (id) => open(c, id),
          ),
      ],
    ),
  );
}

/// Warning icon with the number of conflicts, for app bars; nothing when
/// the plan has none.
class ConflictBadgeButton extends ConsumerWidget {
  final TripData data;
  const ConflictBadgeButton({super.key, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = findConflicts(data.items, zones: data.zones).length;
    if (n == 0) return const SizedBox.shrink();
    final l = context.l10n;
    return IconButton(
      key: const ValueKey('conflict-badge'),
      tooltip: '${l.conflictsCount(n)} – ${l.showConflicts}',
      onPressed: () => showConflictsSheet(context, ref, data),
      icon: Badge.count(
        count: n,
        child: Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
