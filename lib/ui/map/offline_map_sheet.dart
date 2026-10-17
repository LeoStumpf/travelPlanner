import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/map_offline.dart';
import '../../domain/models.dart';
import '../../state/offline_map.dart';
import '../common/dialogs.dart';
import '../common/l10n.dart';

/// "Save map offline": what would be downloaded, the running download, or
/// what is saved, with delete. [online] false disables saving.
Future<void> showOfflineMapSheet(BuildContext context, TripData data, {bool? online}) => showModalBottomSheet(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => OfflineMapPanel(data: data, online: online),
);

class OfflineMapPanel extends ConsumerWidget {
  final TripData data;
  final bool? online;
  const OfflineMapPanel({super.key, required this.data, this.online});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final tripId = data.trip.id;
    final s = ref.watch(offlineMapProvider(tripId));
    final notifier = ref.read(offlineMapProvider(tripId).notifier);
    final plan = planOfflineMap(data);
    final covers = s.covers(placesBox(data));

    final children = <Widget>[
      Text(l.offlineMapTitle, style: theme.textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(l.offlineMapExplain),
      const SizedBox(height: 16),
    ];

    if (s.downloading) {
      children.addAll([
        LinearProgressIndicator(key: const ValueKey('offline-progress'), value: s.progress),
        const SizedBox(height: 8),
        Text(l.offlineMapProgress((s.progress! * 100).round(), formatBytes(s.downloadedBytes))),
        const SizedBox(height: 4),
        Text(l.offlineMapProgressHint, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(onPressed: notifier.cancel, icon: const Icon(Icons.close), label: Text(l.cancel)),
        ),
      ]);
    } else if (s.saved) {
      children.add(
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.offline_pin, color: theme.colorScheme.primary),
          title: Text(l.offlineMapSaved),
          subtitle: Text(l.offlineMapSavedInfo(s.savedAt == null ? '–' : l.dateTime(s.savedAt!), formatBytes(s.bytes))),
        ),
      );
      if (!covers) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(l.offlineMapOutdated, style: TextStyle(color: theme.colorScheme.error)),
          ),
        );
      }
    } else if (s.regionIds.isNotEmpty) {
      children.add(Text(l.offlineMapIncomplete, style: TextStyle(color: theme.colorScheme.error)));
    } else if (plan == null) {
      children.add(Text(l.mapNoPlaces));
    } else {
      children.add(Text(l.offlineMapEstimate(plan.tiles, formatBytes(plan.estimatedBytes))));
    }

    if (s.error != null && !s.downloading) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(l.offlineMapFailed(s.error!), style: TextStyle(color: theme.colorScheme.error)),
        ),
      );
    }
    if (online == false && !s.downloading && plan != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(l.offlineMapNeedsConnection, style: theme.textTheme.bodySmall),
        ),
      );
    }

    if (!s.downloading) {
      children.add(const SizedBox(height: 16));
      children.add(
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (s.regionIds.isNotEmpty)
              TextButton.icon(
                onPressed: () async {
                  final ok = await confirm(context, l.offlineMapDeleteConfirm, null, l.delete);
                  if (ok) await notifier.delete();
                },
                icon: const Icon(Icons.delete_outline),
                label: Text(l.offlineMapDelete),
              ),
            if (plan != null)
              FilledButton.icon(
                onPressed: online == false ? null : () => notifier.save(plan),
                icon: const Icon(Icons.download_for_offline_outlined),
                label: Text(s.saved ? l.offlineMapSaveAgain : l.offlineMapSave),
              ),
          ],
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}
