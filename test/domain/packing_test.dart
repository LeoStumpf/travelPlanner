import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner/data/attachment_store.dart';
import 'package:travel_planner/data/db.dart';
import 'package:travel_planner/data/repository.dart';
import 'package:travel_planner/domain/demo.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/domain/packing.dart';

import '../l10n_test_utils.dart';

ChecklistEntry entry(String id, {bool done = false}) => ChecklistEntry(id: id, text: id.toUpperCase(), done: done);

List<String> ids(List<ChecklistEntry> list) => [for (final e in list) e.id];

NoteCard list(String tripId, List<ChecklistEntry> entries, {DateTime? at, String title = 'L'}) => NoteCard(
      id: '$tripId-$title',
      tripId: tripId,
      type: CardType.checklist,
      title: title,
      checklist: entries,
      createdAt: at ?? DateTime(2026),
    );

void main() {
  group('setEntryDone', () {
    test('ticks and unticks one entry only', () {
      final c = list('t', [entry('a'), entry('b')]);
      final ticked = setEntryDone(c, 'b', true);
      expect([for (final e in ticked.checklist) e.done], [false, true]);
      expect(setEntryDone(ticked, 'b', false).checklist[1].done, isFalse);
      expect(ticked.checklist[1].text, 'B');
    });

    test('an unknown id changes nothing', () {
      final c = list('t', [entry('a')]);
      expect(setEntryDone(c, 'x', true).checklist.single.done, isFalse);
    });
  });

  group('moveOpenEntry', () {
    final entries = [entry('a'), entry('x', done: true), entry('b'), entry('c'), entry('y', done: true)];

    test('moves down and up among the open entries', () {
      expect(ids(moveOpenEntry(entries, 0, 2)), ['b', 'x', 'c', 'a', 'y']);
      expect(ids(moveOpenEntry(entries, 2, 0)), ['c', 'x', 'a', 'b', 'y']);
      expect(ids(moveOpenEntry(entries, 1, 0)), ['b', 'x', 'a', 'c', 'y']);
    });

    test('ticked entries keep their slots', () {
      final moved = moveOpenEntry(entries, 0, 1);
      expect(moved[1].id, 'x');
      expect(moved[4].id, 'y');
    });

    test('out of range or same index leaves the list alone', () {
      expect(ids(moveOpenEntry(entries, 1, 1)), ids(entries));
      expect(ids(moveOpenEntry(entries, 5, 0)), ids(entries));
      expect(ids(moveOpenEntry(entries, 0, 99)), ['b', 'x', 'c', 'a', 'y']);
    });
  });

  group('adding entries', () {
    test('newEntryTexts skips existing, duplicate and blank texts', () {
      expect(newEntryTexts(['Passport', ' adapter '], ['passport', 'Sunscreen', '', 'Adapter', 'sunscreen ', ' Hat ']),
          ['Sunscreen', 'Hat']);
    });

    test('addEntries appends open entries and drops blank placeholders', () {
      var n = 0;
      final current = [entry('a'), const ChecklistEntry(id: 'blank', text: ' ')];
      final out = addEntries(current, ['A', 'New'], newId: () => 'n${n++}');
      expect(ids(out), ['a', 'n0']);
      expect(out.last.text, 'New');
      expect(out.last.done, isFalse);
    });

    test('addEntries keeps the list as it is when nothing is new', () {
      final current = [entry('a'), const ChecklistEntry(id: 'blank', text: '')];
      expect(identical(addEntries(current, ['a'], newId: () => 'x'), current), isTrue);
    });
  });

  group('templates', () {
    test('every template has entries in both languages, without duplicates', () {
      for (final l in [de, en]) {
        for (final items in [
          l.packingTemplateBasicsItems,
          l.packingTemplateBeachItems,
          l.packingTemplateHikingItems,
          l.packingTemplateCityItems,
        ]) {
          final list = items.split('|');
          expect(list.length, greaterThanOrEqualTo(8));
          expect(newEntryTexts(const [], list), list, reason: items);
        }
      }
      expect(PackingTemplate.values.length, 4);
    });

    test('combined templates list overlapping entries once', () {
      final beach = de.packingTemplateBeachItems.split('|');
      final hiking = de.packingTemplateHikingItems.split('|');
      final merged = newEntryTexts(const [], [...beach, ...hiking]);
      expect(merged.where((e) => e == 'Sonnencreme'), hasLength(1));
      expect(merged.length, beach.length + hiking.length - 1);
    });
  });

  group('copyableChecklists', () {
    test('offers other trips\' non-empty checklists, newest first', () {
      final sources = [
        ChecklistSource('Mine', list('here', [entry('a')])),
        ChecklistSource('Old', list('old', [entry('a')], at: DateTime(2024))),
        ChecklistSource('New', list('new', [entry('a'), entry('b')], at: DateTime(2026, 5))),
        ChecklistSource('Empty', list('empty', [const ChecklistEntry(id: 'e', text: ' ')])),
      ];
      final out = copyableChecklists(sources, 'here');
      expect([for (final s in out) s.tripTitle], ['New', 'Old']);
      expect(out.first.entries, ['A', 'B']);
    });
  });

  group('Repository.loadChecklists', () {
    late Repository repo;
    setUp(() => repo = Repository(AppDatabase(NativeDatabase.memory()), AttachmentStore(Directory.systemTemp)));
    tearDown(() => repo.close());

    test('returns checklists of all trips except those in the trash', () async {
      final a = demoInterrail();
      final b = demoSriLanka();
      await repo.putTripData(a);
      await repo.putTripData(b);
      var all = await repo.loadChecklists();
      expect({for (final s in all) s.tripTitle}, {a.trip.title, b.trip.title});
      expect(all.every((s) => s.card.type == CardType.checklist), isTrue);

      await repo.trashTrip(b.trip.id);
      all = await repo.loadChecklists();
      expect({for (final s in all) s.tripTitle}, {a.trip.title});
    });
  });
}
