import 'package:flutter/material.dart';

import '../../domain/models.dart';

/// Colours per planning layer; shared by timeline, map and canvas so the
/// same thing looks the same everywhere.
Color kindColor(ItemKind k) => switch (k) {
      ItemKind.stay => const Color(0xFF2E7D6B),
      ItemKind.transport => const Color(0xFF3F6FD8),
      ItemKind.accommodation => const Color(0xFF8E5BC8),
      ItemKind.activity => const Color(0xFFE08A1E),
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

const tripColors = <int>[
  0xFF2E7D6B,
  0xFFD9822B,
  0xFF3F6FD8,
  0xFF8E5BC8,
  0xFFC0392B,
  0xFF16A085,
  0xFF7F8C8D,
];
