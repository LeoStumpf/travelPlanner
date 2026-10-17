import 'package:flutter/material.dart';

import 'l10n.dart';

void showSnack(BuildContext context, String text, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), action: action));
}

/// Shows [text] with an "Undo" action. Takes the messenger instead of a
/// context, so callers can grab it before the widget that deleted something is gone.
void showUndoSnack(ScaffoldMessengerState messenger, String text, VoidCallback onUndo) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      action: SnackBarAction(label: messenger.context.l10n.undo, onPressed: onUndo),
    ));
}

/// Asks [title]; the confirming button says [ok] (default "Delete").
Future<bool> confirm(BuildContext context, String title, [String? body, String? ok]) async {
  final l = context.l10n;
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok ?? l.delete)),
      ],
    ),
  );
  return r ?? false;
}

Future<String?> promptText(BuildContext context, String title,
    {String initial = '', String hint = '', TextInputType? keyboard}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: keyboard,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(c, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(c.l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: Text(c.l10n.ok)),
      ],
    ),
  );
}

enum LeaveChoice { save, discard, keepEditing }

/// Asks what to do with unsaved changes when leaving an editor.
/// Dismissing the dialog counts as [LeaveChoice.keepEditing].
Future<LeaveChoice> askLeave(BuildContext context) async {
  final l = context.l10n;
  final r = await showDialog<LeaveChoice>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(l.unsavedChangesTitle),
      content: Text(l.unsavedChangesBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, LeaveChoice.keepEditing), child: Text(l.keepEditing)),
        TextButton(onPressed: () => Navigator.pop(c, LeaveChoice.discard), child: Text(l.discard)),
        FilledButton(onPressed: () => Navigator.pop(c, LeaveChoice.save), child: Text(l.save)),
      ],
    ),
  );
  return r ?? LeaveChoice.keepEditing;
}
