import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/hints.dart';

/// Explains the hidden gestures of a view until the user taps "Verstanden".
/// [floating] draws a card for overlays on the map and canvas; otherwise a
/// flat strip that fits between a toolbar and the content.
class HintBanner extends ConsumerWidget {
  final Hint hint;
  final String text;
  final IconData icon;
  final bool floating;

  const HintBanner({
    super.key,
    required this.hint,
    required this.text,
    this.icon = Icons.touch_app_outlined,
    this.floating = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(hintsProvider).contains(hint)) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      child: Row(children: [
        Icon(icon, color: scheme.onSecondaryContainer, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(color: scheme.onSecondaryContainer)),
        ),
        TextButton(
          onPressed: () => ref.read(hintsProvider.notifier).dismiss(hint),
          child: const Text('Verstanden'),
        ),
      ]),
    );
    return Material(
      key: ValueKey('hint-${hint.name}'),
      color: scheme.secondaryContainer,
      elevation: floating ? 3 : 0,
      borderRadius: floating ? BorderRadius.circular(12) : null,
      child: content,
    );
  }
}

const timelineHint = 'Block lange drücken und ziehen, um ihn zu verschieben. '
    'Tag-Kopf lange drücken, um an diesem Tag etwas hinzuzufügen. Mit zwei Fingern zoomen.';
const mapHint = 'Lange auf die Karte drücken, um dort einen Ort, eine Unterkunft oder eine Aktivität anzulegen.';
const canvasHint = 'Karten lange drücken und ziehen, um sie zu verschieben. Mit zwei Fingern zoomen.';
