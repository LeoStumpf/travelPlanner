import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository.dart';
import '../../state/providers.dart';
import '../common/dialogs.dart';

/// Deleted trips: restore them or delete them for good. Trips older than
/// [Repository.trashRetention] are purged on app start.
class TrashPage extends ConsumerWidget {
  const TrashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trash = ref.watch(trashProvider);
    final list = trash.value ?? const <TrashedTrip>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Papierkorb'),
        actions: [
          if (list.isNotEmpty)
            TextButton(onPressed: () => _emptyAll(context, ref, list), child: const Text('Leeren')),
        ],
      ),
      body: trash.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (list) => list.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Der Papierkorb ist leer.\nGelöschte Reisen bleiben hier 30 Tage, dann werden sie endgültig entfernt.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [for (final t in list) _TrashTile(entry: t)],
              ),
      ),
    );
  }

  Future<void> _emptyAll(BuildContext context, WidgetRef ref, List<TrashedTrip> list) async {
    final ok = await confirm(
      context,
      'Papierkorb leeren?',
      '${list.length == 1 ? 'Eine Reise wird' : '${list.length} Reisen werden'} mit allen Orten, Notizen und Anhängen endgültig gelöscht.',
      'Endgültig löschen',
    );
    if (!ok) return;
    for (final t in list) {
      await _deleteForGood(ref, t.trip.id);
    }
  }
}

Future<void> _deleteForGood(WidgetRef ref, String tripId) async {
  await ref.read(repositoryProvider).deleteTrip(tripId);
  ref.read(undoProvider.notifier).forget(tripId);
}

/// "in 3 Tagen" / "morgen" / "heute" until [purgeAt].
String purgeHint(DateTime purgeAt, DateTime now) {
  // Rounded, so a daylight saving switch does not cost a day.
  final days = (purgeAt.difference(now).inMinutes / Duration.minutesPerDay).round();
  if (days <= 0) return 'Wird beim nächsten Start endgültig gelöscht';
  if (days == 1) return 'Wird morgen endgültig gelöscht';
  return 'Wird in $days Tagen endgültig gelöscht';
}

class _TrashTile extends ConsumerWidget {
  final TrashedTrip entry;
  const _TrashTile({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = entry.trip;
    final d = entry.deletedAt;
    String two(int n) => n.toString().padLeft(2, '0');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(trip.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text('Gelöscht am ${two(d.day)}.${two(d.month)}.${d.year}\n'
            '${purgeHint(entry.purgeAt, DateTime.now())}'),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Wiederherstellen',
              icon: const Icon(Icons.restore_from_trash),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await ref.read(repositoryProvider).restoreFromTrash(trip.id);
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text('„${trip.title}“ wiederhergestellt')));
              },
            ),
            IconButton(
              tooltip: 'Endgültig löschen',
              icon: const Icon(Icons.delete_forever),
              onPressed: () async {
                final ok = await confirm(
                  context,
                  '„${trip.title}“ endgültig löschen?',
                  'Alle Orte, Notizen und Anhänge dieser Reise werden entfernt. Das lässt sich nicht rückgängig machen.',
                  'Endgültig löschen',
                );
                if (ok) await _deleteForGood(ref, trip.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}
