import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/hints.dart';
import 'l10n.dart';

/// Explains the hidden gestures of a view until the user taps "Got it".
/// [floating] draws a card for overlays on the map and canvas; otherwise a
/// flat strip that fits between a toolbar and the content.
class HintBanner extends ConsumerWidget {
  final Hint hint;
  final IconData icon;
  final bool floating;

  const HintBanner({
    super.key,
    required this.hint,
    this.icon = Icons.touch_app_outlined,
    this.floating = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(hintsProvider).contains(hint)) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final l = context.l10n;
    final text = switch (hint) {
      Hint.timeline => l.hintTimeline,
      Hint.map => l.hintMap,
      Hint.canvas => l.hintCanvas,
    };
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
          child: Text(l.gotIt),
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


