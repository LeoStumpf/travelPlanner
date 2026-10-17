// Plan exchange format ("tripboard-plan"): a compact JSON view of a trip that
// people and AI assistants can read and write. Workflow: export the trip,
// let an assistant (e.g. the Claude app) research and edit it, import the
// result. The full spec lives in assets/plan_format.md.
//
// Items and notes are addressed by `ref`. Exported refs are the app ids, so
// an edited plan updates the existing entries; any other ref creates a new
// entry. Nothing is deleted unless it is listed in `remove`.

import 'dart:convert';

import 'budget.dart';
import 'models.dart';
import 'time.dart';
import 'zones.dart';

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

  /// A time zone field (field) names no known IANA zone (value); ignored.
  unknownTimeZone,

  /// A `cost` (value, as JSON) has no usable amount; ignored.
  invalidCost,

  /// A currency field (field) is not a three-letter code (value); ignored.
  /// [PlanWarning.entry] is null for the trip's currency or rates.
  unknownCurrency,

  /// An exchange rate (field = currency) is not a positive number (value).
  invalidRate,
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

/// What happens to an entry in a [PlanChange].
enum PlanChangeType { created, updated, removed }

/// Groups of fields a plan changes, for the import preview. Item and note
/// fields share the group where they mean the same; the trip has its own.
enum PlanField {
  title,
  kind,
  place,
  status,
  fixed,
  time,
  notes,
  links,

  /// stay / from / to of an item, the linked item of a note.
  relation,
  mode,

  /// Stations, number, seat, booking reference.
  ticket,
  zone,
  cost,
  text,
  url,
  pinned,
  checklist,

  /// Trip start date and length.
  dates,
  currency,
  travellers,
  rates,
}

/// One entry a plan creates, changes or deletes, named by its title as it
/// will be (or was, for a removal).
class PlanChange {
  final PlanChangeType type;
  final String id;
  final String title;

  /// Null for a note.
  final ItemKind? kind;
  bool get isNote => kind == null;

  /// What changes; empty unless [type] is [PlanChangeType.updated].
  final Set<PlanField> fields;

  const PlanChange(this.type, this.id, this.title, {this.kind, this.fields = const {}});

  @override
  String toString() => 'PlanChange(${type.name}, $title, ${fields.map((f) => f.name).join(',')})';
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
        if (d.trip.homeZone != null) 'tz': d.trip.homeZone,
        if (d.trip.currency != null) 'currency': d.trip.currency,
        if (d.trip.travellers != 1) 'travellers': d.trip.travellers,
        if (d.trip.rates.isNotEmpty) 'rates': d.trip.rates,
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
        if (i.tz != null && _zoned(i.kind)) 'tz': i.tz,
        if (i.endTz != null && i.kind == ItemKind.transport) 'endTz': i.endTz,
        if (i.cost != null) 'cost': i.cost!.toJson(),
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

  /// Kinds whose own `tz` means something (see zones.dart).
  static bool _zoned(ItemKind k) => k == ItemKind.stay || k == ItemKind.transport;

  static Map<String, Object?> _moment(int minute) => {'day': dayOf(minute) + 1, 'time': formatClock(minute)};

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // --- preview ---------------------------------------------------------------

  /// The trip fields that differ between [old] and [trip].
  static Set<PlanField> tripChanges(Trip old, Trip trip) => {
        if (trip.title != old.title) PlanField.title,
        if (trip.startDate != old.startDate || trip.plannedDays != old.plannedDays) PlanField.dates,
        if (trip.homeZone != old.homeZone) PlanField.zone,
        if (trip.currency != old.currency) PlanField.currency,
        if (trip.travellers != old.travellers) PlanField.travellers,
        if (jsonEncode(trip.rates) != jsonEncode(old.rates)) PlanField.rates,
      };

  /// Every entry [imp] creates, changes or deletes in [into] (null for a new
  /// trip): new ones first, then changed ones with their fields, then
  /// deletions; items before notes within each group.
  static List<PlanChange> changes(PlanImport imp, TripData? into) {
    final oldItems = {for (final i in into?.items ?? const <PlanItem>[]) i.id: i};
    final oldCards = {for (final c in into?.cards ?? const <NoteCard>[]) c.id: c};
    final created = <PlanChange>[], updated = <PlanChange>[], removed = <PlanChange>[];
    for (final i in imp.items) {
      final old = oldItems[i.id];
      if (old == null) {
        created.add(PlanChange(PlanChangeType.created, i.id, i.title, kind: i.kind));
      } else {
        updated.add(PlanChange(PlanChangeType.updated, i.id, i.title,
            kind: i.kind, fields: _diff(old.toJson(), i.toJson(), _itemFields)));
      }
    }
    for (final c in imp.cards) {
      final old = oldCards[c.id];
      if (old == null) {
        created.add(PlanChange(PlanChangeType.created, c.id, _cardTitle(c)));
      } else {
        updated.add(PlanChange(PlanChangeType.updated, c.id, _cardTitle(c),
            fields: _diff(_cardCompare(old), _cardCompare(c), _cardFields)));
      }
    }
    for (final id in imp.removeItemIds) {
      final old = oldItems[id];
      if (old != null) removed.add(PlanChange(PlanChangeType.removed, id, old.title, kind: old.kind));
    }
    for (final id in imp.removeCardIds) {
      final old = oldCards[id];
      if (old != null) removed.add(PlanChange(PlanChangeType.removed, id, _cardTitle(old)));
    }
    return [...created, ...updated, ...removed];
  }

  /// The trip's items once [imp] is written into [into]: removed items gone
  /// (and unlinked), new and changed ones in place. Used to judge the plan
  /// (e.g. conflicts) before it is applied.
  static List<PlanItem> itemsAfter(PlanImport imp, TripData? into) {
    final removed = imp.removeItemIds.toSet();
    final byId = {
      for (final i in into?.items ?? const <PlanItem>[])
        if (!removed.contains(i.id)) i.id: i,
      for (final i in imp.items) i.id: i,
    };
    return [
      for (final i in byId.values)
        i.copyWith(
          parentId: removed.contains(i.parentId) ? null : i.parentId,
          fromId: removed.contains(i.fromId) ? null : i.fromId,
          toId: removed.contains(i.toId) ? null : i.toId,
        ),
    ];
  }

  /// A note without a title is named by the start of its text, its link or
  /// its first checklist entry.
  static String _cardTitle(NoteCard c) {
    for (final s in [c.title, c.text, c.url ?? '', c.checklist.firstOrNull?.text ?? '']) {
      final line = s.trim().split('\n').first.trim();
      if (line.isNotEmpty) return line.length > 60 ? '${line.substring(0, 59)}…' : line;
    }
    return '';
  }

  static const _itemFields = {
    'title': PlanField.title,
    'kind': PlanField.kind,
    'placeName': PlanField.place,
    'lat': PlanField.place,
    'lng': PlanField.place,
    'status': PlanField.status,
    'fixed': PlanField.fixed,
    'start': PlanField.time,
    'end': PlanField.time,
    'notes': PlanField.notes,
    'links': PlanField.links,
    'parentId': PlanField.relation,
    'fromId': PlanField.relation,
    'toId': PlanField.relation,
    'mode': PlanField.mode,
    'departureStation': PlanField.ticket,
    'arrivalStation': PlanField.ticket,
    'transportNumber': PlanField.ticket,
    'seat': PlanField.ticket,
    'bookingRef': PlanField.ticket,
    'tz': PlanField.zone,
    'endTz': PlanField.zone,
    'cost': PlanField.cost,
  };

  static const _cardFields = {
    'type': PlanField.kind,
    'title': PlanField.title,
    'text': PlanField.text,
    'url': PlanField.url,
    'pinned': PlanField.pinned,
    'checklist': PlanField.checklist,
    'itemId': PlanField.relation,
  };

  /// The field groups whose JSON differs between [a] and [b], in enum order.
  static Set<PlanField> _diff(Map<String, Object?> a, Map<String, Object?> b, Map<String, PlanField> fields) {
    final out = <PlanField>{};
    for (final e in fields.entries) {
      if (jsonEncode(a[e.key]) != jsonEncode(b[e.key])) out.add(e.value);
    }
    return (out.toList()..sort((x, y) => x.index.compareTo(y.index))).toSet();
  }

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
    final homeZone = t.containsKey('tz') ? _parseZone(t['tz'], 'tz', null, warnings) : null;
    final currency = t.containsKey('currency') ? _parseCurrency(t['currency'], 'currency', null, warnings) : null;
    final travellers = t.containsKey('travellers') ? _parseInt(t['travellers'], 'travellers', warnings) : null;
    final travellerCount = travellers == null ? null : (travellers.value ?? 1).clamp(1, 99);
    if (into == null) {
      final title = (t['title'] as String?)?.trim();
      trip = Trip(
        id: newId(),
        title: title == null || title.isEmpty ? newTripTitle : title,
        startDate: startDate?.value,
        plannedDays: days?.value,
        homeZone: homeZone?.value,
        currency: currency?.value,
        travellers: travellerCount ?? 1,
        rates: _applyRates(const {}, t['rates'], warnings),
        createdAt: now,
      );
    } else {
      var tr = into.trip;
      final title = (t['title'] as String?)?.trim();
      if (title != null && title.isNotEmpty) tr = tr.copyWith(title: title);
      if (startDate != null) tr = tr.copyWith(startDate: startDate.value);
      if (days != null) tr = tr.copyWith(plannedDays: days.value);
      if (homeZone != null) tr = tr.copyWith(homeZone: homeZone.value);
      if (currency != null) tr = setHomeCurrency(tr, currency.value);
      if (travellerCount != null) tr = tr.copyWith(travellers: travellerCount);
      if (t.containsKey('rates')) tr = tr.copyWith(rates: _applyRates(tr.rates, t['rates'], warnings));
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
    final timeChecks = <(String, Map<String, Object?>, int?, int?)>[];
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
      if (has('tz')) {
        final z = _parseZone(e['tz'], 'tz', label(e), warnings);
        if (z != null) item = item.copyWith(tz: z.value);
      }
      if (has('endTz')) {
        final z = _parseZone(e['endTz'], 'endTz', label(e), warnings);
        if (z != null) item = item.copyWith(endTz: z.value);
      }
      if (item.kind != ItemKind.stay && item.kind != ItemKind.transport) item = item.copyWith(tz: null);
      if (item.kind != ItemKind.transport) item = item.copyWith(endTz: null);
      if (has('cost')) {
        final c = _parseCost(e['cost'], item.cost, label(e), warnings);
        if (c != null) item = item.copyWith(cost: c.value);
      }
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
        // A transport's end is in the arrival zone and may read earlier
        // than its start (westwards); it is checked on absolute time below.
        if (ok && start != null && end! < start && item.kind != ItemKind.transport) {
          warn(PlanWarningType.endBeforeStart, e);
          ok = false;
        }
        if (ok) {
          if (item.kind == ItemKind.transport && start != null) {
            timeChecks.add((id, e, item.start, item.end));
          }
          item = item.copyWith(start: start, end: end);
        }
      }

      if (old == null) {
        created++;
        outItems.add(item);
      } else if (jsonEncode(item.toJson()) != jsonEncode(old.toJson())) {
        updated++;
        outItems.add(item);
      }
    }

    // Transports whose end might lie before their start once zones are
    // applied: check them against the final plan, and keep the old times
    // (none for a new entry) when the arrival is before the departure.
    if (timeChecks.isNotEmpty) {
      final merged = {...oldItems, for (final i in outItems) i.id: i};
      merged.removeWhere((id, _) => removeItems.contains(id));
      final zones = TripZones.of(trip, merged.values);
      for (final (id, e, oldStart, oldEnd) in timeChecks) {
        final k = outItems.indexWhere((i) => i.id == id);
        if (k < 0) continue; // unchanged
        final item = outItems[k];
        if (zones.absEnd(item) >= zones.absStart(item)) continue;
        warn(PlanWarningType.endBeforeStart, e);
        final reverted = item.copyWith(start: oldStart, end: oldEnd);
        final old = oldItems[id];
        if (old != null && jsonEncode(reverted.toJson()) == jsonEncode(old.toJson())) {
          outItems.removeAt(k);
          updated--;
        } else {
          outItems[k] = reverted;
        }
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

  /// A currency field: a code (or symbol, see [normalizeCurrency]), or null
  /// / blank to clear it.
  static ({String? value})? _parseCurrency(Object? v, String field, String? entry, List<PlanWarning> warnings) {
    final t = _text(v);
    if (t == null) return (value: null);
    final c = normalizeCurrency(t);
    if (c != null) return (value: c);
    warnings.add(PlanWarning(PlanWarningType.unknownCurrency, entry: entry, field: field, value: t));
    return null;
  }

  /// `cost`: null clears it, a number is a total in the home currency, an
  /// object sets the fields it names on top of [old].
  static ({Cost? value})? _parseCost(Object? v, Cost? old, String entry, List<PlanWarning> warnings) {
    if (v == null) return (value: null);
    if (v is num && v >= 0) return (value: Cost(amount: v.toDouble()));
    if (v is Map) {
      final amount = v['amount'];
      if (amount is num && amount >= 0 || (!v.containsKey('amount') && old != null)) {
        var c = old ?? const Cost(amount: 0);
        if (amount is num) c = c.copyWith(amount: amount.toDouble());
        if (v.containsKey('currency')) {
          // An unknown currency would silently count the amount as home
          // currency (5000 "Rupees" as 5000 EUR), so the cost is skipped.
          final cur = _parseCurrency(v['currency'], 'cost.currency', entry, warnings);
          if (cur == null) return null;
          c = c.copyWith(currency: cur.value);
        }
        if (v.containsKey('perPerson')) c = c.copyWith(perPerson: v['perPerson'] == true);
        if (v.containsKey('paid')) c = c.copyWith(paid: v['paid'] == true);
        return (value: c);
      }
    }
    warnings.add(PlanWarning(PlanWarningType.invalidCost, entry: entry, field: 'cost', value: jsonEncode(v)));
    return null;
  }

  /// `trip.rates` merged into [old]: each code sets its rate, null removes it.
  static Map<String, double> _applyRates(Map<String, double> old, Object? v, List<PlanWarning> warnings) {
    if (v is! Map) return old;
    final out = {...old};
    for (final e in v.entries) {
      final code = normalizeCurrency('${e.key}');
      if (code == null) {
        warnings.add(PlanWarning(PlanWarningType.unknownCurrency, field: 'rates', value: '${e.key}'));
      } else if (e.value == null) {
        out.remove(code);
      } else if (e.value is num && (e.value as num) > 0) {
        out[code] = (e.value as num).toDouble();
      } else {
        warnings.add(PlanWarning(PlanWarningType.invalidRate, field: code, value: '${e.value}'));
      }
    }
    return out;
  }

  static ({int? value})? _parseInt(Object? v, String field, List<PlanWarning> warnings) {
    if (v == null) return (value: null);
    if (v is num && v == v.roundToDouble()) return (value: v.toInt());
    warnings.add(PlanWarning(PlanWarningType.notAnInteger, field: field, value: '$v'));
    return null;
  }

  /// A zone field: an IANA name, or null / blank to clear it.
  static ({String? value})? _parseZone(Object? v, String field, String? entry, List<PlanWarning> warnings) {
    final name = _text(v);
    if (name == null) return (value: null);
    if (isKnownZone(name)) return (value: name);
    warnings.add(PlanWarning(PlanWarningType.unknownTimeZone, entry: entry, field: field, value: name));
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
