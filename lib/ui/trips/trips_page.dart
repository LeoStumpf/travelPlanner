import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/backup.dart';
import '../../domain/demo.dart';
import '../../domain/models.dart';
import '../../domain/time.dart';
import '../../state/providers.dart';
import '../common/dialogs.dart';
import '../common/route_line.dart';
import '../exchange/plan_exchange_ui.dart';
import '../trip/trip_page.dart';
import 'trip_settings_dialog.dart';

class TripsPage extends ConsumerWidget {
  const TripsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Reisen'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => switch (v) {
              'import' => _import(context, ref),
              'claude' => showPlanExchangeSheet(context, ref, null),
              'demo' => _loadDemos(context, ref),
              _ => null,
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'claude',
                child: ListTile(
                  leading: Icon(Icons.auto_fix_high),
                  title: Text('Mit Claude planen …'),
                ),
              ),
              PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.file_open),
                  title: Text('Backup importieren'),
                ),
              ),
              PopupMenuItem(
                value: 'demo',
                child: ListTile(
                  leading: Icon(Icons.auto_awesome),
                  title: Text('Beispielreisen laden'),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Neue Reise'),
      ),
      body: trips.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (list) => list.isEmpty
            ? _Empty(onDemo: () => _loadDemos(context, ref))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [for (final t in list) _TripTile(trip: t)],
              ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final trip = await showTripSettingsDialog(context, null);
    if (trip == null) return;
    await ref.read(repositoryProvider).saveTrip(trip);
    if (context.mounted) openTrip(context, ref, trip.id);
  }

  Future<void> _loadDemos(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(repositoryProvider);
    await repo.putTripData(demoSriLanka());
    await repo.putTripData(demoInterrail());
    if (context.mounted) showSnack(context, 'Zwei Beispielreisen angelegt');
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final f = await FilePicker.pickFile(
      dialogTitle: 'Backup wählen',
      type: FileType.any,
    );
    if (f == null) return;
    try {
      final bytes = await f.xFile.readAsBytes();
      final id = await Backup.importZip(ref.read(repositoryProvider), bytes);
      if (context.mounted) openTrip(context, ref, id);
    } catch (e) {
      if (context.mounted) showSnack(context, 'Import fehlgeschlagen: $e');
    }
  }
}

void openTrip(BuildContext context, WidgetRef ref, String tripId) {
  ref.read(tripUiProvider.notifier).reset();
  Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => TripPage(tripId: tripId)));
}

class _TripTile extends ConsumerWidget {
  final Trip trip;
  const _TripTile({required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(tripDataProvider(trip.id)).value;
    final stays =
        data?.items
            .where((i) => i.kind == ItemKind.stay && i.isScheduled)
            .toList() ??
        [];
    stays.sort((a, b) => a.start!.compareTo(b.start!));
    final days = trip.plannedDays ?? (stays.isEmpty ? null : lastDayOf(stays.last.end!) + 1);
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () => openTrip(context, ref, trip.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(trip.title, style: theme.textTheme.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  if (days != null) SignalPill(pluralDays(days)),
                  PopupMenuButton<String>(
                    onSelected: (v) => _menu(context, ref, v),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                      PopupMenuItem(value: 'export', child: Text('Als Backup exportieren')),
                      PopupMenuItem(value: 'copy', child: Text('Duplizieren')),
                      PopupMenuItem(value: 'delete', child: Text('Löschen')),
                    ],
                  ),
                ],
              ),
              if (trip.startDate != null)
                Text(formatDay(trip.startDate, 0), style: theme.textTheme.labelMedium),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: stays.isEmpty
                    ? Text('Noch keine Orte geplant', style: theme.textTheme.bodyMedium)
                    : RouteLine(stations: [for (final s in stays) s.title], color: Color(trip.color)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _menu(BuildContext context, WidgetRef ref, String v) async {
    final repo = ref.read(repositoryProvider);
    switch (v) {
      case 'edit':
        final t = await showTripSettingsDialog(context, trip);
        if (t != null) await ref.read(planActionsProvider).record(t.id, 'Reise bearbeitet', (r) => r.saveTrip(t));
      case 'export':
        await exportTrip(context, ref, trip);
      case 'copy':
        final bytes = await Backup.exportTrip(repo, trip.id);
        await Backup.importZip(repo, bytes);
      case 'delete':
        final ok = await confirm(
          context,
          'Reise „${trip.title}“ löschen?',
          'Alle Orte, Notizen und Anhänge dieser Reise werden entfernt.',
        );
        if (ok) {
          await repo.deleteTrip(trip.id);
          ref.read(undoProvider.notifier).forget(trip.id);
        }
    }
  }
}

Future<void> exportTrip(BuildContext context, WidgetRef ref, Trip trip) async {
  try {
    final bytes = await Backup.exportTrip(
      ref.read(repositoryProvider),
      trip.id,
    );
    final safe = trip.title.replaceAll(RegExp(r'[^\w\- äöüÄÖÜß]'), '_');
    final uri = await FilePicker.saveFile(
      fileName: '$safe.travelplan.zip',
      bytes: bytes,
      mimeType: 'application/zip',
      dialogTitle: 'Backup speichern',
    );
    if (uri != null && context.mounted) {
      showSnack(context, 'Backup gespeichert');
    }
  } catch (e) {
    if (context.mounted) showSnack(context, 'Export fehlgeschlagen: $e');
  }
}

class _Empty extends StatelessWidget {
  final VoidCallback onDemo;
  const _Empty({required this.onDemo});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.luggage,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Noch keine Reise geplant',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Lege eine neue Reise an oder schau dir zuerst die Beispiele an '
            '(Interrail Frankreich/Spanien und Sri Lanka).',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onDemo,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Beispielreisen laden'),
          ),
        ],
      ),
    ),
  );
}
