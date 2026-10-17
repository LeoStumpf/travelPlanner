import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/db.dart';
import '../data/repository.dart';
import '../domain/models.dart';
import '../domain/scheduler.dart';

/// Overridden in main() with the initialised repository.
final repositoryProvider = Provider<Repository>((ref) => throw UnimplementedError());

final tripsProvider = StreamProvider<List<Trip>>((ref) => ref.watch(repositoryProvider).watchTrips());

final trashProvider = StreamProvider<List<TrashedTrip>>((ref) => ref.watch(repositoryProvider).watchTrash());

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

/// One undoable step: the trip's documents as they were before.
class UndoEntry {
  final String label;
  final String tripId;
  final List<DocRow> before;
  const UndoEntry(this.label, this.tripId, this.before);
}

/// Undo history per trip (kept while the app runs).
class UndoNotifier extends Notifier<Map<String, List<UndoEntry>>> {
  @override
  Map<String, List<UndoEntry>> build() => const {};

  void push(UndoEntry e) {
    final list = [...?state[e.tripId], e];
    state = {...state, e.tripId: list.length > 50 ? list.sublist(list.length - 50) : list};
  }

  UndoEntry? pop(String tripId) {
    final list = state[tripId];
    if (list == null || list.isEmpty) return null;
    state = {...state, tripId: list.sublist(0, list.length - 1)};
    return list.last;
  }

  void forget(String tripId) => state = {...state}..remove(tripId);
}

final undoProvider = NotifierProvider<UndoNotifier, Map<String, List<UndoEntry>>>(UndoNotifier.new);

/// Label of the step that undo would revert, or null.
final undoLabelProvider = Provider.family<String?, String>(
  (ref, tripId) => ref.watch(undoProvider)[tripId]?.lastOrNull?.label,
);

/// Every change to a trip goes through here so it can be undone.
class PlanActions {
  final Ref ref;
  PlanActions(this.ref);

  Repository get _repo => ref.read(repositoryProvider);

  /// Runs [change] as one undoable step.
  Future<T> record<T>(String tripId, String label, Future<T> Function(Repository repo) change) async {
    final before = await _repo.snapshotTrip(tripId);
    final result = await change(_repo);
    ref.read(undoProvider.notifier).push(UndoEntry(label, tripId, before));
    return result;
  }

  Future<void> saveItems(TripData data, Iterable<PlanItem> items, String label) async {
    final list = items.toList();
    if (list.isEmpty) return;
    await record(data.trip.id, label, (r) => r.saveItems(list));
  }

  Future<void> applySchedule(TripData data, ScheduleResult r, String label) =>
      saveItems(data, r.changed, label);

  Future<void> deleteItem(TripData data, String id) async {
    final item = data.item(id);
    if (item == null) return;
    await record(data.trip.id, '„${item.title}“ gelöscht', (r) => r.deleteItem(data, id));
  }

  /// Reverts the last step of [tripId]. Returns its label, or null.
  Future<String?> undo(String tripId) async {
    final e = ref.read(undoProvider.notifier).pop(tripId);
    if (e == null) return null;
    await _repo.restoreTrip(tripId, e.before);
    return e.label;
  }
}

final planActionsProvider = Provider<PlanActions>((ref) => PlanActions(ref));
