import 'package:flutter/material.dart';

import '../../domain/zones.dart';
import 'l10n.dart';

/// Result of [pickTimeZone]; [zone] null = no own zone (or automatic).
typedef ZoneChoice = ({String? zone});

/// A list tile showing a zone setting; tapping opens [pickTimeZone].
/// [noneLabel] describes the null choice ("None", "Automatic (Asia/Colombo)").
class ZoneTile extends StatelessWidget {
  final String label;
  final String? zone;
  final String noneLabel;
  final String? subtitle;

  /// Zones offered first (those already used in the trip).
  final List<String> suggestions;
  final ValueChanged<String?> onChanged;

  const ZoneTile({
    super.key,
    required this.label,
    required this.zone,
    required this.noneLabel,
    required this.onChanged,
    this.subtitle,
    this.suggestions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final z = zone;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.public),
      title: Text(label),
      subtitle: Text([z == null ? noneLabel : zoneLabel(z), ?subtitle].join('\n')),
      trailing: z == null
          ? null
          : IconButton(
              tooltip: noneLabel,
              icon: const Icon(Icons.clear),
              onPressed: () => onChanged(null),
            ),
      onTap: () async {
        final r = await pickTimeZone(context, current: z, noneLabel: noneLabel, suggestions: suggestions);
        if (r != null) onChanged(r.zone);
      },
    );
  }
}

/// "Asia/Colombo (UTC+5:30)", the offset as of now.
String zoneLabel(String zone) => '$zone (${formatUtcOffset(zoneOffsetAt(zone, DateTime.now().toUtc()))})';

/// Lets the user search and pick an IANA zone. Returns null when cancelled.
Future<ZoneChoice?> pickTimeZone(
  BuildContext context, {
  String? current,
  required String noneLabel,
  List<String> suggestions = const [],
}) =>
    showDialog<ZoneChoice>(
      context: context,
      builder: (_) => _ZonePickerDialog(current: current, noneLabel: noneLabel, suggestions: suggestions),
    );

class _ZonePickerDialog extends StatefulWidget {
  final String? current;
  final String noneLabel;
  final List<String> suggestions;
  const _ZonePickerDialog({this.current, required this.noneLabel, required this.suggestions});

  @override
  State<_ZonePickerDialog> createState() => _ZonePickerDialogState();
}

class _ZonePickerDialogState extends State<_ZonePickerDialog> {
  final _query = TextEditingController();
  late final List<String> _all = allZoneNames();
  final _now = DateTime.now().toUtc();
  final _offsets = <String, String>{};

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  String _offset(String z) => _offsets.putIfAbsent(z, () => formatUtcOffset(zoneOffsetAt(z, _now)));

  /// Matches "colombo", "ho chi", "asia/col" or an offset like "+5:30".
  bool _matches(String zone, String q) {
    if (q.isEmpty) return true;
    final name = zone.toLowerCase().replaceAll('_', ' ');
    return name.contains(q) || _offset(zone).toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final q = _query.text.trim().toLowerCase().replaceAll('_', ' ');
    final suggested = [for (final z in widget.suggestions.toSet()) if (_matches(z, q)) z];
    final all = [for (final z in _all) if (_matches(z, q)) z];

    Widget zoneTile(String z) => ListTile(
          key: ValueKey('zone-$z'),
          dense: true,
          title: Text(zoneCity(z)),
          subtitle: Text(z),
          trailing: Text(_offset(z)),
          selected: z == widget.current,
          onTap: () => Navigator.pop(context, (zone: z)),
        );
    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(text, style: Theme.of(context).textTheme.labelMedium),
        );

    return AlertDialog(
      title: Text(l.pickTimeZone),
      contentPadding: const EdgeInsets.only(top: 12),
      content: SizedBox(
        width: 360,
        height: 440,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const ValueKey('zone-search'),
              controller: _query,
              autofocus: true,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l.searchTimeZone),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: ListView(children: [
              if (q.isEmpty)
                ListTile(
                  key: const ValueKey('zone-none'),
                  dense: true,
                  leading: const Icon(Icons.block),
                  title: Text(widget.noneLabel),
                  selected: widget.current == null,
                  onTap: () => Navigator.pop(context, (zone: null)),
                ),
              if (suggested.isNotEmpty) ...[header(l.zonesInTrip), for (final z in suggested) zoneTile(z)],
              if (suggested.isNotEmpty && all.isNotEmpty) header(l.allZones),
              for (final z in all) zoneTile(z),
              if (all.isEmpty)
                Padding(padding: const EdgeInsets.all(16), child: Text(l.noZoneMatches)),
            ]),
          ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel))],
    );
  }
}
