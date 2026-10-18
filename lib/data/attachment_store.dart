import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../domain/models.dart';

/// Stores attachment files (tickets, photos) in a private app directory.
class AttachmentStore {
  final Directory root;
  AttachmentStore(this.root);

  File fileFor(Attachment a) => File(p.join(root.path, a.relPath));

  Future<Attachment> addFile({
    required String tripId,
    List<String> ownerIds = const [],
    String folder = '',
    required String sourcePath,
    String? fileName,
  }) async {
    final name = fileName ?? p.basename(sourcePath);
    final bytes = await File(sourcePath).readAsBytes();
    return addBytes(tripId: tripId, ownerIds: ownerIds, folder: folder, bytes: bytes, fileName: name);
  }

  Future<Attachment> addBytes({
    required String tripId,
    List<String> ownerIds = const [],
    String folder = '',
    required Uint8List bytes,
    required String fileName,
    String? id,
    String? relPath,
    DateTime? createdAt,
  }) async {
    final attId = id ?? const Uuid().v4();
    final rel = relPath ?? '$attId${p.extension(fileName).toLowerCase()}';
    final f = File(p.join(root.path, rel));
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes, flush: true);
    return Attachment(
      id: attId,
      tripId: tripId,
      ownerIds: ownerIds,
      folder: folder,
      fileName: fileName,
      relPath: rel,
      mime: mimeFor(fileName),
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  Directory get _trash => Directory(p.join(root.path, '.trash'));
  File _trashFor(Attachment a) => File(p.join(_trash.path, a.relPath));

  /// Moves the file to the trash so that an undo can bring it back.
  Future<void> delete(Attachment a) async {
    final f = fileFor(a);
    if (!await f.exists()) return;
    final t = _trashFor(a);
    await t.parent.create(recursive: true);
    await f.rename(t.path);
  }

  /// Brings a file back from the trash (after an undo).
  Future<void> restore(Attachment a) async {
    final f = fileFor(a);
    final t = _trashFor(a);
    if (await f.exists() || !await t.exists()) return;
    await f.parent.create(recursive: true);
    await t.rename(f.path);
  }

  Future<void> deletePermanently(Attachment a) async {
    for (final f in [fileFor(a), _trashFor(a)]) {
      if (await f.exists()) await f.delete();
    }
  }

  /// Called on app start: undo history does not survive a restart.
  Future<void> emptyTrash() async {
    if (await _trash.exists()) await _trash.delete(recursive: true);
  }

  /// Size of the stored file in bytes, or null when it is missing.
  int? sizeOf(Attachment a) {
    final f = fileFor(a);
    return f.existsSync() ? f.lengthSync() : null;
  }

  static String mimeFor(String fileName) {
    switch (p.extension(fileName).toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.heic':
        return 'image/heic';
      case '.pdf':
        return 'application/pdf';
      case '.txt':
        return 'text/plain';
      case '.html':
        return 'text/html';
      case '.pkpass':
        return 'application/vnd.apple.pkpass';
      case '.htm':
        return 'text/html';
      case '.csv':
        return 'text/csv';
      case '.json':
        return 'application/json';
      case '.md':
        return 'text/markdown';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.xls':
        return 'application/vnd.ms-excel';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.ppt':
        return 'application/vnd.ms-powerpoint';
      case '.pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case '.odt':
        return 'application/vnd.oasis.opendocument.text';
      case '.ods':
        return 'application/vnd.oasis.opendocument.spreadsheet';
      case '.zip':
        return 'application/zip';
      case '.gpx':
        return 'application/gpx+xml';
      case '.kml':
        return 'application/vnd.google-earth.kml+xml';
      case '.ics':
        return 'text/calendar';
      case '.eml':
        return 'message/rfc822';
      case '.mp3':
        return 'audio/mpeg';
      case '.m4a':
        return 'audio/mp4';
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.webm':
        return 'video/webm';
      default:
        return 'application/octet-stream';
    }
  }
}
