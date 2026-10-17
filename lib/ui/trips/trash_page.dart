import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository.dart';
import '../../state/providers.dart';
import '../common/dialogs.dart';
import '../common/l10n.dart';

/// Deleted trips: restore them or delete them for good. Trips older than
/// [Repository.trashRetention] are purged on app start.
class TrashPage extends ConsumerWidget {
  const TrashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trash = ref.watch(trashProvider);
    final list = trash.value ?? const <TrashedTrip>[];
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.trashTitle),
        actions: [
          if (list.isNotEmpty)
            TextButton(onPressed: () => _emptyAll(context, ref, list), child: Text(l.trashEmptyAction)),
        ],
      ),
      body: trash.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.errorWith('$e'))),
        data: (list) => list.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    l.trashIsEmpty,
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
    final l = context.l10n;
    final ok = await confirm(context, l.trashEmptyQuestion, l.trashEmptyBody(list.length), l.deleteForGood);
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

/// "in 3 days" / "tomorrow" / "on next start" until [purgeAt].
String purgeHint(AppLocalizations l, DateTime purgeAt, DateTime now) {
  // Rounded, so a daylight saving switch does not cost a day.
  final days = (purgeAt.difference(now).inMinutes / Duration.minutesPerDay).round();
  return l.trashPurgeHint(days < 0 ? 0 : days);
}

class _TrashTile extends ConsumerWidget {
  final TrashedTrip entry;
  const _TrashTile({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = entry.trip;
    final l = context.l10n;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(trip.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text('${l.trashDeletedOn(l.date(entry.deletedAt))}\n'
            '${purgeHint(l, entry.purgeAt, DateTime.now())}'),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: l.restore,
              icon: const Icon(Icons.restore_from_trash),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await ref.read(repositoryProvider).restoreFromTrash(trip.id);
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(l.tripRestored(trip.title))));
              },
            ),
            IconButton(
              tooltip: l.deleteForGood,
              icon: const Icon(Icons.delete_forever),
              onPressed: () async {
                final ok = await confirm(
                  context,
                  l.deleteTripForGoodQuestion(trip.title),
                  l.deleteTripForGoodBody,
                  l.deleteForGood,
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
