import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/plan_exchange.dart';
import '../common/l10n.dart';
import '../share/share_listener.dart';
import 'plan_exchange_ui.dart';

/// When the app comes back to the foreground with a plan in the clipboard
/// (copied from the Claude app), offers to import it. Each plan is offered
/// once; one already opened in the import dialog is not offered at all.
class ClipboardPlanListener extends ConsumerStatefulWidget {
  final Widget child;
  const ClipboardPlanListener({super.key, required this.child});

  @override
  ConsumerState<ClipboardPlanListener> createState() => _ClipboardPlanListenerState();
}

class _ClipboardPlanListenerState extends ConsumerState<ClipboardPlanListener> {
  late final AppLifecycleListener _lifecycle;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _check);
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      // hasStrings does not read the clip, so Android shows no "pasted"
      // notice while the clipboard holds nothing.
      if (!await Clipboard.hasStrings()) return;
      final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim() ?? '';
      if (text.isEmpty || !PlanExchange.looksLikePlan(text) || seenPlanTexts.contains(text.hashCode)) return;
      try {
        PlanExchange.parse(text);
      } on FormatException {
        return;
      }
      seenPlanTexts.add(text.hashCode);
      final context = navigatorKey.currentContext;
      if (!mounted || context == null || !context.mounted) return;
      final l = context.l10n;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(l.clipboardPlanFound),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: l.apply,
            onPressed: () {
              final ctx = navigatorKey.currentContext;
              if (ctx != null && ctx.mounted) importPlanText(ctx, ref, text);
            },
          ),
        ));
    } catch (e) {
      // The clipboard is a convenience; failing to read it is no error.
      debugPrint('Clipboard check failed: $e');
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
