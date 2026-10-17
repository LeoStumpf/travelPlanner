// Accessibility helpers: what screen readers announce for plan items, the
// custom actions that replace drag gestures, and 48 dp colour swatches.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/analysis.dart';
import '../../domain/models.dart';
import '../../domain/time.dart';
import '../../domain/zones.dart';
import '../../state/providers.dart';
import 'dialogs.dart';
import 'item_sheet.dart';
import 'l10n.dart';
import 'style.dart';

/// Minimum touch target (Material / Android accessibility guideline).
const minTapTarget = 48.0;

/// "Kandy, Ort, 3 Nächte, Mi., 12. März 15:00 → Sa., 15. März 10:00,
/// Option, Fix, Konflikt": everything a sighted user reads off a block or
/// node, in one sentence.
String itemSemanticsLabel(
  AppLocalizations l,
  PlanItem item, {
  DateTime? tripStart,
  bool conflict = false,
  bool selected = false,
}) {
  final title = item.title.trim().isEmpty ? l.kind(item.kind) : item.title.trim();
  final hasNights = item.kind == ItemKind.stay || item.kind == ItemKind.accommodation;
  return [
    title,
    l.kind(item.kind),
    if (item.mode != null && item.kind == ItemKind.transport) l.mode(item.mode!),
    if (item.isScheduled && hasNights && nightsIn(item.start!, item.end!) > 0)
      l.nights(nightsIn(item.start!, item.end!)),
    if (item.isScheduled)
      '${l.moment(tripStart, item.start!)} → ${l.moment(tripStart, item.end!)}'
    else
      l.notScheduledYet,
    if (item.status != ItemStatus.planned) l.status(item.status),
    if (item.fixed) l.fixedChip,
    if (conflict) l.a11yConflict,
    if (selected) l.a11ySelected,
  ].join(', ');
}

/// "1 Tag früher" / "1 Tag später" as custom semantics actions: the
/// screen-reader way to do what a long-press drag does. Empty for fixed or
/// unscheduled items. Each action is one undoable step (see
/// [shiftItemDays]).
Map<CustomSemanticsAction, VoidCallback> itemShiftActions(
  BuildContext context,
  WidgetRef ref,
  TripData data,
  PlanItem item,
) {
  if (!item.isScheduled || item.fixed) return const {};
  final l = context.l10n;
  // Like after a drag, a snack (read out by screen readers) says what moved
  // along and offers undo; without it the shift would happen silently.
  Future<void> shift(int days) async {
    final actions = ref.read(planActionsProvider);
    final (label, r) = await shiftItemDays(l, ref, data, item, days);
    if (!context.mounted || r.changedIds.isEmpty) return;
    final others = r.changedIds.length - 1;
    final conflicts = findConflicts(r.items, zones: data.zones).length;
    showSnack(
      context,
      [label, if (others > 0) l.othersMovedAlong(others), if (conflicts > 0) l.conflictsCount(conflicts)].join(' · '),
      action: SnackBarAction(label: l.undo, onPressed: () => actions.undo(data.trip.id)),
    );
  }

  return {
    CustomSemanticsAction(label: l.a11yDayEarlier): () => shift(-1),
    CustomSemanticsAction(label: l.a11yDayLater): () => shift(1),
  };
}

/// Spoken name of a note/trip colour from [noteColors] / [tripColors].
String colorName(AppLocalizations l, int color) => switch (color) {
  0 => l.colorDefault,
  0xFFFFF59D => l.colorYellow,
  0xFFFFCCBC || 0xFFC2410C => l.colorOrange,
  0xFFC8E6C9 || 0xFF00876A => l.colorGreen,
  0xFFBBDEFB || 0xFF1F5FD1 => l.colorBlue,
  0xFFE1BEE7 || 0xFF8B3FBF => l.colorPurple,
  0xFFF8BBD0 || 0xFFD6336C => l.colorPink,
  0xFFD7CCC8 => l.colorBrown,
  0xFF0B7285 => l.colorTeal,
  0xFF5C677D => l.colorGrey,
  _ => '#${(color & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
};

/// A round colour choice with a full 48 dp touch target and a spoken name
/// ("Farbe: Gelb", selected or not).
class ColorSwatchButton extends StatelessWidget {
  final int color;
  final Color fill;
  final bool selected;
  final Color checkColor;
  final VoidCallback onTap;
  final double radius;

  const ColorSwatchButton({
    super.key,
    required this.color,
    required this.fill,
    required this.selected,
    required this.onTap,
    this.checkColor = Colors.black54,
    this.radius = 15,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: context.l10n.a11yColor(colorName(context.l10n, color)),
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: minTapTarget / 2,
        child: SizedBox.square(
          dimension: minTapTarget,
          child: Center(
            child: Container(
              width: radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                // The selected one gets a ring, not only the check mark.
                border: Border.all(
                  color: selected ? scheme.onSurface : scheme.outlineVariant,
                  width: selected ? 2.5 : 1,
                ),
              ),
              child: selected ? Icon(Icons.check, size: 16, color: checkColor) : null,
            ),
          ),
        ),
      ),
    );
  }
}
