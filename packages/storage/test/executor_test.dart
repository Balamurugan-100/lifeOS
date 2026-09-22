import 'dart:io';

import 'package:drift/drift.dart';
import 'package:lifeos_storage/lifeos_storage.dart';
import 'package:test/test.dart';

part 'executor_test.g.dart';

void main() {
  group('executor helpers', () {
    test('in-memory executor opens and writes (drift smoke test)', () async {
      final executor = openInMemoryExecutor();
      final db = _SmokeDatabase(executor);

      await db
          .into(db.smokeTable)
          .insert(SmokeTableCompanion.insert(value: 'hello'));

      final rows = await db.select(db.smokeTable).get();
      expect(rows.single.value, 'hello');

      await db.close();
    });

    test('file executor opens and closes cleanly', () async {
      final dir = await Directory.systemTemp.createTemp('lifeos-storage-test');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/smoke.db';

      final executor = openFileExecutor(path);
      final db = _SmokeDatabase(executor);
      await db
          .into(db.smokeTable)
          .insert(SmokeTableCompanion.insert(value: 'file'));
      expect((await db.select(db.smokeTable).get()).single.value, 'file');

      await closeExecutor(executor);
      expect(File(path).existsSync(), isTrue);
    });
  });

  group('audit conventions', () {
    test('utcNow returns a UTC instant', () {
      expect(utcNow().isUtc, isTrue);
    });
  });
}

class SmokeTable extends Table {
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {value};
}

@DriftDatabase(tables: [SmokeTable])
class _SmokeDatabase extends _$_SmokeDatabase {
  _SmokeDatabase(super.e);

  @override
  int get schemaVersion => 1;
}