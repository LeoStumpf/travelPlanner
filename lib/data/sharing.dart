// Hands text and files to the system share sheet (share_plus). Behind a
// provider (sharerProvider) so tests can capture what would be shared.
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class Sharer {
  const Sharer();

  Future<void> shareText(String text, {String? subject}) =>
      SharePlus.instance.share(ShareParams(text: text, subject: subject));

  /// Writes [bytes] to a temporary file called [name] and shares it.
  Future<void> shareFile(Uint8List bytes, {required String name, required String mime, String? subject}) async {
    final dir = Directory(p.join((await getTemporaryDirectory()).path, 'share'));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: mime, name: name)],
      subject: subject,
    ));
  }

  /// Shares files that already exist on disk ([files]: path, mime, name).
  Future<void> shareFiles(List<(String, String, String)> files) => SharePlus.instance.share(ShareParams(
        files: [for (final (path, mime, name) in files) XFile(path, mimeType: mime, name: name)],
      ));
}
