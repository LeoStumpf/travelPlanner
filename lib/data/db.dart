import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'db.steps.dart';
import 'doc_migrations.dart';

part 'db.g.dart';

/// Document store: every entity is one JSON row, scoped by trip. Data per trip
/// is small, so loading a trip as a whole keeps all views trivially in sync and
/// makes export/import a plain JSON dump.
@DataClassName('DocRow')
@TableIndex(name: 'docs_trip', columns: {#tripId})
class Docs extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text()();

  /// trip | item | card | edge | attachment
  TextColumn get type => text()();
  TextColumn get json => text()();
  IntColumn get updatedAt => integer()();

  /// Version of the JSON layout in [json], see doc_migrations.dart.
  IntColumn get docVersion => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Two levels of migrations:
///
/// * **SQL schema** ([schemaVersion]): tables, columns, indexes. Every change
///   bumps [schemaVersion], adds a `fromXToY` step below and needs
///   `dart run drift_dev make-migrations`, which snapshots the schema into
///   `drift_schemas/` and regenerates `db.steps.dart` and the test helpers in
///   `test/drift/`. Never edit a released step.
/// * **JSON documents** ([currentDocVersion]): the layout of the model JSON in
///   [Docs.json]. Model changes that old JSON cannot express via optional
///   fields with defaults add a step in doc_migrations.dart; [beforeOpen]
///   rewrites all older rows once. Backups carry the doc version too, so old
///   ZIPs pass through the same steps on import.
@DriftDatabase(tables: [Docs])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'travel_planner'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: stepByStep(
          // v2: per-row doc version; existing rows get the default 1. The
          // trip index is now declared on the table; v1 created it by hand.
          from1To2: (m, schema) async {
            await m.addColumn(schema.docs, schema.docs.docVersion);
            await customStatement('CREATE INDEX IF NOT EXISTS docs_trip ON docs (trip_id)');
          },
        ),
        beforeOpen: (details) async {
          // No foreign keys yet, but new tables with references must not end
          // up silently unchecked.
          await customStatement('PRAGMA foreign_keys = ON');
          await migrateDocs();
        },
      );

  /// Brings every row with an older [Docs.docVersion] to [to]. Runs on every
  /// open; when everything is current it is a single query. The parameters
  /// exist for tests.
  Future<void> migrateDocs({int to = currentDocVersion, List<DocMigrationStep> steps = docMigrationSteps}) async {
    final stale = await (select(docs)..where((d) => d.docVersion.isSmallerThanValue(to))).get();
    if (stale.isEmpty) return;
    await transaction(() async {
      for (final r in stale) {
        await (update(docs)..where((d) => d.id.equals(r.id))).write(DocsCompanion(
          json: Value(migrateDocJson(r.type, r.json, r.docVersion, to: to, steps: steps)),
          docVersion: Value(to),
        ));
      }
    });
  }
}
