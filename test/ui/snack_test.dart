import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/ui/common/dialogs.dart';
import 'package:travel_planner/ui/common/l10n.dart';

import '../l10n_test_utils.dart';

void main() {
  // Since Flutter 3.29 a SnackBar with an action stays until dismissed;
  // on the Pixel the undo snack hung around across views for minutes.
  testWidgets('snackbars with an action still time out', (tester) async {
    await tester.pumpWidget(testApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(children: [
            TextButton(
              onPressed: () => showUndoSnack(ScaffoldMessenger.of(context), 'Gelöscht', () {}),
              child: const Text('undo'),
            ),
            TextButton(
              onPressed: () => showSnack(context, 'Gespeichert', action: SnackBarAction(label: 'Ok', onPressed: () {})),
              child: const Text('plain'),
            ),
          ]),
        ),
      ),
    ));
    for (final (button, text) in [('undo', 'Gelöscht'), ('plain', 'Gespeichert')]) {
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
      expect(find.text(text), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text(text), findsNothing, reason: '$button snack must hide by itself');
    }
  });

  test('sizes use the locale decimal separator', () {
    expect(formatBytes(19 * 1024 * 1024 + 100 * 1024, 'de'), '19,1 MB');
    expect(formatBytes(19 * 1024 * 1024 + 100 * 1024, 'en'), '19.1 MB');
    expect(formatBytes(512 * 1024, 'de'), '512 KB');
  });
}
