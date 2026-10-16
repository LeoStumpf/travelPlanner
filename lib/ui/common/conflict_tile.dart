import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/analysis.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import 'dialogs.dart';

/// A conflict with its one-tap fix (if there is one).
class ConflictTile extends ConsumerWidget {
  final Conflict conflict;
  final TripData data;
  final VoidCallback? onTap;
  final VoidCallback? onFixed;

  const ConflictTile({super.key, required this.conflict, required this.data, this.onTap, this.onFixed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = Theme.of(context).colorScheme.error;
    final fix = conflict.fix;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(Icons.warning_amber, color: error),
      title: Text(conflict.message, style: TextStyle(color: error)),
      subtitle: fix == null
          ? null
          : Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.auto_fix_high, size: 18),
                label: Text(fix.label),
                onPressed: () async {
                  final actions = ref.read(planActionsProvider);
                  await actions.saveItems(data, fix.apply(data.items), fix.label);
                  onFixed?.call();
                  if (context.mounted) {
                    showSnack(
                      context,
                      'Behoben: ${fix.label}',
                      action: SnackBarAction(label: 'Rückgängig', onPressed: () => actions.undo(data.trip.id)),
                    );
                  }
                },
              ),
            ),
      onTap: onTap,
    );
  }
}
