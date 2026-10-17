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
  final List<String> warnings;

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
    if (json is! Map) throw const FormatException('Kein Plan gefunden (JSON-Objekt erwartet)');
    final j = json.cast<String, Object?>();
    final format = j['format'];
    if (format != null && format != planFormat) {
      throw FormatException('Unbekanntes Format „$format“ (erwartet: $planFormat)');
    }
    if (format == null && j['items'] == null && j['trip'] == null) {
      throw const FormatException('Kein Tripboard-Plan: „items“ oder „trip“ fehlt');
    }
    final version = j['version'];
    if (version is num && version > planFormatVersion) {
      throw FormatException('Plan-Version $version ist neuer als diese App (kann $planFormatVersion)');
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
    throw FormatException('Kein gültiges JSON gefunden (${error?.message ?? 'leer'})');
  }

  // --- apply -----------------------------------------------------------------

  /// Computes what importing [doc] does: into the existing trip [into], or as
  /// a new trip when [into] is null. Pure; nothing is written.
  static PlanImport apply(
    PlanDoc doc, {
    TripData? into,
    required DateTime now,
    required String Function() newId,
  }) {
    final warnings = <String>[];
    final t = doc.trip;

    // Trip.
    final Trip trip;
    var tripChanged = false;
    final startDate = t.containsKey('startDate') ? _parseDate(t['startDate'], warnings) : null;
    final days = t.containsKey('days') ? _parseInt(t['days'], 'Reise: days', warnings) : null;
    if (into == null) {
      final title = (t['title'] as String?)?.trim();
      trip = Trip(
        id: newId(),
        title: title == null || title.isEmpty ? 'Importierte Reise' : title,
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
        warnings.add('remove: „$r“ gibt es nicht – ignoriert');
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
        warnings.add('ref „$ref“ kommt mehrfach vor – nur der erste Eintrag zählt');
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

    String label(Map<String, Object?> e) => '„${e['title'] ?? e['ref'] ?? '?'}“';

    // Item references may point at document refs or at existing items.
    final docItemIds = {for (final (id, _) in itemEntries) id};
    String? resolveItem(Object? ref, String field, Map<String, Object?> e) {
      if (ref == null) return null;
      final id = ids[ref] ?? (ref is String && oldItems.containsKey(ref) ? ref : null);
      if (id == null || !(docItemIds.contains(id) || oldItems.containsKey(id))) {
        warnings.add('${label(e)}: $field „$ref“ nicht gefunden – Verknüpfung entfernt');
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
          warnings.add('${label(e)}: unbekannte Art „${e['kind']}“ – übersprungen');
          continue;
        }
      }
      if (kind == null) {
        warnings.add('${label(e)}: „kind“ fehlt – übersprungen');
        continue;
      }
      final title = (e['title'] as String?)?.trim();
      if (old == null && (title == null || title.isEmpty)) {
        warnings.add('Eintrag ohne Titel (ref ${e['ref'] ?? '–'}) – übersprungen');
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
          warnings.add('${label(e)}: unbekannter Status „${e['status']}“ – ignoriert');
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
          warnings.add('${label(e)}: unbekanntes Verkehrsmittel „${e['mode']}“ – „other“');
        }
        item = item.copyWith(mode: e['mode'] == null ? null : (m ?? TransportMode.other));
      }
      if (has('stay')) item = item.copyWith(parentId: resolveItem(e['stay'], 'stay', e));
      if (has('from')) item = item.copyWith(fromId: resolveItem(e['from'], 'from', e));
      if (has('to')) item = item.copyWith(toId: resolveItem(e['to'], 'to', e));
      for (final (field, value) in [('stay', item.parentId), ('from', item.fromId), ('to', item.toId)]) {
        if (value == id) {
          warnings.add('${label(e)}: $field verweist auf sich selbst – entfernt');
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
          final r = _parseMoment(e['start'], trip.startDate, '${label(e)}: start', warnings);
          ok &= r != null;
          if (r != null) start = r.value;
        }
        if (has('end')) {
          final r = _parseMoment(e['end'], trip.startDate, '${label(e)}: end', warnings);
          ok &= r != null;
          if (r != null) end = r.value;
        }
        if (ok && (start == null) != (end == null)) {
          warnings.add('${label(e)}: nur start oder end angegeben – bleibt ungeplant');
          start = end = null;
        }
        if (ok && start != null && end! < start) {
          warnings.add('${label(e)}: end liegt vor start – Zeit nicht übernommen');
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
          warnings.add('${label(e)}: Notiztyp „${e['type']}“ wird nicht unterstützt – übersprungen');
          continue;
        }
        if (old?.type == CardType.image) {
          warnings.add('${label(e)}: Bild-Notizen können den Typ nicht wechseln – Typ ignoriert');
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
        warnings.add('Leere Notiz (ref ${e['ref'] ?? '–'}) – übersprungen');
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

  static ({int? value})? _parseInt(Object? v, String what, List<String> warnings) {
    if (v == null) return (value: null);
    if (v is num && v == v.roundToDouble()) return (value: v.toInt());
    warnings.add('$what: „$v“ ist keine ganze Zahl – ignoriert');
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

  static ({DateTime? value})? _parseDate(Object? v, List<String> warnings) {
    if (v == null) return (value: null);
    final d = v is String ? _toDate(v.trim()) : null;
    if (d == null) {
      warnings.add('Reise: startDate „$v“ ist kein Datum (YYYY-MM-DD) – ignoriert');
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
  static ({int? value})? _parseMoment(Object? v, DateTime? tripStart, String what, List<String> warnings) {
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
        warnings.add('$what: Datum braucht ein Startdatum der Reise (trip.startDate) – ignoriert');
        return null;
      }
    }
    if (dayIndex == null || clock == null) {
      warnings.add('$what: „${jsonEncode(v)}“ unverständlich (erwartet {"day": 1, "time": "14:00"}) – ignoriert');
      return null;
    }
    return (value: at(dayIndex, clock));
  }
}
