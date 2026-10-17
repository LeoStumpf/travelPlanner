// A readable itinerary for fellow travellers: the confirmed plan (planned
// and booked items, no options or ideas), arranged day by day. Pure Dart and
// language-neutral – the UI words it as text or PDF (lib/ui/share), and the
// calendar export (ics.dart) shares the selection rule [isShared].
import 'analysis.dart';
import 'models.dart';
import 'time.dart';

/// Whether [i] belongs into a shared plan: scheduled and planned or booked.
/// Options and ideas are private brainstorming.
bool isShared(PlanItem i) =>
    i.isScheduled && (i.status == ItemStatus.planned || i.status == ItemStatus.booked);

/// What an entry of a day stands for. The order breaks ties at the same
/// minute: leave the hotel, travel, do things, check in.
enum EntryRole { checkOut, transport, activity, checkIn }

/// One line of a day: an item in a [role], shown at local trip [minute].
class ItineraryEntry {
  final PlanItem item;
  final EntryRole role;
  final int minute;
  const ItineraryEntry(this.item, this.role, this.minute);
}

class ItineraryDay {
  final int day;

  /// Stays touching the day, in order (two on a travel day).
  final List<PlanItem> stays;

  /// Chronological. A transport or activity appears on its start day only,
  /// accommodation with its check-in and its check-out.
  final List<ItineraryEntry> entries;

  /// Accommodation covering the night from this day to the next.
  final PlanItem? night;

  /// A stay spans the night after this day but no bed covers it.
  final bool needsBed;

  const ItineraryDay({
    required this.day,
    this.stays = const [],
    this.entries = const [],
    this.night,
    this.needsBed = false,
  });

  /// Whether [night] is checked into today (then it needs no extra line).
  bool get checksIntoNight =>
      night != null && entries.any((e) => e.role == EntryRole.checkIn && e.item.id == night!.id);

  bool get isEmpty => entries.isEmpty && night == null && !needsBed;
}

class Itinerary {
  /// The route: shared stays in order.
  final List<PlanItem> stays;
  final List<ItineraryDay> days;

  /// Text, checklist and link notes linked to a shared item, by item id.
  final Map<String, List<NoteCard>> cardsByItem;

  /// The other notes worth sharing (not linked to a shared item).
  final List<NoteCard> notes;

  const Itinerary({
    this.stays = const [],
    this.days = const [],
    this.cardsByItem = const {},
    this.notes = const [],
  });

  int get firstDay => days.isEmpty ? 0 : days.first.day;
  int get lastDay => days.isEmpty ? 0 : days.last.day;
  int get dayCount => days.length;

  /// Every item that appears somewhere in the itinerary.
  Iterable<PlanItem> get items sync* {
    final seen = <String>{};
    for (final s in stays) {
      if (seen.add(s.id)) yield s;
    }
    for (final d in days) {
      for (final e in d.entries) {
        if (seen.add(e.item.id)) yield e.item;
      }
    }
  }
}

/// Whether a note card carries something readable (images only count with
/// a title, the picture itself is not exported).
bool _readable(NoteCard c) => switch (c.type) {
      CardType.note => c.title.trim().isNotEmpty || c.text.trim().isNotEmpty,
      CardType.checklist => c.title.trim().isNotEmpty || c.checklist.isNotEmpty,
      CardType.link => c.url != null || c.title.trim().isNotEmpty,
      CardType.image => c.title.trim().isNotEmpty || c.text.trim().isNotEmpty,
    };

/// The itinerary of [data]: every trip day from the first to the last
/// shared item (or the planned length, whichever is longer).
Itinerary buildItinerary(TripData data) {
  final shared = [for (final i in data.items) if (isShared(i)) i];
  final chain = stayChain(shared);
  final (first, last) = dayRange(shared, plannedDays: data.trip.plannedDays);
  final uncovered = uncoveredNights(shared).toSet();

  final perDay = <int, List<ItineraryEntry>>{};
  void add(int day, ItineraryEntry e) => (perDay[day] ??= []).add(e);
  for (final i in shared) {
    switch (i.kind) {
      case ItemKind.stay:
        break;
      case ItemKind.transport:
        add(dayOf(i.start!), ItineraryEntry(i, EntryRole.transport, i.start!));
      case ItemKind.activity:
        add(dayOf(i.start!), ItineraryEntry(i, EntryRole.activity, i.start!));
      case ItemKind.accommodation:
        add(dayOf(i.start!), ItineraryEntry(i, EntryRole.checkIn, i.start!));
        add(lastDayOf(i.end!), ItineraryEntry(i, EntryRole.checkOut, i.end!));
    }
  }

  final lodging = [for (final i in shared) if (i.kind == ItemKind.accommodation) i]
    ..sort((a, b) => a.start!.compareTo(b.start!));

  final days = <ItineraryDay>[
    for (var d = first; d <= last; d++)
      ItineraryDay(
        day: d,
        stays: [for (final s in chain) if (dayOf(s.start!) <= d && d <= lastDayOf(s.end!)) s],
        entries: (perDay[d] ?? [])
          ..sort((a, b) {
            final c = a.minute.compareTo(b.minute);
            return c != 0 ? c : a.role.index.compareTo(b.role.index);
          }),
        night: lodging.where((a) => dayOf(a.start!) <= d && d < lastDayOf(a.end!)).firstOrNull,
        needsBed: uncovered.contains(d),
      ),
  ];

  final sharedIds = {for (final i in shared) i.id};
  final byItem = <String, List<NoteCard>>{};
  final notes = <NoteCard>[];
  final cards = [for (final c in data.cards) if (_readable(c)) c]
    ..sort((a, b) => a.pinned == b.pinned ? a.createdAt.compareTo(b.createdAt) : (a.pinned ? -1 : 1));
  for (final c in cards) {
    if (c.itemId != null && sharedIds.contains(c.itemId)) {
      (byItem[c.itemId!] ??= []).add(c);
    } else {
      notes.add(c);
    }
  }

  return Itinerary(stays: chain, days: days, cardsByItem: byItem, notes: notes);
}
