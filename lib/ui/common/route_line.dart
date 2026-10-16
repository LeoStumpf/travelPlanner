import 'package:flutter/material.dart';

/// A trip's stays drawn as a transit line: evenly spaced stations with
/// their names underneath.
class RouteLine extends StatelessWidget {
  final List<String> stations;
  final Color color;

  const RouteLine({super.key, required this.stations, required this.color});

  @override
  Widget build(BuildContext context) {
    if (stations.isEmpty) return const SizedBox.shrink();
    final surface = Theme.of(context).colorScheme.surface;
    final label = Theme.of(context).textTheme.labelSmall;
    return LayoutBuilder(builder: (context, c) {
      final col = c.maxWidth / stations.length;
      return SizedBox(
        height: 40,
        child: Stack(
          children: [
            if (stations.length > 1)
              Positioned(
                left: col / 2,
                right: col / 2,
                top: 5,
                height: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            Row(
              children: [
                for (final s in stations)
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: color, width: 4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: label),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

/// Small yellow pill, e.g. "18 Tage".
class SignalPill extends StatelessWidget {
  final String text;
  const SignalPill(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xFFFFC21A), borderRadius: BorderRadius.circular(14)),
        child: Text(
          text,
          style: const TextStyle(color: Color(0xFF0B0D12), fontSize: 13, fontWeight: FontWeight.w800),
        ),
      );
}
