import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

/// The one offline-write queue every later phase's client-initiated writes
/// reuse (location samples, transport declarations, checkpoint claims, tag
/// requests, ...). Each row is a single not-yet-synced intent; [kind] names
/// which RPC it targets and [payload] carries that RPC's arguments as JSON.
///
/// [clientActionId] is the idempotency key threaded through to the server
/// (plan: "Every client-initiated write carries a `client_action_id uuid
/// unique`") — offline queues *will* double-submit on retry, and the server
/// is what actually de-duplicates; this column is what lets a retried row
/// be recognised as the one already queued rather than a new one.
class PendingActions extends Table {
  TextColumn get clientActionId => text().withLength(min: 36, max: 36)();
  TextColumn get kind => text()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {clientActionId};
}

@DriftDatabase(tables: [PendingActions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'manhunt_sg.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
