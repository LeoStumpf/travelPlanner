import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import '../../state/providers.dart';
import '../canvas/canvas_view.dart';
import '../common/dialogs.dart';
import '../common/style.dart';
import '../editor/card_editor_page.dart';
import '../editor/item_editor_page.dart';
import '../keep/notes_view.dart';
import '../map/map_view.dart';
import '../timeline/timeline_view.dart';
import '../trips/trip_settings_dialog.dart';
import '../trips/trips_page.dart';

class TripPage extends ConsumerStatefulWidget {
  final String tripId;
  const TripPage({super.key, required this.tripId});

  @override
  ConsumerState<TripPage> createState() => _TripPageState();
}

class _TripPageState extends ConsumerState<TripPage> {
  /// Views are built on first visit and then kept alive (map keeps its camera).
  final _visited = <TripView>{};

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tripDataProvider(widget.tripId));
    final ui = ref.watch(tripUiProvider);
    final undoLabel = ref.watch(undoLabelProvider(widget.tripId));
    _visited.add(ui.view);

    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Fehler: $e'))),
      data: (data) {
        if (data == null) return const Scaffold(body: Center(child: Text('Reise nicht gefunden')));
        final showLayerBar = ui.view == TripView.timeline || ui.view == TripView.map;
        return Scaffold(
          appBar: AppBar(
            title: Text(data.trip.title),
            actions: [
              IconButton(
                tooltip: undoLabel == null ? 'Rückgängig' : 'Rückgängig: $undoLabel',
                onPressed: undoLabel != null ? _undo : null,
                icon: const Icon(Icons.undo),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'settings') {
                    final t = await showTripSettingsDialog(context, data.trip);
                    if (t != null) {
                      await ref.read(planActionsProvider).record(t.id, 'Reise bearbeitet', (r) => r.saveTrip(t));
                    }
                  } else if (v == 'export') {
                    if (context.mounted) await exportTrip(context, ref, data.trip);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'settings', child: Text('Reise bearbeiten')),
                  PopupMenuItem(value: 'export', child: Text('Backup exportieren')),
                ],
              ),
            ],
            bottom: showLayerBar
                ? PreferredSize(preferredSize: const Size.fromHeight(48), child: LayerBar(data: data))
                : null,
          ),
          body: IndexedStack(
            index: ui.view.index,
            children: [
              for (final v in TripView.values)
                if (!_visited.contains(v))
                  const SizedBox.shrink()
                else
                  switch (v) {
                    TripView.canvas => CanvasView(data: data),
                    TripView.notes => NotesView(data: data),
                    TripView.timeline => TimelineView(data: data),
                    TripView.map => TripMapView(data: data, active: ui.view == TripView.map),
                  },
            ],
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: 'Hinzufügen',
            onPressed: () => showAddSheet(context, ref, data),
            child: const Icon(Icons.add),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: ui.view.index,
            onDestinationSelected: (i) => ref.read(tripUiProvider.notifier).setView(TripView.values[i]),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Canvas'),
              NavigationDestination(icon: Icon(Icons.sticky_note_2_outlined), selectedIcon: Icon(Icons.sticky_note_2), label: 'Notizen'),
              NavigationDestination(icon: Icon(Icons.view_timeline_outlined), selectedIcon: Icon(Icons.view_timeline), label: 'Zeitplan'),
              NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Karte'),
            ],
          ),
        );
      },
    );
  }

  Future<void> _undo() async {
    final label = await ref.read(planActionsProvider).undo(widget.tripId);
    if (label != null && mounted) showSnack(context, 'Rückgängig: $label');
  }
}

/// Layer filter chips (places / transport / lodging / activities / options).
class LayerBar extends ConsumerWidget {
  final TripData data;
  const LayerBar({super.key, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(tripUiProvider);
    final n = ref.read(tripUiProvider.notifier);
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (final k in ItemKind.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(kindIcon(k), size: 16, color: kindColor(k)),
                label: Text('${k.layer} ${k.label}'),
                selected: ui.layers.contains(k),
                onSelected: (_) => n.toggleLayer(k),
              ),
            ),
          FilterChip(
            visualDensity: VisualDensity.compact,
            avatar: const Icon(Icons.help_outline, size: 16),
            label: const Text('Optionen'),
            selected: ui.showOptions,
            onSelected: (_) => n.toggleOptions(),
          ),
        ],
      ),
    );
  }
}

Future<void> showAddSheet(BuildContext context, WidgetRef ref, TripData data, {int? atDay}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plan', style: Theme.of(c).textTheme.titleSmall),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final k in ItemKind.values)
                ActionChip(
                  avatar: Icon(kindIcon(k), color: kindColor(k)),
                  label: Text(k.label),
                  onPressed: () => Navigator.pop(c, k.name),
                ),
            ]),
            const SizedBox(height: 16),
            Text('Sammeln', style: Theme.of(c).textTheme.titleSmall),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ActionChip(avatar: const Icon(Icons.notes), label: const Text('Notiz'), onPressed: () => Navigator.pop(c, 'note')),
              ActionChip(avatar: const Icon(Icons.checklist), label: const Text('Checkliste'), onPressed: () => Navigator.pop(c, 'checklist')),
              ActionChip(avatar: const Icon(Icons.link), label: const Text('Link'), onPressed: () => Navigator.pop(c, 'link')),
              ActionChip(avatar: const Icon(Icons.image), label: const Text('Bild'), onPressed: () => Navigator.pop(c, 'image')),
            ]),
          ],
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  final kind = ItemKind.values.where((k) => k.name == choice).firstOrNull;
  if (kind != null) {
    final parent = ref.read(tripUiProvider).selectedId;
    await openItemEditor(context, data, newKind: kind, atDay: atDay, parentHint: parent);
  } else {
    final type = CardType.values.firstWhere((t) => t.name == choice);
    await openCardEditor(context, data, newType: type);
  }
}
