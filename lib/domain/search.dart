// Global search across the plan items and notes of all trips – pure Dart.
//
// Matching is case- and accent-insensitive ("cafe" finds "Café") and every
// word of the query must occur somewhere in the item or card, though not
// necessarily in the same field ("kandy tuk" finds the activity "Tuk-tuk
// tour" whose place is Kandy). Folding keeps one character per character,
// so match positions in the folded text are positions in the original –
// the UI uses them to highlight the hits.

import 'models.dart';

/// Where in an item or card a hit was found.
enum SearchField {
  title,
  place,
  notes,
  link,
  departureStation,
  arrivalStation,
  transportNumber,
  seat,
  bookingRef,

  /// Text of a note card.
  text,

  /// One entry of a checklist.
  checklistEntry,

  /// File name of an attachment (ticket PDF, photo).
  attachment,

  /// Workspace folder of a file.
  folder,
}

// Umlauts as escapes: lib/domain carries no German literals (l10n_test).
const _accents = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', '\u00e4': 'a', 'å': 'a', 'ā': 'a', 'ą': 'a', //
  'ç': 'c', 'ć': 'c', 'č': 'c', 'ď': 'd', 'đ': 'd', //
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ė': 'e', 'ę': 'e', 'ě': 'e', //
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'ı': 'i', //
  'ł': 'l', 'ñ': 'n', 'ń': 'n', 'ň': 'n', //
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', '\u00f6': 'o', 'ø': 'o', 'ō': 'o', 'ő': 'o', //
  'ř': 'r', 'ś': 's', 'š': 's', 'ş': 's', 'ș': 's', 'ť': 't', 'ț': 't', //
  'ù': 'u', 'ú': 'u', 'û': 'u', '\u00fc': 'u', 'ū': 'u', 'ů': 'u', 'ű': 'u', //
  'ý': 'y', 'ÿ': 'y', 'ź': 'z', 'ż': 'z', 'ž': 'z',
};

/// Lower case without accents, exactly one output character per input
/// UTF-16 unit (characters whose lower case is longer stay as they are).
String foldForSearch(String s) {
  final out = StringBuffer();
  for (final unit in s.codeUnits) {
    final c = String.fromCharCode(unit);
    final lower = c.toLowerCase();
    final l = lower.length == 1 ? lower : c;
    out.write(_accents[l] ?? l);
  }
  return out.toString();
}

/// The folded words of [query]; empty when there is nothing to search.
List<String> searchTerms(String query) =>
    [for (final w in foldForSearch(query).split(RegExp(r'\s+'))) if (w.isNotEmpty) w];

/// Ranges (start, end) of [text] that match any of [terms], sorted and
/// merged – for highlighting.
List<(int, int)> matchRanges(String text, List<String> terms) {
  final folded = foldForSearch(text);
  final raw = <(int, int)>[];
  for (final t in terms) {
    var i = folded.indexOf(t);
    while (i >= 0) {
      raw.add((i, i + t.length));
      i = folded.indexOf(t, i + t.length);
    }
  }
  raw.sort((a, b) => a.$1.compareTo(b.$1));
  final merged = <(int, int)>[];
  for (final r in raw) {
    if (merged.isNotEmpty && r.$1 <= merged.last.$2) {
      final last = merged.removeLast();
      merged.add((last.$1, r.$2 > last.$2 ? r.$2 : last.$2));
    } else {
      merged.add(r);
    }
  }
  return merged;
}

/// A piece of [text] around its first match of [terms], on one line: at
/// most [before] characters ahead of the match, "…" where it was cut.
String searchSnippet(String text, List<String> terms, {int before = 24}) {
  final line = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final ranges = matchRanges(line, terms);
  if (ranges.isEmpty || ranges.first.$1 <= before) return line;
  var from = ranges.first.$1 - before;
  // Start at a word boundary where there is one close by.
  final space = line.indexOf(' ', from);
  if (space >= 0 && space < ranges.first.$1) from = space + 1;
  return '…${line.substring(from)}';
}

/// One item, card or workspace file that matches the query. Files linked
/// to an item or card are found through it; [file] hits are the others.
class SearchHit {
  final String tripId;
  final PlanItem? item;
  final NoteCard? card;
  final Attachment? file;

  /// The field shown under the title: the one with the most query words
  /// (the title itself when only the title matches).
  final SearchField field;

  /// Text of [field] (for [SearchField.title] the title), not shortened.
  final String text;

  /// Higher = better; title matches first.
  final int score;

  const SearchHit({
    required this.tripId,
    this.item,
    this.card,
    this.file,
    required this.field,
    required this.text,
    required this.score,
  });

  String get id => item?.id ?? card?.id ?? file!.id;

  /// The item's title, [cardTitle] or the file name; may be empty for an
  /// untitled card.
  String get title => item?.title ?? file?.fileName ?? cardTitle(card!);
}

/// The hits of one trip.
class TripHits {
  final Trip trip;

  /// The trip's own title matches, so the trip is a result by itself.
  final bool titleMatches;
  final List<SearchHit> hits;

  const TripHits(this.trip, this.titleMatches, this.hits);
}

/// What a card is called in a result list: its title, else the link's
/// page title or address, else the first line of its text or checklist.
String cardTitle(NoteCard c) {
  String firstLine(String s) => s.trim().split('\n').first.trim();
  if (c.title.trim().isNotEmpty) return c.title.trim();
  if ((c.previewTitle ?? '').trim().isNotEmpty) return c.previewTitle!.trim();
  if ((c.url ?? '').trim().isNotEmpty) return c.url!.trim();
  if (c.text.trim().isNotEmpty) return firstLine(c.text);
  for (final e in c.checklist) {
    if (e.text.trim().isNotEmpty) return e.text.trim();
  }
  return '';
}

List<(SearchField, String)> _itemFields(PlanItem i, List<Attachment> files) => [
      (SearchField.title, i.title),
      if (i.placeName != null) (SearchField.place, i.placeName!),
      (SearchField.notes, i.notes),
      for (final l in i.links) (SearchField.link, l),
      if (i.departureStation != null) (SearchField.departureStation, i.departureStation!),
      if (i.arrivalStation != null) (SearchField.arrivalStation, i.arrivalStation!),
      if (i.transportNumber != null) (SearchField.transportNumber, i.transportNumber!),
      if (i.seat != null) (SearchField.seat, i.seat!),
      if (i.bookingRef != null) (SearchField.bookingRef, i.bookingRef!),
      for (final f in files) (SearchField.attachment, f.fileName),
    ];

List<(SearchField, String)> _cardFields(NoteCard c, List<Attachment> files) => [
      (SearchField.title, cardTitle(c)),
      (SearchField.text, c.text),
      if (c.url != null) (SearchField.link, c.url!),
      if (c.previewTitle != null && c.title.trim().isNotEmpty) (SearchField.link, c.previewTitle!),
      for (final e in c.checklist) (SearchField.checklistEntry, e.text),
      for (final f in files) (SearchField.attachment, f.fileName),
    ];

/// Matches [fields] against [terms]: null unless every term occurs in some
/// field; otherwise the field to show and the score.
(SearchField, String, int)? _match(List<(SearchField, String)> fields, List<String> terms) {
  final folded = [for (final f in fields) foldForSearch(f.$2)];
  for (final t in terms) {
    if (!folded.any((f) => f.contains(t))) return null;
  }
  var best = -1;
  var bestCount = 0;
  for (var k = 0; k < fields.length; k++) {
    final count = terms.where(folded[k].contains).length;
    // Earlier fields win ties: the title comes first.
    if (count > bestCount) {
      best = k;
      bestCount = count;
    }
  }
  final title = folded.first;
  var score = 0;
  for (final t in terms) {
    if (title.contains(t)) {
      score += 2;
      if (title.startsWith(t) || title.contains(' $t')) score += 1;
    }
  }
  return (fields[best].$1, fields[best].$2, score);
}

/// Whether [c] matches all [terms] (see [searchTerms]); used by the notes
/// grid's own search box so it finds what the global search finds.
bool cardMatches(NoteCard c, List<String> terms, {List<Attachment> files = const []}) =>
    terms.isEmpty || _match(_cardFields(c, files), terms) != null;

/// Hits for [query] in one trip, best first: by score, then items before
/// cards, items in plan order (scheduled by start, then unscheduled).
List<SearchHit> searchTrip(TripData data, String query) {
  final terms = searchTerms(query);
  if (terms.isEmpty) return const [];
  final hits = <SearchHit>[];
  for (final i in data.items) {
    final m = _match(_itemFields(i, data.attachmentsOf(i.id)), terms);
    if (m != null) {
      hits.add(SearchHit(tripId: data.trip.id, item: i, field: m.$1, text: m.$2, score: m.$3));
    }
  }
  for (final c in data.cards) {
    final m = _match(_cardFields(c, data.attachmentsOf(c.id)), terms);
    if (m != null) {
      hits.add(SearchHit(tripId: data.trip.id, card: c, field: m.$1, text: m.$2, score: m.$3));
    }
  }
  for (final f in data.attachments) {
    if (f.ownerIds.any((o) => data.item(o) != null || data.card(o) != null)) continue;
    final m = _match([(SearchField.title, f.fileName), (SearchField.folder, f.folder)], terms);
    if (m != null) {
      hits.add(SearchHit(tripId: data.trip.id, file: f, field: m.$1, text: m.$2, score: m.$3));
    }
  }
  int order(SearchHit h) => h.item != null ? (h.item!.isScheduled ? 0 : 1) : (h.card != null ? 2 : 3);
  // List.sort is not stable: ties fall back to the stored order.
  final seq = {for (final (k, h) in hits.indexed) h: k};
  hits.sort((a, b) {
    final s = b.score.compareTo(a.score);
    if (s != 0) return s;
    final o = order(a).compareTo(order(b));
    if (o != 0) return o;
    if (a.item != null && b.item != null && a.item!.isScheduled && b.item!.isScheduled) {
      final t = a.item!.start!.compareTo(b.item!.start!);
      if (t != 0) return t;
    }
    return seq[a]!.compareTo(seq[b]!);
  });
  return hits;
}

/// Hits for [query] grouped by trip, in the order of [trips] with
/// [firstTripId] (the open trip) moved to the front. Trips without hits
/// are left out unless their title matches.
List<TripHits> searchTrips(Iterable<TripData> trips, String query, {String? firstTripId}) {
  final terms = searchTerms(query);
  if (terms.isEmpty) return const [];
  final result = <TripHits>[];
  for (final d in trips) {
    final title = foldForSearch(d.trip.title);
    final titleMatches = terms.every(title.contains);
    final hits = searchTrip(d, query);
    if (titleMatches || hits.isNotEmpty) result.add(TripHits(d.trip, titleMatches, hits));
  }
  final first = result.indexWhere((t) => t.trip.id == firstTripId);
  if (first > 0) result.insert(0, result.removeAt(first));
  return result;
}
