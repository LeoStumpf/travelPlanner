import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/packing.dart';
import '../../state/providers.dart';
import '../common/l10n.dart';

/// What the packing list sheet picked: a title for a new list and its entries.
class PackingPick {
  final String title;
  final List<String> entries;
  const PackingPick(this.title, this.entries);
}

/// Offers the packing list templates (several can be combined) and the
/// checklists of other trips. [adding] words the sheet for adding entries to
/// an existing list instead of creating one.
Future<PackingPick?> showPackingSheet(BuildContext context, {required String tripId, bool adding = false}) =>
    showModalBottomSheet<PackingPick>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => PackingSheet(tripId: tripId, adding: adding),
    );

class PackingSheet extends ConsumerStatefulWidget {
  final String tripId;
  final bool adding;
  const PackingSheet({super.key, required this.tripId, this.adding = false});

  @override
  ConsumerState<PackingSheet> createState() => _PackingSheetState();
}

class _PackingSheetState extends ConsumerState<PackingSheet> {
  final Set<PackingTemplate> _chosen = {};

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    // Chosen templates in their natural order, overlaps (sunscreen, rain jacket) once.
    final chosen = [for (final t in PackingTemplate.values) if (_chosen.contains(t)) t];
    final entries = newEntryTexts(const [], [for (final t in chosen) ...l.packingTemplateEntries(t)]);
    final sources = ref.watch(checklistSourcesProvider);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(widget.adding ? l.packingAddFrom : l.packingList, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(l.packingTemplates, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in PackingTemplate.values)
                FilterChip(
                  key: ValueKey('packing-${t.name}'),
                  label: Text(l.packingTemplate(t)),
                  selected: _chosen.contains(t),
                  onSelected: (v) => setState(() => v ? _chosen.add(t) : _chosen.remove(t)),
                ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Text(
                  chosen.isEmpty ? '' : l.packingEntryCount(entries.length),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              FilledButton(
                onPressed: chosen.isEmpty
                    ? null
                    : () => Navigator.pop(
                          context,
                          PackingPick(
                            '${l.packingList} · ${chosen.map(l.packingTemplate).join(', ')}',
                            entries,
                          ),
                        ),
                child: Text(widget.adding ? l.packingAdd : l.packingCreate),
              ),
            ]),
            const Divider(height: 32),
            Text(l.packingFromOtherTrip, style: theme.textTheme.titleSmall),
            ...sources.when(
              loading: () => const [Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))],
              error: (e, _) => [Padding(padding: const EdgeInsets.all(8), child: Text(l.error(e)))],
              data: (all) {
                final list = copyableChecklists(all, widget.tripId);
                if (list.isEmpty) {
                  return [Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(l.packingNoOtherLists))];
                }
                return [
                  for (final s in list)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.checklist),
                      title: Text(s.card.title.isEmpty ? l.packingList : s.card.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(l.packingSource(s.tripTitle, s.entries.length),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => Navigator.pop(
                        context,
                        PackingPick(s.card.title.isEmpty ? l.packingList : s.card.title, s.entries),
                      ),
                    ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}
