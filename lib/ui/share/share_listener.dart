import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../domain/models.dart';
import '../../state/providers.dart';
import '../common/dialogs.dart';
import '../../domain/plan_exchange.dart';
import '../editor/card_editor_page.dart';
import '../exchange/plan_exchange_ui.dart';
import '../trips/trip_settings_dialog.dart';
import '../trips/trips_page.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// Receives links, text, screenshots and tickets shared from other apps
/// ("Teilen → Reiseplaner") and stores them as a card in a chosen trip.
class ShareListener extends ConsumerStatefulWidget {
  final Widget child;
  const ShareListener({super.key, required this.child});

  @override
  ConsumerState<ShareListener> createState() => _ShareListenerState();
}

class _ShareListenerState extends ConsumerState<ShareListener> {
  StreamSubscription<List<SharedMediaFile>>? _sub;

  @override
  void initState() {
    super.initState();
    if (!Platform.isAndroid && !Platform.isIOS) return;
    _sub = ReceiveSharingIntent.instance.getMediaStream().listen(_handle, onError: (_) {});
    ReceiveSharingIntent.instance.getInitialMedia().then((m) {
      _handle(m);
      ReceiveSharingIntent.instance.reset();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _handle(List<SharedMediaFile> media) async {
    if (media.isEmpty) return;
    // Wait for the first frame so a navigator exists on cold start.
    await WidgetsBinding.instance.endOfFrame;
    // A plan shared from a chat app (e.g. Claude) is imported, not stored.
    final plan = await _planText(media);
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    if (plan != null) {
      await importPlanText(context, ref, plan);
      return;
    }

    final tripId = await _chooseTrip(context);
    if (tripId == null) return;
    final repo = ref.read(repositoryProvider);
    final data = await repo.loadTrip(tripId);
    if (data == null) return;

    NoteCard? last;
    await ref.read(planActionsProvider).record(tripId, 'Geteilte Inhalte gespeichert', (_) async {
      for (final m in media) {
        last = await _store(data, m) ?? last;
      }
    });
    final ctx = navigatorKey.currentContext;
    final card = last;
    if (card == null || ctx == null || !ctx.mounted) return;
    openTrip(ctx, ref, tripId);
    ref.read(tripUiProvider.notifier).setView(TripView.notes);
    final fresh = await repo.loadTrip(tripId);
    final ctx2 = navigatorKey.currentContext;
    if (fresh != null && ctx2 != null && ctx2.mounted) {
      await openCardEditor(ctx2, fresh, card: fresh.card(card.id));
    }
  }

  Future<String?> _planText(List<SharedMediaFile> media) async {
    for (final m in media) {
      String? text;
      if (m.type == SharedMediaType.text || m.type == SharedMediaType.url) {
        text = m.path;
      } else if (m.type == SharedMediaType.file && RegExp(r'\.(json|md|txt)$', caseSensitive: false).hasMatch(m.path)) {
        try {
          text = await File(m.path).readAsString();
        } catch (_) {}
      }
      if (text != null && PlanExchange.looksLikePlan(text)) return text;
    }
    return null;
  }

  Future<NoteCard?> _store(TripData data, SharedMediaFile m) async {
    final repo = ref.read(repositoryProvider);
    final now = DateTime.now();
    switch (m.type) {
      case SharedMediaType.text:
      case SharedMediaType.url:
        final text = m.path.trim();
        final url = RegExp(r'https?://\S+').firstMatch(text)?.group(0);
        final rest = url == null ? text : text.replaceAll(url, '').trim();
        final card = NoteCard(
          id: newId(),
          tripId: data.trip.id,
          type: url != null ? CardType.link : CardType.note,
          title: url != null ? rest.split('\n').first : '',
          text: url != null ? '' : text,
          url: url,
          createdAt: now,
        );
        await repo.saveCard(card);
        return card;
      case SharedMediaType.image:
      case SharedMediaType.video:
      case SharedMediaType.file:
        final f = File(m.path);
        if (!await f.exists()) return null;
        final card = NoteCard(
          id: newId(),
          tripId: data.trip.id,
          type: m.type == SharedMediaType.image ? CardType.image : CardType.note,
          title: m.type == SharedMediaType.image ? '' : p.basename(m.path),
          text: m.message ?? '',
          createdAt: now,
        );
        final att = await repo.files.addBytes(
          tripId: data.trip.id,
          ownerId: card.id,
          bytes: await f.readAsBytes(),
          fileName: p.basename(m.path),
        );
        await repo.saveAttachment(att);
        await repo.saveCard(card);
        return card;
    }
  }

  Future<String?> _chooseTrip(BuildContext context) async {
    final trips = await ref.read(repositoryProvider).watchTrips().first;
    if (!context.mounted) return null;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('In welche Reise speichern?')),
            for (final t in trips)
              ListTile(
                leading: CircleAvatar(backgroundColor: Color(t.color), radius: 10),
                title: Text(t.title),
                onTap: () => Navigator.pop(c, t.id),
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Neue Reise …'),
              onTap: () => Navigator.pop(c, ''),
            ),
          ],
        ),
      ),
    );
    if (choice != '' || !context.mounted) return choice;
    final trip = await showTripSettingsDialog(context, null);
    if (trip == null) return null;
    await ref.read(repositoryProvider).saveTrip(trip);
    if (context.mounted) showSnack(context, 'Reise „${trip.title}“ angelegt');
    return trip.id;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
