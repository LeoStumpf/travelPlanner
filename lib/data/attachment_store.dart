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

  Future<void> delete(Attachment a) async {
    final f = fileFor(a);
    if (await f.exists()) await f.delete();
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
