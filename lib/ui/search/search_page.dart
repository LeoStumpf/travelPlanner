import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import '../../domain/search.dart';
import '../../state/providers.dart';
import '../common/item_sheet.dart';
import '../common/l10n.dart';
import '../common/style.dart';
import '../editor/card_editor_page.dart';
import '../trips/trips_page.dart';

/// Opens the global search. From inside a trip pass its [tripId]: the
/// search then starts in that trip and can widen to all trips.
Future<void> openSearch(BuildContext context, {String? tripId}) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => SearchPage(tripId: tripId)));

/// Searches plan items and notes of all trips (see domain/search.dart);
/// results are grouped by trip, a tap opens the trip and the item's sheet
/// or the card's editor.
class SearchPage extends ConsumerStatefulWidget {
  /// The trip the search was opened from, or null for the trip list.
  final String? tripId;
  const SearchPage({super.key, this.tripId});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _query = TextEditingController();
  late bool _allTrips = widget.tripId == null;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final corpus = ref.watch(searchCorpusProvider);
    final hasQuery = _query.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          key: const ValueKey('search-field'),
          controller: _query,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(hintText: l.searchHint, border: InputBorder.none),
          onChanged: (_) => setState(() {}),
        ),
        actions: [
          if (hasQuery)
            IconButton(
              tooltip: l.searchClear,
              icon: const Icon(Icons.close),
              onPressed: () => setState(_query.clear),
            ),
        ],
        bottom: widget.tripId == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(value: false, label: Text(l.searchScopeTrip), icon: const Icon(Icons.luggage)),
                      ButtonSegment(value: true, label: Text(l.searchScopeAll), icon: const Icon(Icons.travel_explore)),
                    ],
                    selected: {_allTrips},
                    onSelectionChanged: (s) => setState(() => _allTrips = s.single),
                  ),
                ),
              ),
      ),
      body: corpus.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.errorWith('$e'))),
        data: (trips) => hasQuery ? _results(context, trips) : _message(context, Icons.search, l.searchIntro),
      ),
    );
  }

  Widget _results(BuildContext context, List<TripData> all) {
    final l = context.l10n;
    final query = _query.text.trim();
    final trips = _allTrips ? all : [for (final d in all) if (d.trip.id == widget.tripId) d];
    final groups = searchTrips(trips, query, firstTripId: widget.tripId);
    if (groups.isEmpty) {
      return _message(
        context,
        Icons.search_off,
        l.searchNoResults(query),
        detail: l.searchNoResultsHint,
        action: _allTrips
            ? null
            : TextButton(onPressed: () => setState(() => _allTrips = true), child: Text(l.searchNoResultsTrip)),
      );
    }
    final terms = searchTerms(query);
    final byId = {for (final d in all) d.trip.id: d};
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final g in groups) ...[
          _TripHeader(group: g, onTap: () => _open(byId[g.trip.id]!)),
          for (final h in g.hits) _HitTile(hit: h, terms: terms, onTap: () => _open(byId[g.trip.id]!, hit: h)),
        ],
      ],
    );
  }

  Widget _message(BuildContext context, IconData icon, String text, {String? detail, Widget? action}) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(detail, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            ],
            if (action != null) ...[const SizedBox(height: 8), action],
          ],
        ),
      ),
    );
  }

  /// Closes the search and shows [data]'s trip – the trip page it was
  /// opened from, or freshly opened above the trip list – then the hit's
  /// item sheet or card editor. All synchronous: this page's ref is gone
  /// once the pop has finished.
  void _open(TripData data, {SearchHit? hit}) {
    final nav = Navigator.of(context);
    final ctx = nav.context;
    final ref = this.ref;
    final sameTrip = widget.tripId == data.trip.id;
    if (sameTrip) {
      nav.pop();
    } else {
      nav.popUntil((r) => r.isFirst);
      openTrip(ctx, ref, data.trip.id);
    }
    if (hit == null) return;
    if (hit.item != null) {
      showItemSheet(ctx, ref, data.trip.id, hit.item!.id);
    } else {
      if (!sameTrip) ref.read(tripUiProvider.notifier).setView(TripView.notes);
      openCardEditor(ctx, data, card: hit.card);
    }
  }
}

class _TripHeader extends StatelessWidget {
  final TripHits group;
  final VoidCallback onTap;
  const _TripHeader({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: Color(group.trip.color), shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  group.trip.title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                group.hits.isEmpty ? l.searchOpenTrip : l.searchHitCount(group.hits.length),
                style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _HitTile extends StatelessWidget {
  final SearchHit hit;
  final List<String> terms;
  final VoidCallback onTap;
  const _HitTile({required this.hit, required this.terms, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final item = hit.item;
    final card = hit.card;
    final title = hit.title.isEmpty ? l.cardType(card!.type) : hit.title;
    final String subtitle;
    if (hit.field != SearchField.title) {
      subtitle = '${l.searchField(hit.field)}: ${searchSnippet(hit.text, terms)}';
    } else if (item != null) {
      subtitle = [l.kind(item.kind), if ((item.placeName ?? '').isNotEmpty) item.placeName!].join(' · ');
    } else {
      subtitle = l.cardType(card!.type);
    }
    return ListTile(
      key: ValueKey('hit-${hit.id}'),
      leading: item != null
          ? Icon(itemIcon(item), color: kindColor(item.kind))
          : Icon(cardIcon(card!.type), color: theme.colorScheme.onSurfaceVariant),
      title: HighlightedText(title, terms: terms, maxLines: 1),
      subtitle: HighlightedText(subtitle, terms: terms, maxLines: 2),
      onTap: onTap,
    );
  }
}

/// [text] with the parts matching [terms] in bold on a tinted background.
class HighlightedText extends StatelessWidget {
  final String text;
  final List<String> terms;
  final int maxLines;
  const HighlightedText(this.text, {super.key, required this.terms, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mark = TextStyle(
      fontWeight: FontWeight.bold,
      backgroundColor: scheme.tertiaryContainer,
      color: scheme.onTertiaryContainer,
    );
    final spans = <TextSpan>[];
    var at = 0;
    for (final (from, to) in matchRanges(text, terms)) {
      if (from > at) spans.add(TextSpan(text: text.substring(at, from)));
      spans.add(TextSpan(text: text.substring(from, to), style: mark));
      at = to;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return Text.rich(TextSpan(children: spans), maxLines: maxLines, overflow: TextOverflow.ellipsis);
  }
}
