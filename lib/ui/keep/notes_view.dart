import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../domain/models.dart';
import '../../domain/search.dart';
import '../common/l10n.dart';
import '../editor/card_editor_page.dart';
import 'card_preview.dart';

/// Google-Keep-like masonry grid of notes, checklists, links and images.
class NotesView extends ConsumerStatefulWidget {
  final TripData data;
  const NotesView({super.key, required this.data});

  @override
  ConsumerState<NotesView> createState() => _NotesViewState();
}

class _NotesViewState extends ConsumerState<NotesView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final terms = searchTerms(_query);
    final cards = [
      for (final c in widget.data.cards)
        if (cardMatches(c, terms, files: widget.data.attachmentsOf(c.id))) c,
    ];
    final pinned = cards.where((c) => c.pinned).toList();
    final others = cards.where((c) => !c.pinned).toList();

    Widget grid(List<NoteCard> list) => SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 3 : 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childCount: list.length,
            itemBuilder: (_, k) => GestureDetector(
              onTap: () => openCardEditor(context, widget.data, card: list[k]),
              child: CardPreview(card: list[k], data: widget.data, tickable: true),
            ),
          ),
        );

    Widget header(String t) => SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Text(t, style: Theme.of(context).textTheme.labelLarge),
          ),
        );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: SearchBar(
              hintText: context.l10n.searchNotes,
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
        if (cards.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  // An empty result while searching is not an empty trip.
                  terms.isEmpty || widget.data.cards.isEmpty
                      ? context.l10n.notesEmpty
                      : context.l10n.searchNoResults(_query.trim()),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        if (pinned.isNotEmpty) ...[header(context.l10n.notesPinned), grid(pinned)],
        if (others.isNotEmpty) ...[if (pinned.isNotEmpty) header(context.l10n.notesOthers), grid(others)],
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }
}
