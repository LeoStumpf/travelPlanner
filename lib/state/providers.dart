import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/repository.dart';
import '../domain/models.dart';
import '../domain/scheduler.dart';

/// Overridden in main() with the initialised repository.
final repositoryProvider = Provider<Repository>((ref) => throw UnimplementedError());

final tripsProvider = StreamProvider<List<Trip>>((ref) => ref.watch(repositoryProvider).watchTrips());

final tripDataProvider = StreamProvider.family<TripData?, String>(
  (ref, tripId) => ref.watch(repositoryProvider).watchTrip(tripId),
);

String newId() => const Uuid().v4();

enum TripView { canvas, notes, timeline, map }

extension TripViewX on TripView {
  String get label => switch (this) {
        TripView.canvas => 'Canvas',
        TripView.notes => 'Notizen',
        TripView.timeline => 'Zeitplan',
        TripView.map => 'Karte',
      };
}

/// View state shared by all views of the open trip, so switching views keeps
/// the selection and the layer filter.
class TripUi {
  final TripView view;
  final String? selectedId;
  final Set<ItemKind> layers;
  final bool showOptions;
  final ShiftMode shiftMode;

  const TripUi({
    this.view = TripView.timeline,
    this.selectedId,
    this.layers = const {...ItemKind.values},
    this.showOptions = true,
    this.shiftMode = ShiftMode.following,
  });

  bool shows(PlanItem i) => layers.contains(i.kind) && (showOptions || !i.isOption);

  TripUi copyWith({
    TripView? view,
    Object? selectedId = _keep,
    Set<ItemKind>? layers,
    bool? showOptions,
    ShiftMode? shiftMode,
  }) =>
      TripUi(
        view: view ?? this.view,
        selectedId: identical(selectedId, _keep) ? this.selectedId : selectedId as String?,
        layers: layers ?? this.layers,
        showOptions: showOptions ?? this.showOptions,
        shiftMode: shiftMode ?? this.shiftMode,
      );
}

const _keep = Object();

class TripUiNotifier extends Notifier<TripUi> {
  @override
  TripUi build() => const TripUi();

  void setView(TripView v) => state = state.copyWith(view: v);
  void select(String? id) => state = state.copyWith(selectedId: id);
  void setShiftMode(ShiftMode m) => state = state.copyWith(shiftMode: m);
  void toggleOptions() => state = state.copyWith(showOptions: !state.showOptions);
  void toggleLayer(ItemKind k) {
    final l = {...state.layers};
    if (!l.remove(k)) l.add(k);
    state = state.copyWith(layers: l);
  }

  void reset() => state = TripUi(view: state.view, shiftMode: state.shiftMode);
}

final tripUiProvider = NotifierProvider<TripUiNotifier, TripUi>(TripUiNotifier.new);

/// One undoable change to plan items: what they looked like before
/// (null = the item did not exist).
class UndoEntry {
  final String label;
  final String tripId;
  final Map<String, PlanItem?> before;
  const UndoEntry(this.label, this.tripId, this.before);
}

class UndoNotifier extends Notifier<List<UndoEntry>> {
  @override
  List<UndoEntry> build() => const [];

  void push(UndoEntry e) {
    final next = [...state, e];
    state = next.length > 50 ? next.sublist(next.length - 50) : next;
  }

  UndoEntry? pop() {
    if (state.isEmpty) return null;
    final e = state.last;
    state = state.sublist(0, state.length - 1);
    return e;
  }

  void clear() => state = const [];
}

final undoProvider = NotifierProvider<UndoNotifier, List<UndoEntry>>(UndoNotifier.new);

/// Write operations on plan items that record undo history.
class PlanActions {
  final Ref ref;
  PlanActions(this.ref);

  Repository get _repo => ref.read(repositoryProvider);

  /// Saves new or changed items as one undoable step.
  Future<void> saveItems(TripData data, Iterable<PlanItem> items, String label) async {
    final list = items.toList();
    if (list.isEmpty) return;
    ref
        .read(undoProvider.notifier)
        .push(UndoEntry(label, data.trip.id, {for (final i in list) i.id: data.item(i.id)}));
    await _repo.saveItems(list);
  }

  Future<void> applySchedule(TripData data, ScheduleResult r, String label) =>
      saveItems(data, r.changed, label);

  Future<void> deleteItem(TripData data, String id) async {
    final item = data.item(id);
    if (item == null) return;
    // Linked items lose their anchor; remember them so undo restores the links.
    final affected = <String, PlanItem?>{
      id: item,
      for (final i in data.items)
        if (i.parentId == id || i.fromId == id || i.toId == id) i.id: i,
    };
    ref.read(undoProvider.notifier).push(UndoEntry('„${item.title}“ gelöscht', data.trip.id, affected));
    await _repo.deleteItem(data, id);
  }

  /// Reverts the last step. Returns its label, or null if nothing to undo.
  Future<String?> undo() async {
    final e = ref.read(undoProvider.notifier).pop();
    if (e == null) return null;
    final created = [for (final en in e.before.entries) if (en.value == null) en.key];
    if (created.isNotEmpty) {
      final data = await _repo.loadTrip(e.tripId);
      if (data != null) {
        for (final id in created) {
          await _repo.deleteItem(data, id);
        }
      }
    }
    await _repo.saveItems([for (final v in e.before.values) ?v]);
    return e.label;
  }
}

final planActionsProvider = Provider<PlanActions>((ref) => PlanActions(ref));
