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
    required String ownerId,
    required String sourcePath,
    String? fileName,
  }) async {
    final name = fileName ?? p.basename(sourcePath);
    final bytes = await File(sourcePath).readAsBytes();
    return addBytes(tripId: tripId, ownerId: ownerId, bytes: bytes, fileName: name);
  }

  Future<Attachment> addBytes({
    required String tripId,
    required String ownerId,
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
      ownerId: ownerId,
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
      default:
        return 'application/octet-stream';
    }
  }
}
