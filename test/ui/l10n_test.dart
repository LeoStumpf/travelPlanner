import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:travel_planner/data/backup.dart';
import 'package:travel_planner/data/doc_migrations.dart';
import 'package:travel_planner/domain/analysis.dart';
import 'package:travel_planner/domain/demo.dart';
import 'package:travel_planner/domain/models.dart';
import 'package:travel_planner/domain/plan_exchange.dart';
import 'package:travel_planner/domain/scheduler.dart';
import 'package:travel_planner/domain/time.dart';
import 'package:travel_planner/state/providers.dart';
import 'package:travel_planner/ui/common/l10n.dart';

import '../l10n_test_utils.dart';

Map<String, Object?> _arb(String lang) =>
    (jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map).cast<String, Object?>();

/// Placeholder names used in an ARB message ({name} and {name, plural, …}).
Set<String> _placeholders(String message) =>
    {for (final m in RegExp(r'(?<!\w)\{([A-Za-z]\w*)(?=[},])').allMatches(message)) m[1]!};

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de');
    await initializeDateFormatting('en');
  });

  group('ARB files', () {
    test('English and German have the same keys and placeholders', () {
      final en = _arb('en'), de = _arb('de');
      final keys = {for (final k in en.keys) if (!k.startsWith('@')) k};
      expect({for (final k in de.keys) if (!k.startsWith('@')) k}, keys);
      for (final k in keys.where((k) => k != '@@locale')) {
        expect(_placeholders(de[k] as String), _placeholders(en[k] as String), reason: k);
      }
    });

    test('no German left in the English strings', () {
      final en = _arb('en');
      for (final MapEntry(:key, :value) in en.entries) {
        if (key.startsWith('@') || value is! String) continue;
        expect(value, isNot(matches(RegExp('[äöüÄÖÜß„]'))), reason: key);
      }
    });
  });

  group('lib/ui and lib/domain carry no German literals', () {
    // Every user-visible text lives in the ARB files now. Comments may still
    // quote German, and file names keep umlauts.
    final german = RegExp(r"'[^'\n]*[äöüÄÖÜß„“][^'\n]*'");
    for (final dir in ['lib/ui', 'lib/domain', 'lib/state']) {
      test(dir, () {
        for (final f in Directory(dir).listSync(recursive: true).whereType<File>()) {
          if (!f.path.endsWith('.dart')) continue;
          final lines = f.readAsLinesSync();
          for (var n = 0; n < lines.length; n++) {
            final code = lines[n].trimLeft();
            if (code.startsWith('//')) continue;
            if (code.contains("RegExp(r'[^\\w\\- äöüÄÖÜß]')")) continue;
            expect(german.hasMatch(code), isFalse, reason: '${f.path}:${n + 1}: $code');
          }
        }
      });
    }
  });

  group('domain values in words', () {
    test('every enum has a label in both languages', () {
      for (final l in [de, en]) {
        for (final k in ItemKind.values) {
          expect(l.kind(k), isNotEmpty);
        }
        for (final s in ItemStatus.values) {
          expect(l.status(s), isNotEmpty);
        }
        for (final m in TransportMode.values) {
          expect(l.mode(m), isNotEmpty);
        }
        for (final m in ShiftMode.values) {
          expect([l.shiftMode(m), l.shiftModeShort(m)], everyElement(isNotEmpty));
        }
        for (final p in DayPart.values) {
          expect(l.dayPart(p), isNotEmpty);
        }
        for (final v in TripView.values) {
          expect(l.view(v), isNotEmpty);
        }
      }
      expect(de.kind(ItemKind.stay), 'Ort');
      expect(en.kind(ItemKind.stay), 'Place');
      expect(de.layer(ItemKind.transport), 'Ebene 2: Transport');
      expect(en.mode(TransportMode.walk), 'On foot');
    });

    test('days, nights and durations', () {
      expect([de.days(1), de.days(3), de.nights(1), de.nights(2)], ['1 Tag', '3 Tage', '1 Nacht', '2 Nächte']);
      expect([en.days(1), en.days(3), en.nights(1), en.nights(2)], ['1 day', '3 days', '1 night', '2 nights']);
      expect(de.duration(minutesPerDay + 3 * 60), '1 Tag 3h');
      expect(de.duration(2 * minutesPerDay), '2 Tage');
      expect(en.duration(5 * 60), '5h');
      expect(en.duration(90, withMinutes: true), '1h 30min');
      expect(en.duration(30, withMinutes: true), '30min');
    });

    test('trip days follow the start date and the language', () {
      expect(de.day(null, 2), 'Tag 3');
      expect(en.day(null, 2), 'Day 3');
      final start = DateTime(2027, 3, 10);
      expect(en.day(start, 2), 'Fri, Mar 12');
      expect(de.day(start, 2), 'Fr., 12. März');
      expect(en.day(start, 2, withDayNumber: true), 'Fri, Mar 12 (day 3)');
      expect(de.moment(null, at(1, 14 * 60)), 'Tag 2, 14:00');
      expect(en.dateTime(DateTime(2026, 10, 17, 14, 3)), '10/17/2026 14:03');
      expect(de.dateTime(DateTime(2026, 10, 17, 14, 3)), '17.10.2026 14:03');
    });

    test('conflicts and fixes are worded from their type and values', () {
      PlanItem stay(String id, int first, int nights) => PlanItem(
            id: id,
            tripId: 't',
            kind: ItemKind.stay,
            title: id,
            start: at(first, defaultStayArrival),
            end: at(first + nights, defaultStayDeparture),
            createdAt: DateTime(2026),
          );
      final c = findConflicts([stay('Paris', 0, 3), stay('Lyon', 2, 2)]).single;
      expect(c.type, ConflictType.staysOverlap);
      expect(de.conflict(c), '„Lyon“ beginnt 20h bevor „Paris“ endet');
      expect(en.conflict(c), '“Lyon” starts 20h before “Paris” ends');
      expect(de.conflictFix(c.fix!), '„Lyon“ nach hinten schieben');
      expect(en.conflictFix(c.fix!), 'Push “Lyon” back');

      const gap = Conflict('tgv', 'paris', ConflictType.daysBeforeDeparture,
          itemTitle: 'TGV', otherTitle: 'Paris', amount: 2);
      expect(de.conflict(gap), 'Zwischen „Paris“ und Abfahrt von „TGV“ liegen 2 Tage ohne Ort');
      expect(en.conflict(gap), '2 days without a place between “Paris” and the departure of “TGV”');
      const one = Conflict('tgv', 'lyon', ConflictType.daysAfterArrival,
          itemTitle: 'TGV', otherTitle: 'Lyon', amount: 1);
      expect(de.conflict(one), 'Zwischen Ankunft von „TGV“ und „Lyon“ liegt 1 Tag ohne Ort');

      for (final type in ConflictType.values) {
        final k = Conflict('a', 'b', type, itemTitle: 'A', otherTitle: 'B', amount: 60);
        for (final l in [de, en]) {
          expect(l.conflict(k), allOf(contains('A'), contains('B')), reason: '$type');
        }
      }
      for (final type in ConflictFixType.values) {
        for (final l in [de, en]) {
          expect(l.conflictFix(ConflictFix(type, 'X', const {})), contains('X'), reason: '$type');
        }
      }
    });

    test('plan warnings and errors in words', () {
      for (final type in PlanWarningType.values) {
        final w = PlanWarning(type, entry: 'E', field: 'f', value: 'v');
        for (final l in [de, en]) {
          expect(l.planWarning(w), isNotEmpty, reason: '$type');
        }
      }
      const w = PlanWarning(PlanWarningType.refNotFound, entry: 'Louvre', field: 'stay', value: 'paris');
      expect(de.planWarning(w), '„Louvre“: stay „paris“ nicht gefunden – Verknüpfung entfernt');
      expect(en.planWarning(w), '“Louvre”: stay “paris” not found – link removed');

      expect(de.planError(const PlanFormatException(PlanErrorType.tooNew, '9')),
          'Plan-Version 9 ist neuer als diese App (kann 1)');
      expect(en.planError(const PlanFormatException(PlanErrorType.unknownFormat, 'x')),
          'Unknown format “x” (expected: tripboard-plan)');
      expect(en.planError(const FormatException('raw')), 'raw');
    });

    test('known errors in words, others as they are', () {
      expect(de.error(const NotABackupException('no trip.json')), 'Kein Tripboard-Backup');
      expect(en.error(const NewerDataException(3, 2)), contains('format 3, supported: 2'));
      expect(en.error(StateError('x')), contains('x'));
    });

    test('demo trips in the user language, English by default', () {
      expect(demoInterrail(de.demoTexts).trip.title, 'Interrail Frankreich & Spanien');
      expect(demoInterrail().trip.title, 'Interrail France & Spain');
      final sl = demoSriLanka(de.demoTexts);
      expect(sl.items.map((i) => i.title), contains('Zahntempel'));
      expect(sl.cards.firstWhere((c) => c.type == CardType.checklist).checklist.map((e) => e.text),
          ['ETA-Visum beantragen', 'Impfungen checken', 'Mückenschutz', 'Rupien tauschen']);
      expect(demoSriLanka(en.demoTexts).items.map((i) => i.title), contains('Temple of the Tooth'));
    });
  });

  group('app language', () {
    Future<String> shown(WidgetTester tester, List<Locale> device) async {
      tester.platformDispatcher.localesTestValue = device;
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(MaterialApp(
        supportedLocales: appLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(builder: (context) => Text(context.l10n.myTrips)),
      ));
      await tester.pumpAndSettle();
      return tester.widget<Text>(find.byType(Text)).data!;
    }

    testWidgets('follows the device language', (tester) async {
      expect(await shown(tester, const [Locale('de', 'AT')]), 'Meine Reisen');
      expect(await shown(tester, const [Locale('en', 'US')]), 'My trips');
    });

    testWidgets('falls back to English for other languages', (tester) async {
      expect(await shown(tester, const [Locale('fr', 'FR')]), 'My trips');
    });

    testWidgets('widgets render in English too', (tester) async {
      await tester.pumpWidget(testApp(
        locale: const Locale('en'),
        home: Builder(builder: (context) => Text(context.l10n.trashPurgeHint(1))),
      ));
      expect(find.text('Will be deleted for good tomorrow'), findsOneWidget);
    });
  });
}
