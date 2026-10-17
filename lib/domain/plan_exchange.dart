// Plan exchange format ("tripboard-plan"): a compact JSON view of a trip that
// people and AI assistants can read and write. Workflow: export the trip,
// let an assistant (e.g. the Claude app) research and edit it, import the
// result. The full spec lives in assets/plan_format.md.
//
// Items and notes are addressed by `ref`. Exported refs are the app ids, so
// an edited plan updates the existing entries; any other ref creates a new
// entry. Nothing is deleted unless it is listed in `remove`.

import 'dart:convert';

import 'models.dart';
import 'time.dart';

const planFormat = 'tripboard-plan';
const planFormatVersion = 1;

/// Why a text could not be read as a plan.
enum PlanErrorType {
  /// No JSON could be decoded at all; [PlanFormatException.detail] has the
  /// decoder's message.
  invalidJson,

  /// The JSON is not an object.
  notAnObject,

  /// `format` names another format ([PlanFormatException.detail]).
  unknownFormat,

  /// Neither `format`, `items` nor `trip`.
  notAPlan,

  /// `version` ([PlanFormatException.detail]) is newer than [planFormatVersion].
  tooNew,
}

/// A text that is not a usable plan. Implements [FormatException] so callers
/// can keep catching that; the UI words it from [type] and [detail].
class PlanFormatException implements FormatException {
  final PlanErrorType type;
  final String? detail;
  const PlanFormatException(this.type, [this.detail]);

  @override
  String get message => detail == null ? type.name : '${type.name}: $detail';
  @override
  dynamic get source => null;
  @override
  int? get offset => null;
  @override
  String toString() => 'PlanFormatException($message)';
}

/// What a [PlanWarning] is about. The entry is named by [PlanWarning.entry],
/// the offending field and value by [PlanWarning.field] / [PlanWarning.value].
enum PlanWarningType {
  /// `remove` names an unknown ref (value).
  removeUnknown,

  /// A ref (value) is used more than once; only the first entry counts.
  duplicateRef,

  /// A link field (field) points at an unknown ref (value); link removed.
  refNotFound,

  /// Unknown `kind` (value); entry skipped.
  unknownKind,

  /// New entry without `kind`; skipped.
  missingKind,

  /// New entry without a title; skipped. [PlanWarning.entry] is its ref.
  missingTitle,

  /// Unknown `status` (value); ignored.
  unknownStatus,

  /// Unknown transport `mode` (value); "other" is used.
  unknownMode,

  /// A link field (field) points at the entry itself; removed.
  selfReference,

  /// Only `start` or only `end`; the entry stays unscheduled.
  startOrEndOnly,

  /// `end` before `start`; times not taken over.
  endBeforeStart,

  /// Unsupported note `type` (value); note skipped.
  unsupportedNoteType,

  /// Image notes can't change their type; type ignored.
  imageTypeFixed,

  /// New note without content; skipped. [PlanWarning.entry] is its ref.
  emptyNote,

  /// A trip field (field) is not a whole number (value); ignored.
  notAnInteger,

  /// `trip.startDate` (value) is not a YYYY-MM-DD date; ignored.
  invalidStartDate,

  /// A moment field (field) uses a date but the trip has no start date.
  dateNeedsStartDate,

  /// A moment field (field) can't be read (value, as JSON); ignored.
  invalidMoment,
}

/// A problem with one part of a plan that did not stop the import.
class PlanWarning {
  final PlanWarningType type;

  /// Title or ref of the entry concerned ('?' / '–' if it has neither); null
  /// for warnings about the trip or the remove list.
  final String? entry;
  final String? field;
  final String? value;
  const PlanWarning(this.type, {this.entry, this.field, this.value});

  @override
  String toString() => 'PlanWarning(${type.name}, entry: $entry, field: $field, value: $value)';
}

/// A parsed, not yet applied plan document.
class PlanDoc {
  final Map<String, Object?> trip;
  final List<Map<String, Object?>> items;
  final List<Map<String, Object?>> notes;
  final List<String> remove;

  const PlanDoc({
    this.trip = const {},
    this.items = const [],
    this.notes = const [],
    this.remove = const [],
  });

  /// Trip id the plan was exported from, if any.
  String? get tripId => trip['id'] as String?;
}

/// The changes a plan makes to a trip, ready to be written.
class PlanImport {
  final Trip trip;
  final bool isNewTrip;

  /// New and changed items / notes (unchanged ones are left out).
  final List<PlanItem> items;
  final List<NoteCard> cards;
  final List<String> removeItemIds;
  final List<String> removeCardIds;
  final int itemsCreated;
  final int itemsUpdated;
  final int notesCreated;
  final int notesUpdated;
  final bool tripChanged;
  final List<PlanWarning> warnings;

  const PlanImport({
    required this.trip,
    required this.isNewTrip,
    required this.items,
    required this.cards,
    required this.removeItemIds,
    required this.removeCardIds,
    required this.itemsCreated,
    required this.itemsUpdated,
    required this.notesCreated,
    required this.notesUpdated,
    required this.tripChanged,
    required this.warnings,
  });

  bool get isEmpty =>
      items.isEmpty && cards.isEmpty && removeItemIds.isEmpty && removeCardIds.isEmpty && !tripChanged;
}

class PlanExchange {
  // --- export ----------------------------------------------------------------

  static Map<String, Object?> export(TripData d) {
    final items = [...d.items]..sort(_exportOrder);
    return {
      'format': planFormat,
      'version': planFormatVersion,
      'trip': {
        'id': d.trip.id,
        'title': d.trip.title,
        if (d.trip.startDate != null) 'startDate': _date(d.trip.startDate!),
        if (d.trip.plannedDays != null) 'days': d.trip.plannedDays,
      },
      'items': [for (final i in items) _exportItem(i)],
      'notes': [
        for (final c in d.cards)
          if (c.type != CardType.image) _exportCard(c),
      ],
    };
  }

  static String exportText(TripData d) => const JsonEncoder.withIndent('  ').convert(export(d));

  /// Scheduled items chronologically, then unscheduled ones; layer breaks ties.
  static int _exportOrder(PlanItem a, PlanItem b) {
    if (a.start != null && b.start != null && a.start != b.start) return a.start!.compareTo(b.start!);
    if ((a.start == null) != (b.start == null)) return a.start == null ? 1 : -1;
    return a.kind.layer.compareTo(b.kind.layer);
  }

  static Map<String, Object?> _exportItem(PlanItem i) => {
        'ref': i.id,
        'kind': i.kind.name,
        'title': i.title,
        if (i.placeName != null) 'place': i.placeName,
        if (i.lat != null) 'lat': i.lat,
        if (i.lng != null) 'lng': i.lng,
        'status': i.status.name,
        if (i.fixed) 'fixed': true,
        if (i.start != null) 'start': _moment(i.start!),
        if (i.end != null) 'end': _moment(i.end!),
        if (i.parentId != null) 'stay': i.parentId,
        if (i.fromId != null) 'from': i.fromId,
        if (i.toId != null) 'to': i.toId,
        if (i.mode != null) 'mode': i.mode!.name,
        if (i.departureStation != null) 'departure': i.departureStation,
        if (i.arrivalStation != null) 'arrival': i.arrivalStation,
        if (i.transportNumber != null) 'number': i.transportNumber,
        if (i.seat != null) 'seat': i.seat,
        if (i.bookingRef != null) 'bookingRef': i.bookingRef,
        if (i.notes.isNotEmpty) 'notes': i.notes,
        if (i.links.isNotEmpty) 'links': i.links,
      };

  static Map<String, Object?> _exportCard(NoteCard c) => {
        'ref': c.id,
        'type': c.type.name,
        if (c.title.isNotEmpty) 'title': c.title,
        if (c.text.isNotEmpty) 'text': c.text,
        if (c.type == CardType.checklist)
          'checklist': [
            for (final e in c.checklist) {'text': e.text, if (e.done) 'done': true},
          ],
        if (c.url != null) 'url': c.url,
        if (c.pinned) 'pinned': true,
        if (c.itemId != null) 'item': c.itemId,
      };

  static Map<String, Object?> _moment(int minute) => {'day': dayOf(minute) + 1, 'time': formatClock(minute)};

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // --- parse -----------------------------------------------------------------

  /// True if [text] looks like a plan document (cheap check for shared text).
  static bool looksLikePlan(String text) => text.contains(planFormat);

  /// Parses a plan from [text]. The JSON may be wrapped in a Markdown code
  /// block or surrounded by prose, as chat apps tend to copy it.
  static PlanDoc parse(String text) {
    final json = _extractJson(text);
    if (json is! Map) throw const PlanFormatException(PlanErrorType.notAnObject);
    final j = json.cast<String, Object?>();
    final format = j['format'];
    if (format != null && format != planFormat) {
      throw PlanFormatException(PlanErrorType.unknownFormat, '$format');
    }
    if (format == null && j['items'] == null && j['trip'] == null) {
      throw const PlanFormatException(PlanErrorType.notAPlan);
    }
    final version = j['version'];
    if (version is num && version > planFormatVersion) {
      throw PlanFormatException(PlanErrorType.tooNew, '$version');
    }
    List<Map<String, Object?>> objects(String key) => [
          for (final e in (j[key] as List? ?? const []))
            if (e is Map) e.cast<String, Object?>(),
        ];
    return PlanDoc(
      trip: (j['trip'] as Map?)?.cast<String, Object?>() ?? const {},
      items: objects('items'),
      notes: objects('notes'),
      remove: [for (final r in (j['remove'] as List? ?? const [])) if (r is String) r],
    );
  }

  static Object? _extractJson(String text) {
    final t = text.trim();
    final candidates = <String>[t];
    for (final m in RegExp(r'```(?:json)?\s*\n([\s\S]*?)```').allMatches(t)) {
      candidates.add(m.group(1)!.trim());
    }
    final a = t.indexOf('{'), b = t.lastIndexOf('}');
    if (a >= 0 && b > a) candidates.add(t.substring(a, b + 1));
    FormatException? error;
    for (final c in candidates) {
      try {
        return jsonDecode(c);
      } on FormatException catch (e) {
        error ??= e;
      }
    }
    throw PlanFormatException(PlanErrorType.invalidJson, error?.message);
  }

  // --- apply -----------------------------------------------------------------

  /// Computes what importing [doc] does: into the existing trip [into], or as
  /// a new trip when [into] is null. Pure; nothing is written. A new trip
  /// without a title is called [newTripTitle].
  static PlanImport apply(
    PlanDoc doc, {
    TripData? into,
    required DateTime now,
    required String Function() newId,
    String newTripTitle = 'Imported trip',
  }) {
    final warnings = <PlanWarning>[];
    final t = doc.trip;

    // Trip.
    final Trip trip;
    var tripChanged = false;
    final startDate = t.containsKey('startDate') ? _parseDate(t['startDate'], warnings) : null;
    final days = t.containsKey('days') ? _parseInt(t['days'], 'days', warnings) : null;
    if (into == null) {
      final title = (t['title'] as String?)?.trim();
      trip = Trip(
        id: newId(),
        title: title == null || title.isEmpty ? newTripTitle : title,
        startDate: startDate?.value,
        plannedDays: days?.value,
        createdAt: now,
      );
    } else {
      var tr = into.trip;
      final title = (t['title'] as String?)?.trim();
      if (title != null && title.isNotEmpty) tr = tr.copyWith(title: title);
      if (startDate != null) tr = tr.copyWith(startDate: startDate.value);
      if (days != null) tr = tr.copyWith(plannedDays: days.value);
      tripChanged = jsonEncode(tr.toJson()) != jsonEncode(into.trip.toJson());
      trip = tr;
    }

    final oldItems = {for (final i in into?.items ?? const <PlanItem>[]) i.id: i};
    final oldCards = {for (final c in into?.cards ?? const <NoteCard>[]) c.id: c};

    // Removals.
    final removeItems = <String>{}, removeCards = <String>{};
    for (final r in doc.remove) {
      if (oldItems.containsKey(r)) {
        removeItems.add(r);
      } else if (oldCards.containsKey(r)) {
        removeCards.add(r);
      } else {
        warnings.add(PlanWarning(PlanWarningType.removeUnknown, value: r));
      }
    }

    // Ref → id for everything in the document, so entries can point at each
    // other regardless of order.
    final ids = <String, String>{};
    final itemEntries = <(String, Map<String, Object?>)>[];
    final cardEntries = <(String, Map<String, Object?>)>[];
    void register(Map<String, Object?> e, bool isItem) {
      final rawRef = e['ref'];
      final ref = rawRef is String && rawRef.isNotEmpty ? rawRef : null;
      if (ref != null && ids.containsKey(ref)) {
        warnings.add(PlanWarning(PlanWarningType.duplicateRef, value: ref));
        return;
      }
      final known = isItem ? oldItems.containsKey(ref) : oldCards.containsKey(ref);
      final id = known ? ref! : newId();
      if (ref != null) ids[ref] = id;
      (isItem ? itemEntries : cardEntries).add((id, e));
    }

    for (final e in doc.items) {
      register(e, true);
    }
    for (final e in doc.notes) {
      register(e, false);
    }

    String label(Map<String, Object?> e) => '${e['title'] ?? e['ref'] ?? '?'}';
    String refOf(Map<String, Object?> e) => '${e['ref'] ?? '–'}';
    void warn(PlanWarningType type, Map<String, Object?> e, {String? field, Object? value}) =>
        warnings.add(PlanWarning(type, entry: label(e), field: field, value: value == null ? null : '$value'));

    // Item references may point at document refs or at existing items.
    final docItemIds = {for (final (id, _) in itemEntries) id};
    String? resolveItem(Object? ref, String field, Map<String, Object?> e) {
      if (ref == null) return null;
      final id = ids[ref] ?? (ref is String && oldItems.containsKey(ref) ? ref : null);
      if (id == null || !(docItemIds.contains(id) || oldItems.containsKey(id))) {
        warn(PlanWarningType.refNotFound, e, field: field, value: ref);
        return null;
      }
      if (removeItems.contains(id)) return null;
      return id;
    }

    // Items.
    final outItems = <PlanItem>[];
    var created = 0, updated = 0, n = 0;
    for (final (id, e) in itemEntries) {
      if (removeItems.contains(id)) continue;
      final old = oldItems[id];
      bool has(String k) => e.containsKey(k);

      ItemKind? kind = old?.kind;
      if (has('kind')) {
        kind = _byName(ItemKind.values, e['kind']);
        if (kind == null) {
          warn(PlanWarningType.unknownKind, e, value: e['kind']);
          continue;
        }
      }
      if (kind == null) {
        warn(PlanWarningType.missingKind, e);
        continue;
      }
      final title = (e['title'] as String?)?.trim();
      if (old == null && (title == null || title.isEmpty)) {
        warnings.add(PlanWarning(PlanWarningType.missingTitle, entry: refOf(e)));
        continue;
      }

      var item = old ??
          PlanItem(
            id: id,
            tripId: trip.id,
            kind: kind,
            title: title!,
            createdAt: now.add(Duration(milliseconds: n++)),
          );
      item = item.copyWith(kind: kind);
      if (title != null && title.isNotEmpty) item = item.copyWith(title: title);
      if (has('place')) item = item.copyWith(placeName: _str(e['place']));
      if (has('lat')) item = item.copyWith(lat: (e['lat'] as num?)?.toDouble());
      if (has('lng')) item = item.copyWith(lng: (e['lng'] as num?)?.toDouble());
      if (has('status')) {
        final s = _byName(ItemStatus.values, e['status']);
        if (s == null) {
          warn(PlanWarningType.unknownStatus, e, value: e['status']);
        } else {
          item = item.copyWith(status: s);
        }
      }
      if (has('fixed')) item = item.copyWith(fixed: e['fixed'] == true);
      if (has('notes')) item = item.copyWith(notes: _str(e['notes']) ?? '');
      if (has('links')) {
        item = item.copyWith(links: [for (final l in (e['links'] as List? ?? const [])) if (l is String) l]);
      }
      if (has('mode')) {
        final m = e['mode'] == null ? null : _byName(TransportMode.values, e['mode']);
        if (e['mode'] != null && m == null) {
          warn(PlanWarningType.unknownMode, e, value: e['mode']);
        }
        item = item.copyWith(mode: e['mode'] == null ? null : (m ?? TransportMode.other));
      }
      // Ticket details: blank text clears like null.
      if (has('departure')) item = item.copyWith(departureStation: _text(e['departure']));
      if (has('arrival')) item = item.copyWith(arrivalStation: _text(e['arrival']));
      if (has('number')) item = item.copyWith(transportNumber: _text(e['number']));
      if (has('seat')) item = item.copyWith(seat: _text(e['seat']));
      if (has('bookingRef')) item = item.copyWith(bookingRef: _text(e['bookingRef']));
      if (has('stay')) item = item.copyWith(parentId: resolveItem(e['stay'], 'stay', e));
      if (has('from')) item = item.copyWith(fromId: resolveItem(e['from'], 'from', e));
      if (has('to')) item = item.copyWith(toId: resolveItem(e['to'], 'to', e));
      for (final (field, value) in [('stay', item.parentId), ('from', item.fromId), ('to', item.toId)]) {
        if (value == id) {
          warn(PlanWarningType.selfReference, e, field: field);
          item = switch (field) {
            'stay' => item.copyWith(parentId: null),
            'from' => item.copyWith(fromId: null),
            _ => item.copyWith(toId: null),
          };
        }
      }
      // Links to removed items go away too.
      if (removeItems.contains(item.parentId)) item = item.copyWith(parentId: null);
      if (removeItems.contains(item.fromId)) item = item.copyWith(fromId: null);
      if (removeItems.contains(item.toId)) item = item.copyWith(toId: null);
      if (item.kind == ItemKind.transport && item.mode == null) {
        item = item.copyWith(mode: TransportMode.other);
      }

      if (has('start') || has('end')) {
        int? start = item.start, end = item.end;
        var ok = true;
        if (has('start')) {
          final r = _parseMoment(e['start'], trip.startDate, label(e), 'start', warnings);
          ok &= r != null;
          if (r != null) start = r.value;
        }
        if (has('end')) {
          final r = _parseMoment(e['end'], trip.startDate, label(e), 'end', warnings);
          ok &= r != null;
          if (r != null) end = r.value;
        }
        if (ok && (start == null) != (end == null)) {
          warn(PlanWarningType.startOrEndOnly, e);
          start = end = null;
        }
        if (ok && start != null && end! < start) {
          warn(PlanWarningType.endBeforeStart, e);
          ok = false;
        }
        if (ok) item = item.copyWith(start: start, end: end);
      }

      if (old == null) {
        created++;
        outItems.add(item);
      } else if (jsonEncode(item.toJson()) != jsonEncode(old.toJson())) {
        updated++;
        outItems.add(item);
      }
    }

    // Notes.
    final outCards = <NoteCard>[];
    var cCreated = 0, cUpdated = 0;
    for (final (id, e) in cardEntries) {
      if (removeCards.contains(id)) continue;
      final old = oldCards[id];
      bool has(String k) => e.containsKey(k);

      var type = old?.type;
      if (has('type')) {
        final t = _byName(CardType.values, e['type']);
        if (t == null || t == CardType.image) {
          warn(PlanWarningType.unsupportedNoteType, e, value: e['type']);
          continue;
        }
        if (old?.type == CardType.image) {
          warn(PlanWarningType.imageTypeFixed, e);
        } else {
          type = t;
        }
      }
      type ??= has('checklist')
          ? CardType.checklist
          : has('url')
              ? CardType.link
              : CardType.note;

      var card = old ?? NoteCard(id: id, tripId: trip.id, type: type, createdAt: now.add(Duration(milliseconds: n++)));
      card = card.copyWith(type: type);
      if (has('title')) card = card.copyWith(title: _str(e['title']) ?? '');
      if (has('text')) card = card.copyWith(text: _str(e['text']) ?? '');
      if (has('url')) card = card.copyWith(url: _str(e['url']));
      if (has('pinned')) card = card.copyWith(pinned: e['pinned'] == true);
      if (has('checklist')) {
        card = card.copyWith(checklist: [
          for (final c in (e['checklist'] as List? ?? const []))
            if (c is String)
              ChecklistEntry(id: newId(), text: c)
            else if (c is Map)
              ChecklistEntry(id: newId(), text: '${c['text'] ?? ''}', done: c['done'] == true),
        ]);
      }
      if (has('item')) card = card.copyWith(itemId: resolveItem(e['item'], 'item', e));
      if (removeItems.contains(card.itemId)) card = card.copyWith(itemId: null);
      if (old == null && card.title.isEmpty && card.text.isEmpty && card.checklist.isEmpty && card.url == null) {
        warnings.add(PlanWarning(PlanWarningType.emptyNote, entry: refOf(e)));
        continue;
      }

      if (old == null) {
        cCreated++;
        outCards.add(card);
      } else if (jsonEncode(_cardCompare(card)) != jsonEncode(_cardCompare(old))) {
        cUpdated++;
        outCards.add(card);
      }
    }

    return PlanImport(
      trip: trip,
      isNewTrip: into == null,
      items: outItems,
      cards: outCards,
      removeItemIds: removeItems.toList(),
      removeCardIds: removeCards.toList(),
      itemsCreated: created,
      itemsUpdated: updated,
      notesCreated: cCreated,
      notesUpdated: cUpdated,
      tripChanged: tripChanged,
      warnings: warnings,
    );
  }

  /// Card JSON without checklist entry ids (those are regenerated on import).
  static Map<String, Object?> _cardCompare(NoteCard c) => {
        ...c.toJson(),
        'checklist': [for (final e in c.checklist) [e.text, e.done]],
      };

  static T? _byName<T extends Enum>(List<T> values, Object? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  static String? _str(Object? v) => v == null ? null : '$v';

  /// [_str] trimmed, with blank text read as null.
  static String? _text(Object? v) {
    final t = _str(v)?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  static ({int? value})? _parseInt(Object? v, String field, List<PlanWarning> warnings) {
    if (v == null) return (value: null);
    if (v is num && v == v.roundToDouble()) return (value: v.toInt());
    warnings.add(PlanWarning(PlanWarningType.notAnInteger, field: field, value: '$v'));
    return null;
  }

  static final _dateRe = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
  static final _timeRe = RegExp(r'^(\d{1,2}):(\d{2})$');
  static final _dateTimeRe = RegExp(r'^(\d{4}-\d{2}-\d{2})[T ](\d{1,2}:\d{2})(?::\d{2})?$');

  static DateTime? _toDate(String s) {
    final m = _dateRe.firstMatch(s);
    if (m == null) return null;
    final d = DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    return d.month == int.parse(m[2]!) && d.day == int.parse(m[3]!) ? d : null;
  }

  static ({DateTime? value})? _parseDate(Object? v, List<PlanWarning> warnings) {
    if (v == null) return (value: null);
    final d = v is String ? _toDate(v.trim()) : null;
    if (d == null) {
      warnings.add(PlanWarning(PlanWarningType.invalidStartDate, field: 'startDate', value: '$v'));
      return null;
    }
    return (value: d);
  }

  static int? _toClock(String s) {
    final m = _timeRe.firstMatch(s.trim());
    if (m == null) return null;
    final h = int.parse(m[1]!), min = int.parse(m[2]!);
    if (min > 59 || h > 24 || (h == 24 && min > 0)) return null;
    return h * 60 + min;
  }

  /// Accepts {"day": 3, "time": "14:00"}, {"date": "2027-03-05", "time":
  /// "14:00"} or "2027-03-05T14:00". Dates need the trip's start date.
  static ({int? value})? _parseMoment(
      Object? v, DateTime? tripStart, String entry, String field, List<PlanWarning> warnings) {
    if (v == null) return (value: null);
    int? dayIndex;
    int? clock;
    String? date;
    if (v is Map) {
      final day = v['day'];
      if (day is num && day == day.roundToDouble()) dayIndex = day.toInt() - 1;
      if (v['date'] is String) date = (v['date'] as String).trim();
      clock = v['time'] is String ? _toClock(v['time'] as String) : null;
    } else if (v is String) {
      final m = _dateTimeRe.firstMatch(v.trim());
      if (m != null) {
        date = m[1];
        clock = _toClock(m[2]!);
      }
    }
    if (dayIndex == null && date != null) {
      final d = _toDate(date);
      if (d != null && tripStart != null) {
        final s = DateTime.utc(tripStart.year, tripStart.month, tripStart.day);
        dayIndex = DateTime.utc(d.year, d.month, d.day).difference(s).inDays;
      } else if (d != null) {
        warnings.add(PlanWarning(PlanWarningType.dateNeedsStartDate, entry: entry, field: field));
        return null;
      }
    }
    if (dayIndex == null || clock == null) {
      warnings.add(PlanWarning(PlanWarningType.invalidMoment, entry: entry, field: field, value: jsonEncode(v)));
      return null;
    }
    return (value: at(dayIndex, clock));
  }
}
