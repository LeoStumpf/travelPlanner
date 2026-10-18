// Where new workspace files come from: the system file picker, the gallery,
// the camera and whole folders. Behind a provider (fileSourcesProvider) so
// widget tests can hand in files without platform plugins.
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

/// A file picked for the workspace. [folder] is its subfolder below the
/// picked folder ('' for single files).
class PickedFile {
  final String name;
  final Uint8List bytes;
  final String folder;
  const PickedFile(this.name, this.bytes, {this.folder = ''});
}

/// A picked folder: its name and the readable files below it. [unreadable]
/// counts files that were listed but could not be read.
class PickedFolder {
  final String name;
  final List<PickedFile> files;
  final int unreadable;
  const PickedFolder(this.name, this.files, {this.unreadable = 0});
}

class FileSources {
  const FileSources();

  /// Any files, several at once. Empty when cancelled.
  Future<List<PickedFile>> pickFiles({String? dialogTitle}) async {
    final picked = await FilePicker.pickFiles(dialogTitle: dialogTitle);
    return [for (final f in picked) PickedFile(f.name, await f.xFile.readAsBytes())];
  }

  /// Photos from the gallery, several at once.
  Future<List<PickedFile>> pickImages() async {
    final picked = await ImagePicker().pickMultiImage(maxWidth: 2400, imageQuality: 85);
    return [for (final x in picked) PickedFile(x.name, await x.readAsBytes())];
  }

  /// A new photo from the camera, or null.
  Future<PickedFile?> takePhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 2400, imageQuality: 85);
    return x == null ? null : PickedFile(x.name, await x.readAsBytes());
  }

  /// A folder with all files below it, or null when cancelled. Reading is
  /// best effort: Android only lets the app read some files of a folder
  /// picked this way, the others count as [PickedFolder.unreadable].
  Future<PickedFolder?> pickFolder({String? dialogTitle}) async {
    final path = await FilePicker.getDirectoryPath(dialogTitle: dialogTitle);
    if (path == null) return null;
    return readFolder(Directory(path));
  }
}

/// All files below [dir] with their subfolder relative to it; hidden files
/// and folders (".thumbnails") are skipped.
Future<PickedFolder> readFolder(Directory dir) async {
  final files = <PickedFile>[];
  var unreadable = 0;
  try {
    await for (final e in dir.list(recursive: true, followLinks: false)) {
      if (e is! File) continue;
      final rel = p.relative(e.path, from: dir.path);
      if (p.split(rel).any((s) => s.startsWith('.'))) continue;
      try {
        final folder = p.dirname(rel) == '.' ? '' : p.split(p.dirname(rel)).join('/');
        files.add(PickedFile(p.basename(rel), await e.readAsBytes(), folder: folder));
      } on FileSystemException {
        unreadable++;
      }
    }
  } on FileSystemException {
    // Listing itself is not allowed: nothing readable.
  }
  files.sort((a, b) => '${a.folder}/${a.name}'.compareTo('${b.folder}/${b.name}'));
  return PickedFolder(p.basename(dir.path), files, unreadable: unreadable);
}
