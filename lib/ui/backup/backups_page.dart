import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../data/auto_backup.dart';
import '../../data/backup.dart';
import '../../state/providers.dart';
import '../common/dialogs.dart';
import '../common/l10n.dart';

/// "Last backup: …" for the trip list menu.
String lastBackupLabel(AppLocalizations l, List<BackupFile>? backups) {
  final last = backups?.firstOrNull;
  return last == null ? l.noBackupYet : l.lastBackup(l.dateTime(last.createdAt));
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
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.backupsTitle),
        actions: [
          IconButton(
            tooltip: l.backupNow,
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
            title: Text(lastBackupLabel(l, backups.value), style: theme.textTheme.titleMedium),
            subtitle: Text(l.backupsExplanation(AutoBackup.keep, auto == null ? '' : ' (${auto.dir.path})')),
          ),
          const SizedBox(height: 8),
          ...switch (backups) {
            AsyncData(:final value) when value.isEmpty => [_Hint(l.noAutoBackups)],
            AsyncData(:final value) => [for (final b in value) _tile(b)],
            AsyncError(:final error) => [_Hint(l.errorWith('$error'))],
            _ => [const Center(child: CircularProgressIndicator())],
          },
        ],
      ),
    );
  }

  Widget _tile(BackupFile b) {
    final size = b.file.existsSync() ? b.file.lengthSync() : 0;
    final l = context.l10n;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.inventory_2_outlined),
        title: Text(l.dateTime(b.createdAt)),
        subtitle: Text(formatBytes(size, l.localeName)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: l.restore,
              icon: const Icon(Icons.settings_backup_restore),
              onPressed: _busy ? null : () => _restore(b),
            ),
            IconButton(
              tooltip: l.saveAs,
              icon: const Icon(Icons.save_alt),
              onPressed: _busy ? null : () => _saveAs(b),
            ),
          ],
        ),
      ),
    );
  }


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
          if (mounted) showSnack(context, context.l10n.backupCreated);
        } catch (e) {
          if (mounted) showSnack(context, context.l10n.backupFailed(context.l10n.error(e)));
        }
      });

  Future<void> _restore(BackupFile b) async {
    final l = context.l10n;
    final ok = await confirm(
      context,
      l.restoreBackupQuestion,
      l.restoreBackupBody(l.dateTime(b.createdAt)),
      l.restore,
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
          showSnack(context, l.tripsRestored(ids.length));
        }
      } catch (e) {
        if (mounted) showSnack(context, l.restoreFailed(l.error(e)));
      }
    });
  }

  Future<void> _saveAs(BackupFile b) async {
    final l = context.l10n;
    try {
      final uri = await FilePicker.saveFile(
        fileName: p.basename(b.file.path),
        bytes: await b.file.readAsBytes(),
        mimeType: 'application/zip',
        dialogTitle: l.saveBackupDialog,
      );
      if (uri != null && mounted) showSnack(context, l.backupSaved);
    } catch (e) {
      if (mounted) showSnack(context, l.saveFailed('$e'));
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
