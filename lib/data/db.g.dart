// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'db.dart';

// ignore_for_file: type=lint
class $DocsTable extends Docs with TableInfo<$DocsTable, DocRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
    'trip_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _docVersionMeta = const VerificationMeta(
    'docVersion',
  );
  @override
  late final GeneratedColumn<int> docVersion = GeneratedColumn<int>(
    'doc_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tripId,
    type,
    json,
    updatedAt,
    docVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'docs';
  @override
  VerificationContext validateIntegrity(
    Insertable<DocRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('doc_version')) {
      context.handle(
        _docVersionMeta,
        docVersion.isAcceptableOrUnknown(data['doc_version']!, _docVersionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DocRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      docVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}doc_version'],
      )!,
    );
  }

  @override
  $DocsTable createAlias(String alias) {
    return $DocsTable(attachedDatabase, alias);
  }
}

class DocRow extends DataClass implements Insertable<DocRow> {
  final String id;
  final String tripId;

  /// trip | item | card | edge | attachment
  final String type;
  final String json;
  final int updatedAt;

  /// Version of the JSON layout in [json], see doc_migrations.dart.
  final int docVersion;
  const DocRow({
    required this.id,
    required this.tripId,
    required this.type,
    required this.json,
    required this.updatedAt,
    required this.docVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['trip_id'] = Variable<String>(tripId);
    map['type'] = Variable<String>(type);
    map['json'] = Variable<String>(json);
    map['updated_at'] = Variable<int>(updatedAt);
    map['doc_version'] = Variable<int>(docVersion);
    return map;
  }

  DocsCompanion toCompanion(bool nullToAbsent) {
    return DocsCompanion(
      id: Value(id),
      tripId: Value(tripId),
      type: Value(type),
      json: Value(json),
      updatedAt: Value(updatedAt),
      docVersion: Value(docVersion),
    );
  }

  factory DocRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocRow(
      id: serializer.fromJson<String>(json['id']),
      tripId: serializer.fromJson<String>(json['tripId']),
      type: serializer.fromJson<String>(json['type']),
      json: serializer.fromJson<String>(json['json']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      docVersion: serializer.fromJson<int>(json['docVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tripId': serializer.toJson<String>(tripId),
      'type': serializer.toJson<String>(type),
      'json': serializer.toJson<String>(json),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'docVersion': serializer.toJson<int>(docVersion),
    };
  }

  DocRow copyWith({
    String? id,
    String? tripId,
    String? type,
    String? json,
    int? updatedAt,
    int? docVersion,
  }) => DocRow(
    id: id ?? this.id,
    tripId: tripId ?? this.tripId,
    type: type ?? this.type,
    json: json ?? this.json,
    updatedAt: updatedAt ?? this.updatedAt,
    docVersion: docVersion ?? this.docVersion,
  );
  DocRow copyWithCompanion(DocsCompanion data) {
    return DocRow(
      id: data.id.present ? data.id.value : this.id,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      type: data.type.present ? data.type.value : this.type,
      json: data.json.present ? data.json.value : this.json,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      docVersion: data.docVersion.present
          ? data.docVersion.value
          : this.docVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocRow(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('type: $type, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('docVersion: $docVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, tripId, type, json, updatedAt, docVersion);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocRow &&
          other.id == this.id &&
          other.tripId == this.tripId &&
          other.type == this.type &&
          other.json == this.json &&
          other.updatedAt == this.updatedAt &&
          other.docVersion == this.docVersion);
}

class DocsCompanion extends UpdateCompanion<DocRow> {
  final Value<String> id;
  final Value<String> tripId;
  final Value<String> type;
  final Value<String> json;
  final Value<int> updatedAt;
  final Value<int> docVersion;
  final Value<int> rowid;
  const DocsCompanion({
    this.id = const Value.absent(),
    this.tripId = const Value.absent(),
    this.type = const Value.absent(),
    this.json = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.docVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocsCompanion.insert({
    required String id,
    required String tripId,
    required String type,
    required String json,
    required int updatedAt,
    this.docVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tripId = Value(tripId),
       type = Value(type),
       json = Value(json),
       updatedAt = Value(updatedAt);
  static Insertable<DocRow> custom({
    Expression<String>? id,
    Expression<String>? tripId,
    Expression<String>? type,
    Expression<String>? json,
    Expression<int>? updatedAt,
    Expression<int>? docVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tripId != null) 'trip_id': tripId,
      if (type != null) 'type': type,
      if (json != null) 'json': json,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (docVersion != null) 'doc_version': docVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocsCompanion copyWith({
    Value<String>? id,
    Value<String>? tripId,
    Value<String>? type,
    Value<String>? json,
    Value<int>? updatedAt,
    Value<int>? docVersion,
    Value<int>? rowid,
  }) {
    return DocsCompanion(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      type: type ?? this.type,
      json: json ?? this.json,
      updatedAt: updatedAt ?? this.updatedAt,
      docVersion: docVersion ?? this.docVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (docVersion.present) {
      map['doc_version'] = Variable<int>(docVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocsCompanion(')
          ..write('id: $id, ')
          ..write('tripId: $tripId, ')
          ..write('type: $type, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('docVersion: $docVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DocsTable docs = $DocsTable(this);
  late final Index docsTrip = Index(
    'docs_trip',
    'CREATE INDEX docs_trip ON docs (trip_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [docs, docsTrip];
}

typedef $$DocsTableCreateCompanionBuilder = DocsCompanion Function({
  required String id,
  required String tripId,
  required String type,
  required String json,
  required int updatedAt,
  Value<int> docVersion,
  Value<int> rowid,
});
typedef $$DocsTableUpdateCompanionBuilder = DocsCompanion Function({
  Value<String> id,
  Value<String> tripId,
  Value<String> type,
  Value<String> json,
  Value<int> updatedAt,
  Value<int> docVersion,
  Value<int> rowid,
});

class $$DocsTableFilterComposer extends Composer<_$AppDatabase, $DocsTable> {
  $$DocsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get docVersion => $composableBuilder(
    column: $table.docVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DocsTableOrderingComposer extends Composer<_$AppDatabase, $DocsTable> {
  $$DocsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get docVersion => $composableBuilder(
    column: $table.docVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DocsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocsTable> {
  $$DocsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tripId =>
      $composableBuilder(column: $table.tripId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get docVersion => $composableBuilder(
    column: $table.docVersion,
    builder: (column) => column,
  );
}

class $$DocsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DocsTable,
          DocRow,
          $$DocsTableFilterComposer,
          $$DocsTableOrderingComposer,
          $$DocsTableAnnotationComposer,
          $$DocsTableCreateCompanionBuilder,
          $$DocsTableUpdateCompanionBuilder,
          (DocRow, BaseReferences<_$AppDatabase, $DocsTable, DocRow>),
          DocRow,
          PrefetchHooks Function()
        > {
  $$DocsTableTableManager(_$AppDatabase db, $DocsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tripId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> docVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocsCompanion(
                id: id,
                tripId: tripId,
                type: type,
                json: json,
                updatedAt: updatedAt,
                docVersion: docVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tripId,
                required String type,
                required String json,
                required int updatedAt,
                Value<int> docVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocsCompanion.insert(
                id: id,
                tripId: tripId,
                type: type,
                json: json,
                updatedAt: updatedAt,
                docVersion: docVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DocsTable, DocRow>(table),
                  BaseReferences<_$AppDatabase, $DocsTable, DocRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DocsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DocsTable,
      DocRow,
      $$DocsTableFilterComposer,
      $$DocsTableOrderingComposer,
      $$DocsTableAnnotationComposer,
      $$DocsTableCreateCompanionBuilder,
      $$DocsTableUpdateCompanionBuilder,
      (DocRow, BaseReferences<_$AppDatabase, $DocsTable, DocRow>),
      DocRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DocsTableTableManager get docs => $$DocsTableTableManager(_db, _db.docs);
}
