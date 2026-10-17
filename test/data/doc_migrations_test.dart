import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/data/backup.dart';
import 'package:travel_planner/data/doc_migrations.dart';
import 'package:travel_planner/domain/demo.dart';

void main() {
  Map<String, Object?> addA(String type, Map<String, Object?> j) => {...j, 'a': type};
  Map<String, Object?> addB(String type, Map<String, Object?> j) => {...j, 'b': j['a']};

  test('applies the steps in order from the stored version', () {
    expect(migrateDoc('item', {'id': 'x'}, 1, to: 3, steps: [addA, addB]), {'id': 'x', 'a': 'item', 'b': 'item'});
    expect(migrateDoc('item', {'id': 'x'}, 2, to: 3, steps: [addA, addB]), {'id': 'x', 'b': null});
    expect(migrateDoc('item', {'id': 'x'}, 3, to: 3, steps: [addA, addB]), {'id': 'x'});
  });

  test('rejects documents from a newer app version', () {
    expect(() => migrateDoc('trip', {}, currentDocVersion + 1), throwsFormatException);
  });

  test('every version below the current one has a step', () {
    expect(docMigrationSteps, hasLength(currentDocVersion - 1));
  });

  test('migrateDocJson works on encoded documents', () {
    expect(jsonDecode(migrateDocJson('card', '{"id":"c"}', 1, to: 2, steps: [addA])), {'id': 'c', 'a': 'card'});
  });

  test('backups carry the doc version; old backups without it still import', () {
    final demo = demoSriLanka();
    final j = Backup.toJson(demo);
    expect(j['docVersion'], currentDocVersion);
    final legacy = jsonDecode(jsonEncode(j)) as Map<String, Object?>..remove('docVersion');
    final back = Backup.fromJson(legacy);
    expect(back.items.length, demo.items.length);
    expect(back.trip.title, demo.trip.title);
    final future = {...j, 'docVersion': currentDocVersion + 1};
    expect(() => Backup.fromJson(future), throwsFormatException);
  });
}
