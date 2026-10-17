import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'backup.dart';
import 'repository.dart';

/// One all-trips ZIP written by [AutoBackup].
class BackupFile {
  final File file;
  final DateTime createdAt;
  const BackupFile(this.file, this.createdAt);
}

/// Writes an all-trips ZIP into [dir] at most once per [interval] and keeps
/// the newest [keep] files. Triggered on app start and when the app goes to
/// the background (see `AutoBackupListener`).
class AutoBackup {
  static const interval = Duration(hours: 24);
  static const keep = 7;

  final Repository repo;
  final Directory dir;

  AutoBackup(this.repo, this.dir);

  static const _prefix = 'tripboard-backup-';
  static const _suffix = '.zip';

  /// Running backup, so start and background never write at the same time.
  Future<BackupFile?>? _running;

  /// Backups in [dir], newest first.
  Future<List<BackupFile>> list() async {
    if (!await dir.exists()) return const [];
    final list = <BackupFile>[];
    await for (final e in dir.list()) {
      if (e is! File) continue;
      final at = parseName(p.basename(e.path));
      if (at != null) list.add(BackupFile(e, at));
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<DateTime?> lastBackupAt() async => (await list()).firstOrNull?.createdAt;

  /// Writes a backup if the last one is older than [interval]. Does nothing
  /// without trips, so an empty app never rotates good backups away.
  Future<BackupFile?> runIfDue({DateTime? now}) async {
    final t = now ?? DateTime.now();
    final last = await lastBackupAt();
    // A backup "from the future" (clock was changed) does not block new ones.
    if (last != null && !last.isAfter(t) && t.difference(last) < interval) return null;
    if ((await repo.watchTrips().first).isEmpty) return null;
    return createNow(now: t);
  }

  /// Writes a backup now and removes the old ones beyond [keep].
  /// While one is being written, callers get that one.
  Future<BackupFile?> createNow({DateTime? now}) =>
      _running ??= _create(now ?? DateTime.now()).whenComplete(() => _running = null);

  Future<BackupFile?> _create(DateTime now) async {
    await dir.create(recursive: true);
    final bytes = await Backup.exportAll(repo);
    // Never overwrite an existing backup (two backups within one second,
    // e.g. "Jetzt sichern" right before restoring): take the next free second.
    var at = now;
    while (await File(p.join(dir.path, fileName(at))).exists()) {
      at = at.add(const Duration(seconds: 1));
    }
    final target = File(p.join(dir.path, fileName(at)));
    // Written next to the target and renamed, so a process killed in the
    // background never leaves a broken ZIP that looks like a backup.
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(target.path);
    await _prune();
    return BackupFile(target, at);
  }

  Future<void> _prune() async {
    final all = await list();
    for (final b in all.skip(keep)) {
      await b.file.delete();
    }
    await for (final e in dir.list()) {
      if (e is File && e.path.endsWith('$_suffix.tmp')) await e.delete();
    }
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// `tripboard-backup-20261017-143005.zip` (local time).
  static String fileName(DateTime t) => '$_prefix${t.year}${_two(t.month)}${_two(t.day)}-'
      '${_two(t.hour)}${_two(t.minute)}${_two(t.second)}$_suffix';

  static final _pattern = RegExp(r'^tripboard-backup-(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})\.zip$');

  static DateTime? parseName(String name) {
    final m = _pattern.firstMatch(name);
    if (m == null) return null;
    final v = [for (var i = 1; i <= 6; i++) int.parse(m.group(i)!)];
    return DateTime(v[0], v[1], v[2], v[3], v[4], v[5]);
  }
}
