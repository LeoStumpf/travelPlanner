import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'db.g.dart';

/// Document store: every entity is one JSON row, scoped by trip. Data per trip
/// is small, so loading a trip as a whole keeps all views trivially in sync and
/// makes export/import a plain JSON dump.
@DataClassName('DocRow')
class Docs extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text()();

  /// trip | item | card | edge | attachment
  TextColumn get type => text()();
  TextColumn get json => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Docs])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'travel_planner'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement('CREATE INDEX IF NOT EXISTS docs_trip ON docs (trip_id)');
        },
      );
}
