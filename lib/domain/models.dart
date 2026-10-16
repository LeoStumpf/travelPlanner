// Domain models – pure Dart, no Flutter imports, so they can be shared with
// any future platform target.
//
// Time model: all times are minutes relative to 00:00 of trip day 0.
// This lets a trip be planned before real dates are known ("Tag 1, Tag 2 …");
// once a start date is set, days map onto the calendar.

const _keep = Object();

enum ItemKind { stay, transport, accommodation, activity }

extension ItemKindX on ItemKind {
  /// Planning layer (1 = places, 2 = transport, 3 = lodging, 4 = activities).
  int get layer => index + 1;

  String get label => switch (this) {
        ItemKind.stay => 'Ort',
        ItemKind.transport => 'Transport',
        ItemKind.accommodation => 'Unterkunft',
        ItemKind.activity => 'Aktivität',
      };
}

enum ItemStatus { idea, option, planned, booked }

extension ItemStatusX on ItemStatus {
  String get label => switch (this) {
        ItemStatus.idea => 'Idee',
        ItemStatus.option => 'Option',
        ItemStatus.planned => 'Geplant',
        ItemStatus.booked => 'Gebucht',
      };
}

enum TransportMode { train, bus, plane, ferry, car, taxi, walk, other }

extension TransportModeX on TransportMode {
  String get label => switch (this) {
        TransportMode.train => 'Zug',
        TransportMode.bus => 'Bus',
        TransportMode.plane => 'Flug',
        TransportMode.ferry => 'Fähre',
        TransportMode.car => 'Auto',
        TransportMode.taxi => 'Taxi/Tuk-Tuk',
        TransportMode.walk => 'Zu Fuß',
        TransportMode.other => 'Sonstiges',
      };
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

class Trip {
  final String id;
  final String title;

  /// Calendar date of trip day 0 (date only). Null while dates are unknown.
  final DateTime? startDate;

  /// Planned length in days, used to show empty days at the end.
  final int? plannedDays;
  final int color;
  final DateTime createdAt;

  const Trip({
    required this.id,
    required this.title,
    this.startDate,
    this.plannedDays,
    this.color = 0xFF00876A,
    required this.createdAt,
  });

  Trip copyWith({
    String? title,
    Object? startDate = _keep,
    Object? plannedDays = _keep,
    int? color,
  }) =>
      Trip(
        id: id,
        title: title ?? this.title,
        startDate: identical(startDate, _keep) ? this.startDate : startDate as DateTime?,
        plannedDays: identical(plannedDays, _keep) ? this.plannedDays : plannedDays as int?,
        color: color ?? this.color,
        createdAt: createdAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'startDate': startDate?.toIso8601String(),
        'plannedDays': plannedDays,
        'color': color,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Trip.fromJson(Map<String, Object?> j) => Trip(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        startDate: j['startDate'] == null ? null : DateTime.parse(j['startDate'] as String),
        plannedDays: j['plannedDays'] as int?,
        color: j['color'] as int? ?? 0xFF00876A,
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

/// A file (ticket PDF, photo, screenshot) stored in the app's documents
/// directory. [ownerId] is the item or card it belongs to.
class Attachment {
  final String id;
  final String tripId;
  final String ownerId;
  final String fileName;

  /// Path relative to the attachments directory.
  final String relPath;
  final String mime;
  final DateTime createdAt;

  const Attachment({
    required this.id,
    required this.tripId,
    required this.ownerId,
    required this.fileName,
    required this.relPath,
    required this.mime,
    required this.createdAt,
  });

  bool get isImage => mime.startsWith('image/');

  Map<String, Object?> toJson() => {
        'id': id,
        'tripId': tripId,
        'ownerId': ownerId,
        'fileName': fileName,
        'relPath': relPath,
        'mime': mime,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Attachment.fromJson(Map<String, Object?> j) => Attachment(
        id: j['id'] as String,
        tripId: j['tripId'] as String,
        ownerId: j['ownerId'] as String,
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
      [for (final a in attachments) if (a.ownerId == ownerId) a];

  Attachment? attachment(String? id) {
    if (id == null) return null;
    for (final a in attachments) {
      if (a.id == id) return a;
    }
    return null;
  }
}
