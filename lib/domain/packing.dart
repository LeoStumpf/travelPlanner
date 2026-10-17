import 'models.dart';

/// Checklist helpers: ticking entries, reordering them and filling packing
/// lists from templates or from another trip. Pure Dart; the entry texts of
/// the templates are worded by the UI (they are localised).

/// The built-in packing list templates. Their titles and entries live in the
/// ARB files (`packingTemplate*`).
enum PackingTemplate { basics, beach, hiking, city }

/// [card] with entry [entryId] ticked ([done] true) or unticked. Unknown ids
/// leave the card unchanged.
NoteCard setEntryDone(NoteCard card, String entryId, bool done) => card.copyWith(checklist: [
      for (final e in card.checklist) e.id == entryId ? e.copyWith(done: done) : e,
    ]);

/// Moves the open (not ticked) entry at [oldIndex] so it ends up at
/// [newIndex], both counted among the open entries only (as
/// `ReorderableListView.onReorderItem` reports them). Ticked entries keep their
/// slots in the full list, so their order does not change either.
List<ChecklistEntry> moveOpenEntry(List<ChecklistEntry> entries, int oldIndex, int newIndex) {
  final open = [for (final e in entries) if (!e.done) e];
  if (oldIndex < 0 || oldIndex >= open.length) return entries;
  newIndex = newIndex.clamp(0, open.length - 1);
  if (newIndex == oldIndex) return entries;
  final moved = open.removeAt(oldIndex);
  open.insert(newIndex, moved);
  var k = 0;
  return [for (final e in entries) e.done ? e : open[k++]];
}

/// The texts of [entries] that [existing] does not contain yet (compared
/// ignoring case and surrounding blanks), in order and without duplicates
/// among themselves. Empty texts are dropped.
List<String> newEntryTexts(Iterable<String> existing, Iterable<String> entries) {
  String norm(String s) => s.trim().toLowerCase();
  final seen = {for (final e in existing) norm(e)};
  return [
    for (final e in entries)
      if (e.trim().isNotEmpty && seen.add(norm(e))) e.trim(),
  ];
}

/// [current] plus open entries for [texts] that are not on the list yet.
/// Blank placeholder entries (an unfilled new row) are dropped first.
List<ChecklistEntry> addEntries(
  List<ChecklistEntry> current,
  Iterable<String> texts, {
  required String Function() newId,
}) {
  final kept = [for (final e in current) if (e.text.trim().isNotEmpty) e];
  final added = newEntryTexts(kept.map((e) => e.text), texts);
  if (added.isEmpty) return current;
  return [...kept, for (final t in added) ChecklistEntry(id: newId(), text: t)];
}

/// A checklist card of another trip, offered for "copy list from another trip".
class ChecklistSource {
  final String tripTitle;
  final NoteCard card;
  const ChecklistSource(this.tripTitle, this.card);

  /// The non-empty entry texts, in list order.
  List<String> get entries => [for (final e in card.checklist) if (e.text.trim().isNotEmpty) e.text.trim()];
}

/// The checklists of [sources] that can be copied into trip [tripId]: those
/// of other trips with at least one entry, newest first.
List<ChecklistSource> copyableChecklists(Iterable<ChecklistSource> sources, String tripId) {
  final list = [
    for (final s in sources)
      if (s.card.tripId != tripId && s.card.type == CardType.checklist && s.entries.isNotEmpty) s,
  ];
  list.sort((a, b) => b.card.createdAt.compareTo(a.card.createdAt));
  return list;
}
