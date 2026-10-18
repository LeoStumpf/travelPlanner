import 'models.dart';

/// The trip's file workspace: folders are '/'-separated paths ("Flights/
/// Outbound"), '' is the top level. Files keep their folder in
/// [Attachment.folder]; empty folders are listed in [Trip.folders].

/// [path] without empty segments and surrounding blanks ("/a//b " -> "a/b").
/// Slashes inside a single name are not possible: they always split.
String normalizeFolder(String path) => path.split('/').map((s) => s.trim()).where((s) => s.isNotEmpty).join('/');

/// "a/b/c" -> "a/b"; top-level folders -> ''.
String parentFolder(String path) {
  final i = path.lastIndexOf('/');
  return i < 0 ? '' : path.substring(0, i);
}

/// Last segment of [path] ("a/b" -> "b").
String folderName(String path) => path.substring(path.lastIndexOf('/') + 1);

/// [parent] joined with [name] (either may be empty).
String joinFolder(String parent, String name) => normalizeFolder('$parent/$name');

/// Whether [path] is [folder] itself or lies somewhere inside it.
bool isInFolder(String path, String folder) => folder.isEmpty || path == folder || path.startsWith('$folder/');

/// [path] and all of its ancestors ("a/b" -> ["a", "a/b"]).
Iterable<String> _withAncestors(String path) sync* {
  if (path.isEmpty) return;
  final parts = path.split('/');
  for (var k = 1; k <= parts.length; k++) {
    yield parts.take(k).join('/');
  }
}

extension Workspace on TripData {
  /// Every folder of the trip: the explicit ones and those holding files,
  /// with their parents.
  Set<String> get allFolders => {
    for (final f in trip.folders) ..._withAncestors(normalizeFolder(f)),
    for (final a in attachments) ..._withAncestors(a.folder),
  };

  /// Direct subfolders of [folder], sorted by name (case-insensitive).
  List<String> subfoldersOf(String folder) {
    final list = [
      for (final f in allFolders)
        if (f != folder && parentFolder(f) == folder) f,
    ];
    list.sort((a, b) => folderName(a).toLowerCase().compareTo(folderName(b).toLowerCase()));
    return list;
  }

  /// Files directly in [folder], newest first.
  List<Attachment> filesIn(String folder) {
    final list = [
      for (final a in attachments)
        if (a.folder == folder) a,
    ];
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Files in [folder] or any of its subfolders.
  List<Attachment> filesBelow(String folder) => [
    for (final a in attachments)
      if (isInFolder(a.folder, folder)) a,
  ];

  /// [fileName], or "name (2).ext", "name (3).ext"... when [folder] already
  /// holds a file of that name. [except] is the file being renamed.
  String uniqueFileName(String folder, String fileName, {String? except}) {
    final taken = {
      for (final a in attachments)
        if (a.folder == folder && a.id != except) a.fileName.toLowerCase(),
    };
    return _unique(fileName, taken);
  }

  /// [name], or "name (2)"... when [parent] already has such a subfolder.
  String uniqueFolderName(String parent, String name) {
    final taken = {for (final f in subfoldersOf(parent)) folderName(f).toLowerCase()};
    return _unique(name, taken, keepExtension: false);
  }
}

String _unique(String name, Set<String> takenLower, {bool keepExtension = true}) {
  if (!takenLower.contains(name.toLowerCase())) return name;
  final dot = keepExtension ? name.lastIndexOf('.') : -1;
  final base = dot > 0 ? name.substring(0, dot) : name;
  final ext = dot > 0 ? name.substring(dot) : '';
  for (var n = 2; ; n++) {
    final candidate = '$base ($n)$ext';
    if (!takenLower.contains(candidate.toLowerCase())) return candidate;
  }
}

/// [path] after its folder [from] (or an ancestor of it) was renamed to [to];
/// paths outside [from] are returned unchanged.
String movedFolderPath(String path, String from, String to) {
  if (path == from) return to;
  if (from.isNotEmpty && path.startsWith('$from/')) return joinFolder(to, path.substring(from.length + 1));
  return path;
}
