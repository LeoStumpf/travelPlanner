import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import '../../domain/packing.dart';
import '../../state/providers.dart';
import '../common/dialogs.dart';
import '../common/l10n.dart';
import '../common/style.dart';

/// Compact rendering of a note/checklist/link/image card, used in the Keep
/// grid and on the canvas. With [tickable], open checklist entries can be
/// ticked off right in the preview (one undoable step each).
class CardPreview extends ConsumerWidget {
  final NoteCard card;
  final TripData data;
  final bool selected;
  final int maxLines;
  final bool tickable;

  const CardPreview({
    super.key,
    required this.card,
    required this.data,
    this.selected = false,
    this.maxLines = 10,
    this.tickable = false,
  });

  Future<void> _tick(BuildContext context, WidgetRef ref, ChecklistEntry e) {
    final label = context.l10n.stepEntryTicked(e.text);
    final messenger = ScaffoldMessenger.of(context);
    final actions = ref.read(planActionsProvider);
    final repo = ref.read(repositoryProvider);
    Future<void> run() async {
      // The preview may still show the card from before an earlier tick.
      final fresh = await repo.loadCard(card.id);
      final entry = fresh?.checklist.where((x) => x.id == e.id).firstOrNull;
      if (fresh == null || entry == null || entry.done) return;
      await actions.record(card.tripId, label, (r) => r.saveCard(setEntryDone(fresh, e.id, true)));
      final step = actions.lastStep(card.tripId);
      // The entry leaves the preview, so a mistap needs a quick way back.
      showUndoSnack(messenger, label, () => actions.undoStep(card.tripId, step));
    }

    // Ticks run one after another, so quick taps on several entries neither
    // overwrite each other nor share one undo snapshot.
    return actions.queued(run);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final img = data.attachmentsOf(card.id).where((a) => a.isImage).firstOrNull;
    final linked = data.item(card.itemId);
    final files = ref.read(repositoryProvider).files;

    return Material(
      color: noteBackground(context, card.color),
      elevation: selected ? 6 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (img != null)
            Image.file(files.fileFor(img), height: 120, fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(height: 40, child: Icon(Icons.broken_image)))
          else if (card.type == CardType.link && card.previewImageUrl != null)
            Image.network(card.previewImageUrl!, height: 100, fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink()),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  if (card.pinned) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.push_pin, size: 14)),
                  if (card.type == CardType.link) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.link, size: 16)),
                  if (card.title.isNotEmpty)
                    Expanded(child: Text(card.title, style: theme.textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
                ]),
                if (card.type == CardType.link && card.url != null)
                  Text(Uri.tryParse(card.url!)?.host ?? card.url!,
                      style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (card.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(card.text.trim(), maxLines: maxLines, overflow: TextOverflow.ellipsis),
                ],
                if (card.type == CardType.checklist) ...[
                  const SizedBox(height: 4),
                  for (final e in card.checklist.where((e) => !e.done).take(maxLines))
                    if (tickable)
                      Semantics(
                        key: ValueKey('tick-${e.id}'),
                        checked: false,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => _tick(context, ref, e),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 36),
                            child: Row(children: [
                              const Icon(Icons.check_box_outline_blank, size: 20),
                              const SizedBox(width: 8),
                              Expanded(child: Text(e.text, maxLines: 2, overflow: TextOverflow.ellipsis)),
                            ]),
                          ),
                        ),
                      )
                    else
                      Row(children: [
                        const Icon(Icons.check_box_outline_blank, size: 16),
                        const SizedBox(width: 6),
                        Expanded(child: Text(e.text, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ]),
                  if (card.checklist.any((e) => e.done))
                    Text(context.l10n.checklistMoreDone(card.checklist.where((e) => e.done).length),
                        style: theme.textTheme.bodySmall),
                ],
                if (linked != null) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(itemIcon(linked), size: 14, color: kindColor(linked.kind)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(linked.title, style: theme.textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
