import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/analysis.dart';
import '../../domain/map_offline.dart';
import '../../domain/models.dart';
import '../../domain/zones.dart';
import '../common/item_sheet.dart';
import '../common/l10n.dart';
import '../common/navigation.dart';
import '../common/style.dart';

/// The trip's places as a list, for when the map can't be shown: the stays
/// in route order, each followed by its lodging and activities, then
/// everything else. Tapping opens the item sheet; the pin button hands the
/// coordinates to a maps app, which may have its own offline maps.
class PlacesList extends ConsumerWidget {
  final TripData data;
  final ScrollController? controller;
  final bool shrinkWrap;
  const PlacesList({super.key, required this.data, this.controller, this.shrinkWrap = false});

  /// Grouped order with indentation depth.
  static List<(PlanItem, int)> ordered(TripData data) {
    final chain = stayChain(data.items, zones: data.zones);
    final stays = [
      ...chain,
      for (final s in data.items)
        if (s.kind == ItemKind.stay && !chain.contains(s)) s,
    ];
    final out = <(PlanItem, int)>[];
    final seen = <String>{};
    for (final s in stays) {
      out.add((s, 0));
      seen.add(s.id);
      for (final c in data.items.where((i) => i.parentId == s.id && i.kind != ItemKind.transport)) {
        out.add((c, 1));
        seen.add(c.id);
      }
    }
    for (final i in data.items) {
      if (i.kind != ItemKind.transport && !seen.contains(i.id)) out.add((i, 0));
    }
    return out;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final rows = ordered(data);
    final chain = stayChain(data.items, zones: data.zones);
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l.placesListEmpty, textAlign: TextAlign.center),
      );
    }
    return ListView(
      controller: controller,
      shrinkWrap: shrinkWrap,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        for (final (i, depth) in rows)
          () {
            final pos = itemPosition(data, i);
            final n = chain.indexWhere((s) => s.id == i.id);
            final where = i.placeName?.trim().isNotEmpty == true
                ? i.placeName!
                : pos == null
                ? l.mapNoCoordinates
                : '${pos.$1.toStringAsFixed(4)}, ${pos.$2.toStringAsFixed(4)}';
            return ListTile(
              key: ValueKey('place-${i.id}'),
              contentPadding: EdgeInsets.only(left: 16.0 + depth * 24, right: 4),
              leading: Icon(itemIcon(i), color: kindColor(i.kind)),
              title: Text(n >= 0 ? '${n + 1}. ${i.title}' : i.title),
              subtitle: Text(where, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: pos == null
                  ? null
                  : IconButton(
                      tooltip: l.mapOpenInMapsApp,
                      icon: const Icon(Icons.directions_outlined),
                      onPressed: () => openNavigation(context, ref, data, i),
                    ),
              onTap: () => showItemSheet(context, ref, data.trip.id, i.id),
            );
          }(),
      ],
    );
  }
}
