import 'package:flutter/material.dart';

import '../../domain/models.dart';

/// Colours per planning layer; shared by timeline, map and canvas so the
/// same thing looks the same everywhere.
Color kindColor(ItemKind k) => switch (k) {
      // Slightly darker than the trip line green so white text on it
      // reaches 4.5:1 (WCAG AA).
      ItemKind.stay => const Color(0xFF00806A),
      ItemKind.transport => const Color(0xFF1F5FD1),
      ItemKind.accommodation => const Color(0xFF8B3FBF),
      ItemKind.activity => const Color(0xFFC2410C),
    };

String kindHex(ItemKind k) => '#${(kindColor(k).toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

IconData kindIcon(ItemKind k) => switch (k) {
      ItemKind.stay => Icons.place,
      ItemKind.transport => Icons.train,
      ItemKind.accommodation => Icons.bed,
      ItemKind.activity => Icons.local_activity,
    };

IconData modeIcon(TransportMode? m) => switch (m) {
      TransportMode.train => Icons.train,
      TransportMode.bus => Icons.directions_bus,
      TransportMode.plane => Icons.flight,
      TransportMode.ferry => Icons.directions_boat,
      TransportMode.car => Icons.directions_car,
      TransportMode.taxi => Icons.local_taxi,
      TransportMode.walk => Icons.directions_walk,
      _ => Icons.commute,
    };

IconData itemIcon(PlanItem i) => i.kind == ItemKind.transport ? modeIcon(i.mode) : kindIcon(i.kind);

/// Options and ideas are only tentative; they are drawn with a dashed
/// outline and their status icon, not just paler (see [tentativeFill]).
bool isTentative(PlanItem i) => i.isOption || i.status == ItemStatus.idea;

/// Opaque light tint of [base] for tentative blocks/nodes, so text contrast
/// does not depend on what lies behind (e.g. night shading).
Color tentativeFill(Color base, Brightness b) =>
    Color.alphaBlend(base.withValues(alpha: b == Brightness.dark ? 0.3 : 0.16), b == Brightness.dark ? const Color(0xFF0B0D12) : Colors.white);

/// Text/icon colour on [tentativeFill]: white in dark mode, a darkened
/// [base] in light mode (>= 4.5:1 for every layer colour).
Color tentativeInk(Color base, Brightness b) =>
    b == Brightness.dark ? Colors.white : Color.lerp(base, Colors.black, 0.3)!;

IconData statusIcon(ItemStatus s) => switch (s) {
      ItemStatus.idea => Icons.lightbulb_outline,
      ItemStatus.option => Icons.help_outline,
      ItemStatus.planned => Icons.event_available,
      ItemStatus.booked => Icons.verified,
    };

/// Keep-like note colours (0 = default surface).
const noteColors = <int>[
  0,
  0xFFFFF59D,
  0xFFFFCCBC,
  0xFFC8E6C9,
  0xFFBBDEFB,
  0xFFE1BEE7,
  0xFFF8BBD0,
  0xFFD7CCC8,
];

/// Note colours are pastel; in dark mode they're toned down.
Color noteBackground(BuildContext context, int color) {
  final scheme = Theme.of(context).colorScheme;
  if (color == 0) return scheme.surfaceContainerHigh;
  final c = Color(color);
  if (Theme.of(context).brightness == Brightness.dark) {
    return Color.alphaBlend(c.withValues(alpha: 0.28), scheme.surfaceContainer);
  }
  return c;
}

/// Trip line colours (like metro lines).
const tripColors = <int>[
  0xFF00876A,
  0xFF1F5FD1,
  0xFF8B3FBF,
  0xFFC2410C,
  0xFFD6336C,
  0xFF0B7285,
  0xFF5C677D,
];
