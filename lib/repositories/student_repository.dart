import '../data/app_database.dart';
import '../models/student.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

class StudentRepository {
	Future<List<Student>> getAll() async {
		final db = await AppDatabase().database;
		final rows = await db.query('students', orderBy: 'sort_order ASC, name COLLATE NOCASE');
		return rows.map((e) => Student.fromMap(e)).toList();
	}

	Future<int> insert(Student student) async {
		final db = await AppDatabase().database;
		// Ensure column exists (defensive in case migration/onOpen didn't run yet)
		final cols = await db.rawQuery('PRAGMA table_info(students)');
		final hasSortOrder = cols.any((c) => (c['name'] as String) == 'sort_order');
		if (!hasSortOrder) {
			await db.execute('ALTER TABLE students ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0');
		}
		// Compute next sort order = max + 1
		final maxOrder = sqflite.Sqflite.firstIntValue(await db.rawQuery('SELECT COALESCE(MAX(sort_order), 0) FROM students')) ?? 0;
		final now = DateTime.now().toUtc().toIso8601String();
		final toInsert = student.toMap()
			..remove('id')
			..['sort_order'] = maxOrder + 1
			..['sync_status'] = 'pending_create'
			..['last_modified'] = now;
		return db.insert('students', toInsert);
	}

	Future<int> update(Student student) async {
		final db = await AppDatabase().database;
		final now = DateTime.now().toUtc().toIso8601String();
		// If row already has a remote_id, mark pending_update so future push picks it up.
		// New (unsynced) rows stay as pending_create.
		final existing = await db.query('students',
			columns: ['remote_id', 'sync_status'],
			where: 'id = ?',
			whereArgs: [student.id],
			limit: 1);
		String nextStatus = 'pending_create';
		if (existing.isNotEmpty && existing.first['remote_id'] != null) {
			nextStatus = 'pending_update';
		} else if (existing.isNotEmpty &&
			existing.first['sync_status'] == 'pending_create') {
			nextStatus = 'pending_create';
		}
		final values = student.toMap()
			..remove('id')
			..['sync_status'] = nextStatus
			..['last_modified'] = now;
		return db.update('students', values, where: 'id = ?', whereArgs: [student.id]);
	}

	Future<int> delete(int id) async {
		final db = await AppDatabase().database;
		return db.delete('students', where: 'id = ?', whereArgs: [id]);
	}

	Future<void> updateOrder(List<Student> students) async {
		final db = await AppDatabase().database;
		await db.transaction((txn) async {
			for (int i = 0; i < students.length; i++) {
				await txn.update('students', {'sort_order': i}, where: 'id = ?', whereArgs: [students[i].id]);
			}
		});
	}
}


