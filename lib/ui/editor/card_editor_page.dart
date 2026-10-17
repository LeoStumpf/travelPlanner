import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/link_preview.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../common/dialogs.dart';
import '../common/l10n.dart';
import '../common/style.dart';
import 'attachments_section.dart';
import 'item_editor_page.dart';

Future<void> openCardEditor(BuildContext context, TripData data, {NoteCard? card, CardType? newType}) =>
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CardEditorPage(
        tripId: data.trip.id,
        initial: card ??
            NoteCard(
              id: newId(),
              tripId: data.trip.id,
              type: newType ?? CardType.note,
              checklist: newType == CardType.checklist ? [ChecklistEntry(id: newId(), text: '')] : const [],
              createdAt: DateTime.now(),
            ),
        isNew: card == null,
      ),
    ));

/// Keep-style editor: changes are saved when leaving the page, and also when
/// the app goes to the background, so they survive the app being killed there.
class CardEditorPage extends ConsumerStatefulWidget {
  final String tripId;
  final NoteCard initial;
  final bool isNew;
  const CardEditorPage({super.key, required this.tripId, required this.initial, required this.isNew});

  @override
  ConsumerState<CardEditorPage> createState() => _CardEditorPageState();
}

class _CardEditorPageState extends ConsumerState<CardEditorPage> with WidgetsBindingObserver {
  late NoteCard _c = widget.initial;
  late final _title = TextEditingController(text: _c.title);
  late final _text = TextEditingController(text: _c.text);
  late final _url = TextEditingController(text: _c.url ?? '');
  final Map<String, TextEditingController> _entryCtrls = {};
  bool _deleted = false;
  bool _loadingPreview = false;
  // What is in the database for this card (json), null while a new card is not stored yet.
  late String? _storedJson = widget.isNew ? null : jsonEncode(widget.initial.toJson());
  // Saves run one after another so a background save and the save on leaving never overlap.
  Future<void> _saving = Future.value();
  // Kept from the last build, so saving works while the page is being popped.
  AppLocalizations? _l;

  TextEditingController _entryCtrl(ChecklistEntry e) =>
      _entryCtrls.putIfAbsent(e.id, () => TextEditingController(text: e.text));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) _persist();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _title.dispose();
    _text.dispose();
    _url.dispose();
    for (final c in _entryCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  NoteCard _collect() => _c.copyWith(
        title: _title.text.trim(),
        text: _text.text,
        url: _url.text.trim().isEmpty ? null : _normalizeUrl(_url.text.trim()),
        checklist: [
          for (final e in _c.checklist) e.copyWith(text: _entryCtrls[e.id]?.text ?? e.text),
        ],
      );

  static String _normalizeUrl(String u) => u.startsWith('http') ? u : 'https://$u';

  /// Stores the current state as one undo step, if it differs from what is stored.
  /// Everything is read synchronously, so it also works while the page is being popped.
  Future<void> _persist() {
    if (_deleted) return _saving;
    final c = _collect();
    final data = ref.read(tripDataProvider(widget.tripId)).value;
    final actions = ref.read(planActionsProvider);
    final hasAttachments = data?.attachmentsOf(c.id).isNotEmpty ?? false;
    final empty = c.title.isEmpty &&
        c.text.trim().isEmpty &&
        c.url == null &&
        c.checklist.every((e) => e.text.trim().isEmpty) &&
        !hasAttachments;
    final cleaned = c.copyWith(
      checklist: [for (final e in c.checklist) if (e.text.trim().isNotEmpty) e],
    );
    final json = jsonEncode(cleaned.toJson());
    final stored = _storedJson;
    final l = _l ?? context.l10n;
    final t = cleaned.title;
    Future<void> Function()? step;
    if (stored == null) {
      // A new card is only created once it has content.
      final label = t.isEmpty ? l.stepNoteCreated : l.stepCardCreated(t);
      if (!empty) step = () => actions.record(widget.tripId, label, (r) => r.saveCard(cleaned));
    } else if (widget.isNew && empty && data != null) {
      // A new card that was saved in the background and then emptied again goes away.
      step = () => actions.record(widget.tripId, l.stepNoteDiscarded, (r) => r.deleteCard(data, cleaned.id));
    } else if (json != stored) {
      // Leaving without changes must not add an undo step.
      final label = t.isEmpty ? l.stepNoteChanged : l.stepCardChanged(t);
      step = () => actions.record(widget.tripId, label, (r) => r.saveCard(cleaned));
    }
    if (step == null) return _saving;
    _storedJson = widget.isNew && empty ? null : json;
    return _saving = _saving.then((_) => step!()).catchError((Object e) => debugPrint('Saving card failed: $e'));
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(tripDataProvider(widget.tripId)).value;
    if (data == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final linked = data.item(_c.itemId);
    final l = _l = context.l10n;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _persist();
      },
      child: Scaffold(
        backgroundColor: noteBackground(context, _c.color),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(
              tooltip: _c.pinned ? l.unpin : l.pin,
              icon: Icon(_c.pinned ? Icons.push_pin : Icons.push_pin_outlined),
              onPressed: () => setState(() => _c = _c.copyWith(pinned: !_c.pinned)),
            ),
            PopupMenuButton<String>(
              onSelected: (v) => _menu(v, data),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'plan', child: Text(l.addToPlan)),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(_c.type == CardType.checklist ? l.convertToNote : l.convertToChecklist),
                ),
                PopupMenuItem(value: 'delete', child: Text(l.delete)),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            TextField(
              controller: _title,
              style: Theme.of(context).textTheme.titleLarge,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: l.titleHint, border: InputBorder.none),
            ),
            if (_c.type == CardType.link) ..._linkFields(),
            if (_c.type == CardType.checklist) ..._checklistFields() else
              TextField(
                controller: _text,
                autofocus: widget.isNew && _c.type == CardType.note,
                minLines: 4,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: l.cardNote, border: InputBorder.none),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final c in noteColors)
                  GestureDetector(
                    onTap: () => setState(() => _c = _c.copyWith(color: c)),
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: c == 0 ? Theme.of(context).colorScheme.surfaceContainerHighest : Color(c),
                      child: c == _c.color ? const Icon(Icons.check, size: 16, color: Colors.black54) : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: linked?.id,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.belongsToLabel, prefixIcon: const Icon(Icons.link)),
              items: [
                DropdownMenuItem(value: null, child: Text(l.nothingOption)),
                for (final i in data.items)
                  DropdownMenuItem(
                    value: i.id,
                    child: Row(children: [
                      Icon(itemIcon(i), size: 16, color: kindColor(i.kind)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(i.title, overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
              ],
              onChanged: (v) => setState(() => _c = _c.copyWith(itemId: v)),
            ),
            const SizedBox(height: 16),
            AttachmentsSection(tripId: widget.tripId, ownerId: _c.id, attachments: data.attachmentsOf(_c.id)),
          ],
        ),
      ),
    );
  }

  List<Widget> _linkFields() => [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(labelText: context.l10n.urlLabel, hintText: 'https://…'),
              onSubmitted: (_) => _fetchPreview(),
            ),
          ),
          IconButton(
            tooltip: context.l10n.loadPreview,
            onPressed: _loadingPreview ? null : _fetchPreview,
            icon: _loadingPreview
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: context.l10n.open,
            onPressed: _url.text.trim().isEmpty
                ? null
                : () => launchUrl(Uri.parse(_normalizeUrl(_url.text.trim())), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new),
          ),
        ]),
        if (_c.previewImageUrl != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(_c.previewImageUrl!, height: 160, fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink()),
            ),
          ),
        if (_c.previewTitle != null)
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(_c.previewTitle!, style: const TextStyle(fontSize: 12))),
      ];

  Future<void> _fetchPreview() async {
    final u = _url.text.trim();
    if (u.isEmpty) return;
    setState(() => _loadingPreview = true);
    try {
      final p = await fetchLinkPreview(_normalizeUrl(u));
      setState(() {
        _c = _c.copyWith(previewTitle: p.title, previewImageUrl: p.imageUrl);
        if (_title.text.trim().isEmpty && p.title != null) _title.text = p.title!;
      });
    } catch (_) {
      if (mounted) showSnack(context, context.l10n.previewFailed);
    } finally {
      if (mounted) setState(() => _loadingPreview = false);
    }
  }

  List<Widget> _checklistFields() {
    final open = [for (final e in _c.checklist) if (!e.done) e];
    final done = [for (final e in _c.checklist) if (e.done) e];
    Widget row(ChecklistEntry e) => Row(
          key: ValueKey(e.id),
          children: [
            Checkbox(
              value: e.done,
              onChanged: (v) => setState(() => _c = _c.copyWith(checklist: [
                    for (final x in _c.checklist) x.id == e.id ? x.copyWith(done: v ?? false, text: _entryCtrl(x).text) : x,
                  ])),
            ),
            Expanded(
              child: TextField(
                controller: _entryCtrl(e),
                autofocus: e.text.isEmpty && widget.isNew,
                style: e.done ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
                decoration: InputDecoration(border: InputBorder.none, hintText: context.l10n.entryHint),
                onSubmitted: (_) => _addEntry(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _c = _c.copyWith(checklist: [..._c.checklist]..removeWhere((x) => x.id == e.id))),
            ),
          ],
        );
    return [
      ...open.map(row),
      TextButton.icon(onPressed: _addEntry, icon: const Icon(Icons.add), label: Text(context.l10n.entryHint)),
      if (done.isNotEmpty) ...[
        Text(context.l10n.doneCount(done.length), style: Theme.of(context).textTheme.labelMedium),
        ...done.map(row),
      ],
    ];
  }

  void _addEntry() => setState(() {
        _c = _c.copyWith(checklist: [
          for (final e in _c.checklist) e.copyWith(text: _entryCtrls[e.id]?.text ?? e.text),
          ChecklistEntry(id: newId(), text: ''),
        ]);
      });

  Future<void> _menu(String v, TripData data) async {
    final l = context.l10n;
    switch (v) {
      case 'delete':
        if (widget.isNew && _storedJson == null) {
          _deleted = true;
          for (final a in data.attachmentsOf(_c.id)) {
            await ref.read(repositoryProvider).deleteAttachment(a);
          }
        } else if (await confirm(context, l.deleteNoteQuestion)) {
          if (!mounted) return;
          _deleted = true;
          final messenger = ScaffoldMessenger.of(context);
          final actions = ref.read(planActionsProvider);
          await _saving;
          await actions.record(widget.tripId, l.stepNoteDeleted, (r) => r.deleteCard(data, _c.id));
          final step = actions.lastStep(widget.tripId);
          showUndoSnack(messenger, l.stepNoteDeleted, () => actions.undoStep(widget.tripId, step));
        } else {
          return;
        }
        if (mounted) Navigator.pop(context);
      case 'toggle':
        setState(() {
          final c = _collect();
          if (c.type == CardType.checklist) {
            _text.text = c.checklist.map((e) => e.text).where((t) => t.isNotEmpty).join('\n');
            _c = c.copyWith(type: CardType.note, checklist: const []);
          } else {
            final lines = c.text.split('\n').where((line) => line.trim().isNotEmpty);
            _c = c.copyWith(type: CardType.checklist, checklist: [
              for (final line in lines) ChecklistEntry(id: newId(), text: line.trim()),
              if (lines.isEmpty) ChecklistEntry(id: newId(), text: ''),
            ]);
            _text.clear();
          }
        });
      case 'plan':
        final kind = await showDialog<ItemKind>(
          context: context,
          builder: (c) => SimpleDialog(
            title: Text(l.addToPlanAs),
            children: [
              for (final k in ItemKind.values)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(c, k),
                  child: Row(children: [Icon(kindIcon(k), color: kindColor(k)), const SizedBox(width: 12), Text(l.kind(k))]),
                ),
            ],
          ),
        );
        if (kind == null || !mounted) return;
        final id = await openItemEditor(context, data, newKind: kind, title: _title.text.trim());
        if (id != null) setState(() => _c = _c.copyWith(itemId: id));
    }
  }
}
