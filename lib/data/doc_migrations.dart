import 'dart:convert';

/// Version of the JSON layout of the stored documents (trip, item, card, edge,
/// attachment rows and the same objects inside backup ZIPs). Steps also see
/// the repository's `trashed` marker rows (`{"deletedAt": ...}`) and must pass
/// through types they do not change.
///
/// Adding an optional field with a default needs no new version: the
/// `fromJson` factories already tolerate missing keys. Bump it only when old
/// JSON would be read wrongly (renamed or restructured fields, changed
/// units...), and add the step that turns version N into N + 1 to
/// [docMigrationSteps] (index 0 migrates 1 -> 2). Steps get the raw JSON map
/// and the row type, so they never depend on the current model classes.
const currentDocVersion = 2;

/// Rewrites one document of [type] from version `index + 1` to `index + 2`.
typedef DocMigrationStep = Map<String, Object?> Function(String type, Map<String, Object?> json);

/// Released steps, in order. Never edit a step once shipped.
const List<DocMigrationStep> docMigrationSteps = [_v1AttachmentOwners];

/// 1 -> 2: an attachment belonged to one item or card (`ownerId`); it now
/// lives in the trip's file workspace and can be linked to several
/// (`ownerIds`).
Map<String, Object?> _v1AttachmentOwners(String type, Map<String, Object?> j) {
  if (type != 'attachment' || !j.containsKey('ownerId')) return j;
  final owner = j['ownerId'];
  return {
    for (final e in j.entries)
      if (e.key != 'ownerId') e.key: e.value,
    'ownerIds': [?owner],
  };
}

/// Data written by a newer app version (doc format [found], this app reads up
/// to [supported]). A [FormatException], worded for the user by the UI.
class NewerDataException implements FormatException {
  final int found;
  final int supported;
  const NewerDataException(this.found, this.supported);

  @override
  String get message => 'Data is from a newer app version (format $found, supported: $supported)';
  @override
  dynamic get source => null;
  @override
  int? get offset => null;
  @override
  String toString() => 'NewerDataException: $message';
}

/// Applies all steps from [from] up to [to] (default [currentDocVersion]).
/// Throws a [NewerDataException] for documents newer than this app knows.
Map<String, Object?> migrateDoc(
  String type,
  Map<String, Object?> json,
  int from, {
  int to = currentDocVersion,
  List<DocMigrationStep> steps = docMigrationSteps,
}) {
  if (from > to) {
    throw NewerDataException(from, to);
  }
  var j = json;
  for (var v = from; v < to; v++) {
    j = steps[v - 1](type, j);
  }
  return j;
}

/// [migrateDoc] on an encoded document, as stored in the database.
String migrateDocJson(
  String type,
  String json,
  int from, {
  int to = currentDocVersion,
  List<DocMigrationStep> steps = docMigrationSteps,
}) =>
    jsonEncode(migrateDoc(type, (jsonDecode(json) as Map).cast<String, Object?>(), from, to: to, steps: steps));
