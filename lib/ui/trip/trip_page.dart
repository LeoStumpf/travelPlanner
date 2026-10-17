import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/agenda.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../agenda/agenda_view.dart';
import '../canvas/canvas_view.dart';
import '../common/dialogs.dart';
import '../common/l10n.dart';
import '../common/style.dart';
import '../editor/card_editor_page.dart';
import '../editor/item_editor_page.dart';
import '../exchange/plan_exchange_ui.dart';
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
    final l = context.l10n;

    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text(l.errorWith('$e')))),
      data: (data) {
        if (data == null) return Scaffold(body: Center(child: Text(l.tripNotFound)));
        if (ui.pickView) _pickView(data, ui);
        final showLayerBar = ui.view == TripView.timeline || ui.view == TripView.map;
        return Scaffold(
          appBar: AppBar(
            title: Text(data.trip.title),
            actions: [
              IconButton(
                tooltip: undoLabel == null ? l.undo : l.undoWithLabel(undoLabel),
                onPressed: undoLabel != null ? _undo : null,
                icon: const Icon(Icons.undo),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'settings') {
                    final t = await showTripSettingsDialog(context, data.trip);
                    if (t != null) {
                      await ref.read(planActionsProvider).record(t.id, l.stepTripEdited, (r) => r.saveTrip(t));
                    }
                  } else if (v == 'export') {
                    if (context.mounted) await exportTrip(context, ref, data.trip);
                  } else if (v == 'claude') {
                    if (context.mounted) await showPlanExchangeSheet(context, ref, data);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'claude', child: Text(l.planWithClaude)),
                  PopupMenuItem(value: 'settings', child: Text(l.editTrip)),
                  PopupMenuItem(value: 'export', child: Text(l.exportBackup)),
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
                    TripView.agenda => AgendaView(data: data),
                  },
            ],
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: l.add,
            onPressed: () => showAddSheet(context, ref, data),
            child: const Icon(Icons.add),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: ui.view.index,
            onDestinationSelected: (i) => ref.read(tripUiProvider.notifier).setView(TripView.values[i]),
            destinations: [
              NavigationDestination(
                  icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard), label: l.viewCanvas),
              NavigationDestination(
                  icon: const Icon(Icons.sticky_note_2_outlined),
                  selectedIcon: const Icon(Icons.sticky_note_2),
                  label: l.viewNotes),
              NavigationDestination(
                  icon: const Icon(Icons.view_timeline_outlined),
                  selectedIcon: const Icon(Icons.view_timeline),
                  label: l.viewTimeline),
              NavigationDestination(icon: const Icon(Icons.map_outlined), selectedIcon: const Icon(Icons.map), label: l.viewMap),
              NavigationDestination(
                  icon: const Icon(Icons.today_outlined), selectedIcon: const Icon(Icons.today), label: l.viewAgenda),
            ],
          ),
        );
      },
    );
  }

  /// Right after opening: the agenda while the trip is running; otherwise
  /// the last view, except the agenda, which then falls back to the
  /// timeline. Runs after the frame – providers can't change during build.
  void _pickView(TripData data, TripUi ui) {
    final running = isTripRunning(data, ref.read(clockProvider)());
    final view = running ? TripView.agenda : (ui.view == TripView.agenda ? TripView.timeline : ui.view);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(tripUiProvider).pickView) ref.read(tripUiProvider.notifier).setView(view);
    });
  }

  Future<void> _undo() async {
    final label = await ref.read(planActionsProvider).undo(widget.tripId);
    if (label != null && mounted) showSnack(context, context.l10n.undoWithLabel(label));
  }
}

/// Layer filter chips (places / transport / lodging / activities / options).
/// Plain names – a leading layer number read like a count. Shown layers are
/// tinted in their colour with a border; hidden ones are grey and outlined.
class LayerBar extends ConsumerWidget {
  final TripData data;
  const LayerBar({super.key, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(tripUiProvider);
    final n = ref.read(tripUiProvider.notifier);
    final l = context.l10n;
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (final k in ItemKind.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: layerChip(
                context,
                key: ValueKey('layer-${k.name}'),
                icon: kindIcon(k),
                color: kindColor(k),
                label: l.kind(k),
                tooltip: l.layer(k),
                selected: ui.layers.contains(k),
                onSelected: () => n.toggleLayer(k),
              ),
            ),
          layerChip(
            context,
            key: const ValueKey('layer-options'),
            icon: Icons.help_outline,
            color: Theme.of(context).colorScheme.primary,
            label: l.layerOptions,
            tooltip: l.layerOptionsTooltip,
            selected: ui.showOptions,
            onSelected: n.toggleOptions,
          ),
        ],
      ),
    );
  }
}

/// A filter chip whose on/off state is obvious at a glance: on = tinted with
/// [color], coloured border and icon, bold label; off = grey, crossed-out
/// eye instead of the icon.
Widget layerChip(
  BuildContext context, {
  Key? key,
  required IconData icon,
  required Color color,
  required String label,
  required String tooltip,
  required bool selected,
  required VoidCallback onSelected,
}) {
  final scheme = Theme.of(context).colorScheme;
  final off = scheme.onSurfaceVariant.withValues(alpha: 0.7);
  return FilterChip(
    key: key,
    visualDensity: VisualDensity.compact,
    showCheckmark: false,
    tooltip: tooltip,
    avatar: Icon(selected ? icon : Icons.visibility_off_outlined, size: 16, color: selected ? color : off),
    label: Text(label),
    labelStyle: TextStyle(
      color: selected ? scheme.onSurface : off,
      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
    ),
    selectedColor: color.withValues(alpha: 0.22),
    backgroundColor: Colors.transparent,
    side: BorderSide(color: selected ? color : scheme.outlineVariant, width: selected ? 1.5 : 1),
    selected: selected,
    onSelected: (_) => onSelected(),
  );
}

Future<void> showAddSheet(BuildContext context, WidgetRef ref, TripData data, {int? atDay}) async {
  final l = context.l10n;
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
            Text(l.addSheetPlan, style: Theme.of(c).textTheme.titleSmall),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final k in ItemKind.values)
                ActionChip(
                  avatar: Icon(kindIcon(k), color: kindColor(k)),
                  label: Text(l.kind(k)),
                  onPressed: () => Navigator.pop(c, k.name),
                ),
            ]),
            const SizedBox(height: 16),
            Text(l.addSheetCollect, style: Theme.of(c).textTheme.titleSmall),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ActionChip(avatar: const Icon(Icons.notes), label: Text(l.cardNote), onPressed: () => Navigator.pop(c, 'note')),
              ActionChip(avatar: const Icon(Icons.checklist), label: Text(l.cardChecklist), onPressed: () => Navigator.pop(c, 'checklist')),
              ActionChip(avatar: const Icon(Icons.link), label: Text(l.cardLink), onPressed: () => Navigator.pop(c, 'link')),
              ActionChip(avatar: const Icon(Icons.image), label: Text(l.cardImage), onPressed: () => Navigator.pop(c, 'image')),
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
