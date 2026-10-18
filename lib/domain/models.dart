// Domain models – pure Dart, no Flutter imports, so they can be shared with
// any future platform target.
//
// Time model: all times are minutes relative to 00:00 of trip day 0.
// This lets a trip be planned before real dates are known ("Tag 1, Tag 2 …");
// once a start date is set, days map onto the calendar. Times are local
// wall-clock times of the place they belong to; optional IANA time zones
// (Trip.homeZone, PlanItem.tz / endTz) make them comparable across zones,
// see zones.dart.

const _keep = Object();

enum ItemKind { stay, transport, accommodation, activity }

extension ItemKindX on ItemKind {
  /// Planning layer (1 = places, 2 = transport, 3 = lodging, 4 = activities).
  int get layer => index + 1;
}

enum ItemStatus { idea, option, planned, booked }

enum TransportMode { train, bus, plane, ferry, car, taxi, walk, other }

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

/// Optional price of a plan item. Amounts are in [currency], or in the
/// trip's home currency ([Trip.currency]) when that is null; see budget.dart.
class Cost {
  final double amount;

  /// ISO 4217 code ("EUR", "LKR"); null = the trip's home currency.
  final String? currency;

  /// The amount is per traveller ([Trip.travellers]) rather than in total.
  final bool perPerson;
  final bool paid;

  const Cost({required this.amount, this.currency, this.perPerson = false, this.paid = false});

  Cost copyWith({double? amount, Object? currency = _keep, bool? perPerson, bool? paid}) => Cost(
        amount: amount ?? this.amount,
        currency: identical(currency, _keep) ? this.currency : currency as String?,
        perPerson: perPerson ?? this.perPerson,
        paid: paid ?? this.paid,
      );

  Map<String, Object?> toJson() => {
        'amount': amount,
        if (currency != null) 'currency': currency,
        if (perPerson) 'perPerson': true,
        if (paid) 'paid': true,
      };

  /// Null for anything that is not a cost object with a numeric amount.
  static Cost? fromJson(Object? j) {
    if (j is! Map || j['amount'] is! num) return null;
    return Cost(
      amount: (j['amount'] as num).toDouble(),
      currency: j['currency'] as String?,
      perPerson: j['perPerson'] == true,
      paid: j['paid'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Cost &&
      other.amount == amount &&
      other.currency == currency &&
      other.perPerson == perPerson &&
      other.paid == paid;

  @override
  int get hashCode => Object.hash(amount, currency, perPerson, paid);
}

class Trip {
  final String id;
  final String title;

  /// Calendar date of trip day 0 (date only). Null while dates are unknown.
  final DateTime? startDate;

  /// Planned length in days, used to show empty days at the end.
  final int? plannedDays;
  final int color;

  /// IANA zone ("Europe/Berlin") of items that have none of their own.
  /// Null = times without zone, as before zones existed.
  final String? homeZone;

  /// ISO 4217 home currency the budget is shown in; null = not set yet.
  final String? currency;

  /// Number of travellers; per-person costs count this many times.
  final int travellers;

  /// Manual exchange rates: foreign units per one unit of [currency]
  /// ({"LKR": 330} = 1 EUR buys 330 LKR). Entered by the user, offline.
  final Map<String, double> rates;

  /// Folders of the trip's file workspace ("Flights/Outbound"), including
  /// empty ones; folders that hold files also follow from [Attachment.folder].
  final List<String> folders;
  final DateTime createdAt;

  const Trip({
    required this.id,
    required this.title,
    this.startDate,
    this.plannedDays,
    this.color = 0xFF00876A,
    this.homeZone,
    this.currency,
    this.travellers = 1,
    this.rates = const {},
    this.folders = const [],
    required this.createdAt,
  });

  Trip copyWith({
    String? title,
    Object? startDate = _keep,
    Object? plannedDays = _keep,
    int? color,
    Object? homeZone = _keep,
    Object? currency = _keep,
    int? travellers,
    Map<String, double>? rates,
    List<String>? folders,
  }) =>
      Trip(
        id: id,
        title: title ?? this.title,
        startDate: identical(startDate, _keep) ? this.startDate : startDate as DateTime?,
        plannedDays: identical(plannedDays, _keep) ? this.plannedDays : plannedDays as int?,
        color: color ?? this.color,
        homeZone: identical(homeZone, _keep) ? this.homeZone : homeZone as String?,
        currency: identical(currency, _keep) ? this.currency : currency as String?,
        travellers: travellers ?? this.travellers,
        rates: rates ?? this.rates,
        folders: folders ?? this.folders,
        createdAt: createdAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'startDate': startDate?.toIso8601String(),
        'plannedDays': plannedDays,
        'color': color,
        if (homeZone != null) 'homeZone': homeZone,
        if (currency != null) 'currency': currency,
        if (travellers != 1) 'travellers': travellers,
        if (rates.isNotEmpty) 'rates': rates,
        if (folders.isNotEmpty) 'folders': folders,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Trip.fromJson(Map<String, Object?> j) => Trip(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        startDate: j['startDate'] == null ? null : DateTime.parse(j['startDate'] as String),
        plannedDays: j['plannedDays'] as int?,
        color: j['color'] as int? ?? 0xFF00876A,
        homeZone: j['homeZone'] as String?,
        currency: j['currency'] as String?,
        travellers: (j['travellers'] as int?) ?? 1,
        rates: {
          for (final e in ((j['rates'] as Map?) ?? const {}).entries)
            if (e.value is num) '${e.key}': (e.value as num).toDouble(),
        },
        folders: [for (final f in (j['folders'] as List?) ?? const []) '$f'],
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class PlanItem {
  final String id;
  final String tripId;
  final ItemKind kind;
  final String title;
  final String? placeName;
  final double? lat;
  final double? lng;
  final ItemStatus status;

  /// Fixed items (booked tour, flight home) never move when rippling.
  final bool fixed;

  /// Minutes from trip day 0 00:00. Both null = not yet scheduled.
  final int? start;
  final int? end;
  final String notes;
  final List<String> links;

  /// For accommodation/activity: the stay it belongs to.
  final String? parentId;

  /// For transport: origin / destination stay.
  final String? fromId;
  final String? toId;
  final TransportMode? mode;

  /// For transport: structured ticket details, all optional free text.
  /// Departure / arrival station, airport or port ("Colombo Fort", "FRA T1").
  final String? departureStation;
  final String? arrivalStation;

  /// Train, flight or bus number ("IC 1009", "LH 754").
  final String? transportNumber;

  /// Seat and/or platform ("Car 3, seat 42", "Pl. 2").
  final String? seat;

  /// Booking reference / PNR, shown with a copy button.
  final String? bookingRef;

  /// IANA time zone of the times. For a stay: the zone of the place (its
  /// accommodation and activities follow it). For a transport: departure
  /// zone, overriding the origin stay's. Ignored for other kinds.
  final String? tz;

  /// For transport: arrival zone, overriding the destination stay's.
  final String? endTz;

  /// Optional price (estimated or actual), see budget.dart.
  final Cost? cost;

  /// Position on the canvas; null = auto-placed.
  final double? canvasX;
  final double? canvasY;
  final DateTime createdAt;

  const PlanItem({
    required this.id,
    required this.tripId,
    required this.kind,
    required this.title,
    this.placeName,
    this.lat,
    this.lng,
    this.status = ItemStatus.planned,
    this.fixed = false,
    this.start,
    this.end,
    this.notes = '',
    this.links = const [],
    this.parentId,
    this.fromId,
    this.toId,
    this.mode,
    this.departureStation,
    this.arrivalStation,
    this.transportNumber,
    this.seat,
    this.bookingRef,
    this.tz,
    this.endTz,
    this.cost,
    this.canvasX,
    this.canvasY,
    required this.createdAt,
  });

  bool get isScheduled => start != null && end != null;
  bool get hasLocation => lat != null && lng != null;
  bool get isOption => status == ItemStatus.option;

  /// The item this one moves with: explicit parent, or for transports the
  /// destination stay (falls back to the origin).
  String? get anchorId => parentId ?? toId ?? fromId;

  int get duration => (end ?? 0) - (start ?? 0);

  /// True if any of the transport ticket details is filled in.
  bool get hasTransportDetails =>
      departureStation != null ||
      arrivalStation != null ||
      transportNumber != null ||
      seat != null ||
      bookingRef != null;

  PlanItem copyWith({
    ItemKind? kind,
    String? title,
    Object? placeName = _keep,
    Object? lat = _keep,
    Object? lng = _keep,
    ItemStatus? status,
    bool? fixed,
    Object? start = _keep,
    Object? end = _keep,
    String? notes,
    List<String>? links,
    Object? parentId = _keep,
    Object? fromId = _keep,
    Object? toId = _keep,
    Object? mode = _keep,
    Object? departureStation = _keep,
    Object? arrivalStation = _keep,
    Object? transportNumber = _keep,
    Object? seat = _keep,
    Object? bookingRef = _keep,
    Object? tz = _keep,
    Object? endTz = _keep,
    Object? cost = _keep,
    Object? canvasX = _keep,
    Object? canvasY = _keep,
  }) =>
      PlanItem(
        id: id,
        tripId: tripId,
        kind: kind ?? this.kind,
        title: title ?? this.title,
        placeName: identical(placeName, _keep) ? this.placeName : placeName as String?,
        lat: identical(lat, _keep) ? this.lat : lat as double?,
        lng: identical(lng, _keep) ? this.lng : lng as double?,
        status: status ?? this.status,
        fixed: fixed ?? this.fixed,
        start: identical(start, _keep) ? this.start : start as int?,
        end: identical(end, _keep) ? this.end : end as int?,
        notes: notes ?? this.notes,
        links: links ?? this.links,
        parentId: identical(parentId, _keep) ? this.parentId : parentId as String?,
        fromId: identical(fromId, _keep) ? this.fromId : fromId as String?,
        toId: identical(toId, _keep) ? this.toId : toId as String?,
        mode: identical(mode, _keep) ? this.mode : mode as TransportMode?,
        departureStation:
            identical(departureStation, _keep) ? this.departureStation : departureStation as String?,
        arrivalStation: identical(arrivalStation, _keep) ? this.arrivalStation : arrivalStation as String?,
        transportNumber: identical(transportNumber, _keep) ? this.transportNumber : transportNumber as String?,
        seat: identical(seat, _keep) ? this.seat : seat as String?,
        bookingRef: identical(bookingRef, _keep) ? this.bookingRef : bookingRef as String?,
        tz: identical(tz, _keep) ? this.tz : tz as String?,
        endTz: identical(endTz, _keep) ? this.endTz : endTz as String?,
        cost: identical(cost, _keep) ? this.cost : cost as Cost?,
        canvasX: identical(canvasX, _keep) ? this.canvasX : canvasX as double?,
        canvasY: identical(canvasY, _keep) ? this.canvasY : canvasY as double?,
        createdAt: createdAt,
      );

  PlanItem shiftedBy(int minutes) => isScheduled
      ? copyWith(start: start! + minutes, end: end! + minutes)
      : this;

  Map<String, Object?> toJson() => {
        'id': id,
        'tripId': tripId,
        'kind': kind.name,
        'title': title,
        'placeName': placeName,
        'lat': lat,
        'lng': lng,
        'status': status.name,
        'fixed': fixed,
        'start': start,
        'end': end,
        'notes': notes,
        'links': links,
        'parentId': parentId,
        'fromId': fromId,
        'toId': toId,
        'mode': mode?.name,
        // Optional since doc version 1; left out when empty so rows of
        // items without details look as before.
        if (departureStation != null) 'departureStation': departureStation,
        if (arrivalStation != null) 'arrivalStation': arrivalStation,
        if (transportNumber != null) 'transportNumber': transportNumber,
        if (seat != null) 'seat': seat,
        if (bookingRef != null) 'bookingRef': bookingRef,
        if (tz != null) 'tz': tz,
        if (endTz != null) 'endTz': endTz,
        if (cost != null) 'cost': cost!.toJson(),
        'canvasX': canvasX,
        'canvasY': canvasY,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PlanItem.fromJson(Map<String, Object?> j) => PlanItem(
        id: j['id'] as String,
        tripId: j['tripId'] as String,
        kind: _enumByName(ItemKind.values, j['kind'], ItemKind.stay),
        title: j['title'] as String? ?? '',
        placeName: j['placeName'] as String?,
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        status: _enumByName(ItemStatus.values, j['status'], ItemStatus.planned),
        fixed: j['fixed'] as bool? ?? false,
        start: j['start'] as int?,
        end: j['end'] as int?,
        notes: j['notes'] as String? ?? '',
        links: (j['links'] as List?)?.cast<String>() ?? const [],
        parentId: j['parentId'] as String?,
        fromId: j['fromId'] as String?,
        toId: j['toId'] as String?,
        mode: j['mode'] == null ? null : _enumByName(TransportMode.values, j['mode'], TransportMode.other),
        departureStation: j['departureStation'] as String?,
        arrivalStation: j['arrivalStation'] as String?,
        transportNumber: j['transportNumber'] as String?,
        seat: j['seat'] as String?,
        bookingRef: j['bookingRef'] as String?,
        tz: j['tz'] as String?,
        endTz: j['endTz'] as String?,
        cost: Cost.fromJson(j['cost']),
        canvasX: (j['canvasX'] as num?)?.toDouble(),
        canvasY: (j['canvasY'] as num?)?.toDouble(),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

enum CardType { note, checklist, link, image }

class ChecklistEntry {
  final String id;
  final String text;
  final bool done;
  const ChecklistEntry({required this.id, required this.text, this.done = false});

  ChecklistEntry copyWith({String? text, bool? done}) =>
      ChecklistEntry(id: id, text: text ?? this.text, done: done ?? this.done);

  Map<String, Object?> toJson() => {'id': id, 'text': text, 'done': done};
  factory ChecklistEntry.fromJson(Map<String, Object?> j) => ChecklistEntry(
        id: j['id'] as String,
        text: j['text'] as String? ?? '',
        done: j['done'] as bool? ?? false,
      );
}

/// Free-form content (Keep-style note, checklist, link, image). The same card
/// shows up in the Keep grid and on the canvas.
class NoteCard {
  final String id;
  final String tripId;
  final CardType type;
  final String title;
  final String text;
  final List<ChecklistEntry> checklist;
  final String? url;
  final String? imageAttachmentId;

  /// Fetched link preview (og:title / og:image).
  final String? previewTitle;
  final String? previewImageUrl;
  final int color;
  final bool pinned;
  final double? canvasX;
  final double? canvasY;
  final double canvasW;

  /// Optional link to a plan item ("this note is about Kandy").
  final String? itemId;
  final DateTime createdAt;

  const NoteCard({
    required this.id,
    required this.tripId,
    required this.type,
    this.title = '',
    this.text = '',
    this.checklist = const [],
    this.url,
    this.imageAttachmentId,
    this.previewTitle,
    this.previewImageUrl,
    this.color = 0,
    this.pinned = false,
    this.canvasX,
    this.canvasY,
    this.canvasW = 220,
    this.itemId,
    required this.createdAt,
  });

  NoteCard copyWith({
    CardType? type,
    String? title,
    String? text,
    List<ChecklistEntry>? checklist,
    Object? url = _keep,
    Object? imageAttachmentId = _keep,
    Object? previewTitle = _keep,
    Object? previewImageUrl = _keep,
    int? color,
    bool? pinned,
    Object? canvasX = _keep,
    Object? canvasY = _keep,
    double? canvasW,
    Object? itemId = _keep,
  }) =>
      NoteCard(
        id: id,
        tripId: tripId,
        type: type ?? this.type,
        title: title ?? this.title,
        text: text ?? this.text,
        checklist: checklist ?? this.checklist,
        url: identical(url, _keep) ? this.url : url as String?,
        imageAttachmentId: identical(imageAttachmentId, _keep)
            ? this.imageAttachmentId
            : imageAttachmentId as String?,
        previewTitle: identical(previewTitle, _keep) ? this.previewTitle : previewTitle as String?,
        previewImageUrl:
            identical(previewImageUrl, _keep) ? this.previewImageUrl : previewImageUrl as String?,
        color: color ?? this.color,
        pinned: pinned ?? this.pinned,
        canvasX: identical(canvasX, _keep) ? this.canvasX : canvasX as double?,
        canvasY: identical(canvasY, _keep) ? this.canvasY : canvasY as double?,
        canvasW: canvasW ?? this.canvasW,
        itemId: identical(itemId, _keep) ? this.itemId : itemId as String?,
        createdAt: createdAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'tripId': tripId,
        'type': type.name,
        'title': title,
        'text': text,
        'checklist': [for (final e in checklist) e.toJson()],
        'url': url,
        'imageAttachmentId': imageAttachmentId,
        'previewTitle': previewTitle,
        'previewImageUrl': previewImageUrl,
        'color': color,
        'pinned': pinned,
        'canvasX': canvasX,
        'canvasY': canvasY,
        'canvasW': canvasW,
        'itemId': itemId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory NoteCard.fromJson(Map<String, Object?> j) => NoteCard(
        id: j['id'] as String,
        tripId: j['tripId'] as String,
        type: _enumByName(CardType.values, j['type'], CardType.note),
        title: j['title'] as String? ?? '',
        text: j['text'] as String? ?? '',
        checklist: [
          for (final e in (j['checklist'] as List? ?? const []))
            ChecklistEntry.fromJson((e as Map).cast<String, Object?>()),
        ],
        url: j['url'] as String?,
        imageAttachmentId: j['imageAttachmentId'] as String?,
        previewTitle: j['previewTitle'] as String?,
        previewImageUrl: j['previewImageUrl'] as String?,
        color: j['color'] as int? ?? 0,
        pinned: j['pinned'] as bool? ?? false,
        canvasX: (j['canvasX'] as num?)?.toDouble(),
        canvasY: (j['canvasY'] as num?)?.toDouble(),
        canvasW: (j['canvasW'] as num?)?.toDouble() ?? 220,
        itemId: j['itemId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

/// A free connection drawn on the canvas between two cards and/or items.
class Edge {
  final String id;
  final String tripId;
  final String fromId;
  final String toId;
  final String label;

  const Edge({
    required this.id,
    required this.tripId,
    required this.fromId,
    required this.toId,
    this.label = '',
  });

  Map<String, Object?> toJson() =>
      {'id': id, 'tripId': tripId, 'fromId': fromId, 'toId': toId, 'label': label};

  factory Edge.fromJson(Map<String, Object?> j) => Edge(
        id: j['id'] as String,
        tripId: j['tripId'] as String,
        fromId: j['fromId'] as String,
        toId: j['toId'] as String,
        label: j['label'] as String? ?? '',
      );
}

/// A file (ticket PDF, photo, screenshot) in the trip's file workspace,
/// stored in the app's documents directory. [ownerIds] are the items and
/// cards it is linked to (none: it only lives in the workspace).
class Attachment {
  final String id;
  final String tripId;
  final List<String> ownerIds;

  /// Workspace folder ("Flights/Outbound"); '' is the top level.
  final String folder;
  final String fileName;

  /// Path relative to the attachments directory.
  final String relPath;
  final String mime;
  final DateTime createdAt;

  const Attachment({
    required this.id,
    required this.tripId,
    this.ownerIds = const [],
    this.folder = '',
    required this.fileName,
    required this.relPath,
    required this.mime,
    required this.createdAt,
  });

  bool get isImage => mime.startsWith('image/');

  Attachment copyWith({List<String>? ownerIds, String? folder, String? fileName}) => Attachment(
        id: id,
        tripId: tripId,
        ownerIds: ownerIds ?? this.ownerIds,
        folder: folder ?? this.folder,
        fileName: fileName ?? this.fileName,
        relPath: relPath,
        mime: mime,
        createdAt: createdAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'tripId': tripId,
        'ownerIds': ownerIds,
        if (folder.isNotEmpty) 'folder': folder,
        'fileName': fileName,
        'relPath': relPath,
        'mime': mime,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Attachment.fromJson(Map<String, Object?> j) => Attachment(
        id: j['id'] as String,
        tripId: j['tripId'] as String,
        ownerIds: [for (final o in (j['ownerIds'] as List?) ?? const []) '$o'],
        folder: j['folder'] as String? ?? '',
        fileName: j['fileName'] as String? ?? '',
        relPath: j['relPath'] as String,
        mime: j['mime'] as String? ?? 'application/octet-stream',
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

/// Everything belonging to one trip, as loaded from storage.
class TripData {
  final Trip trip;
  final List<PlanItem> items;
  final List<NoteCard> cards;
  final List<Edge> edges;
  final List<Attachment> attachments;

  const TripData({
    required this.trip,
    this.items = const [],
    this.cards = const [],
    this.edges = const [],
    this.attachments = const [],
  });

  PlanItem? item(String? id) {
    if (id == null) return null;
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  NoteCard? card(String? id) {
    if (id == null) return null;
    for (final c in cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<Attachment> attachmentsOf(String ownerId) =>
      [for (final a in attachments) if (a.ownerIds.contains(ownerId)) a];

  /// This data with [a] added or replaced.
  TripData withAttachment(Attachment a) => TripData(
        trip: trip,
        items: items,
        cards: cards,
        edges: edges,
        attachments: [for (final x in attachments) if (x.id != a.id) x, a],
      );

  Attachment? attachment(String? id) {
    if (id == null) return null;
    for (final a in attachments) {
      if (a.id == id) return a;
    }
    return null;
  }
}
