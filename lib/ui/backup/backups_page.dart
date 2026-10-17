import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../data/auto_backup.dart';
import '../../data/backup.dart';
import '../../state/providers.dart';
import '../common/dialogs.dart';

/// "17.10.2026, 14:03"
String formatBackupTime(DateTime t) => DateFormat('dd.MM.yyyy, HH:mm').format(t);

/// "Letztes Backup: …" for the trip list menu.
String lastBackupLabel(List<BackupFile>? backups) {
  final last = backups?.firstOrNull;
  return last == null ? 'Noch kein Backup' : 'Letztes Backup: ${formatBackupTime(last.createdAt)}';
}

/// The automatic backups: back up now, restore one, or save a copy elsewhere.
class BackupsPage extends ConsumerStatefulWidget {
  const BackupsPage({super.key});

  @override
  ConsumerState<BackupsPage> createState() => _BackupsPageState();
}

class _BackupsPageState extends ConsumerState<BackupsPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final auto = ref.watch(autoBackupProvider);
    final backups = ref.watch(backupsProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backups'),
        actions: [
          IconButton(
            tooltip: 'Jetzt sichern',
            icon: const Icon(Icons.backup),
            onPressed: auto == null || _busy ? null : _backupNow,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (_busy) const LinearProgressIndicator(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(lastBackupLabel(backups.value), style: theme.textTheme.titleMedium),
            subtitle: Text(
              'Tripboard sichert alle Reisen automatisch, wenn die App startet oder in den Hintergrund geht '
              'und das letzte Backup älter als einen Tag ist. Die letzten ${AutoBackup.keep} Backups bleiben erhalten.\n'
              'Sie liegen im App-Ordner${auto == null ? '' : ' (${auto.dir.path})'} und werden beim Deinstallieren '
              'gelöscht. Für eine dauerhafte Kopie ein Backup „Speichern unter …“ oder '
              '„Alle Reisen exportieren“ nutzen.',
            ),
          ),
          const SizedBox(height: 8),
          ...switch (backups) {
            AsyncData(:final value) when value.isEmpty => [const _Hint('Noch keine automatischen Backups.')],
            AsyncData(:final value) => [for (final b in value) _tile(b)],
            AsyncError(:final error) => [_Hint('Fehler: $error')],
            _ => [const Center(child: CircularProgressIndicator())],
          },
        ],
      ),
    );
  }

  Widget _tile(BackupFile b) {
    final size = b.file.existsSync() ? b.file.lengthSync() : 0;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.inventory_2_outlined),
        title: Text(formatBackupTime(b.createdAt)),
        subtitle: Text(_size(size)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Wiederherstellen',
              icon: const Icon(Icons.settings_backup_restore),
              onPressed: _busy ? null : () => _restore(b),
            ),
            IconButton(
              tooltip: 'Speichern unter …',
              icon: const Icon(Icons.save_alt),
              onPressed: _busy ? null : () => _saveAs(b),
            ),
          ],
        ),
      ),
    );
  }

  static String _size(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(0)} KB'
      : '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';

  /// Runs [job] with the progress bar. [job] gets the provider container,
  /// which stays usable when the user leaves the page while it runs (`ref`
  /// would throw then and abort a restore halfway).
  Future<void> _guard(Future<void> Function(ProviderContainer c) job) async {
    final c = ProviderScope.containerOf(context, listen: false);
    setState(() => _busy = true);
    try {
      await job(c);
    } finally {
      if (mounted) setState(() => _busy = false);
      c.invalidate(backupsProvider);
    }
  }

  Future<void> _backupNow() => _guard((c) async {
        try {
          await c.read(autoBackupProvider)!.createNow();
          if (mounted) showSnack(context, 'Backup erstellt');
        } catch (e) {
          if (mounted) showSnack(context, 'Backup fehlgeschlagen: $e');
        }
      });

  Future<void> _restore(BackupFile b) async {
    final ok = await confirm(
      context,
      'Backup wiederherstellen?',
      'Alle Reisen aus dem Backup vom ${formatBackupTime(b.createdAt)} werden auf diesen Stand zurückgesetzt '
          'oder wieder angelegt. Reisen, die nicht im Backup sind, bleiben unverändert. '
          'Der aktuelle Stand wird vorher als Backup gesichert.',
      'Wiederherstellen',
    );
    if (!ok || !mounted) return;
    await _guard((c) async {
      try {
        // Read first: the safety backup may rotate this file away.
        final bytes = await b.file.readAsBytes();
        final repo = c.read(repositoryProvider);
        if ((await repo.watchTrips().first).isNotEmpty) await c.read(autoBackupProvider)?.createNow();
        final ids = await Backup.importAny(repo, bytes, replace: true);
        // Undo snapshots belong to the replaced state.
        final undo = c.read(undoProvider.notifier);
        for (final id in ids) {
          undo.forget(id);
        }
        if (mounted) {
          showSnack(context, ids.length == 1 ? 'Eine Reise wiederhergestellt' : '${ids.length} Reisen wiederhergestellt');
        }
      } catch (e) {
        if (mounted) showSnack(context, 'Wiederherstellen fehlgeschlagen: $e');
      }
    });
  }

  Future<void> _saveAs(BackupFile b) async {
    try {
      final uri = await FilePicker.saveFile(
        fileName: p.basename(b.file.path),
        bytes: await b.file.readAsBytes(),
        mimeType: 'application/zip',
        dialogTitle: 'Backup speichern',
      );
      if (uri != null && mounted) showSnack(context, 'Backup gespeichert');
    } catch (e) {
      if (mounted) showSnack(context, 'Speichern fehlgeschlagen: $e');
    }
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, textAlign: TextAlign.center),
      );
}
