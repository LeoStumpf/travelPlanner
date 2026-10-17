import 'package:flutter/material.dart';

void showSnack(BuildContext context, String text, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), action: action));
}

/// Shows [text] with a "Rückgängig" action. Takes the messenger instead of a
/// context, so callers can grab it before the widget that deleted something is gone.
void showUndoSnack(ScaffoldMessengerState messenger, String text, VoidCallback onUndo) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      action: SnackBarAction(label: 'Rückgängig', onPressed: onUndo),
    ));
}

Future<bool> confirm(BuildContext context, String title, [String? body, String ok = 'Löschen']) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Abbrechen')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
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
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Abbrechen')),
        FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('OK')),
      ],
    ),
  );
}

enum LeaveChoice { save, discard, keepEditing }

/// Asks what to do with unsaved changes when leaving an editor.
/// Dismissing the dialog counts as [LeaveChoice.keepEditing].
Future<LeaveChoice> askLeave(BuildContext context) async {
  final r = await showDialog<LeaveChoice>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Ungespeicherte Änderungen'),
      content: const Text('Sollen die Änderungen gespeichert werden?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, LeaveChoice.keepEditing), child: const Text('Weiter bearbeiten')),
        TextButton(onPressed: () => Navigator.pop(c, LeaveChoice.discard), child: const Text('Verwerfen')),
        FilledButton(onPressed: () => Navigator.pop(c, LeaveChoice.save), child: const Text('Speichern')),
      ],
    ),
  );
  return r ?? LeaveChoice.keepEditing;
}
