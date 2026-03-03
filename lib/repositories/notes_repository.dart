import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';
import '../models/note.dart';

class NotesRepository {
	Future<List<Note>> listForStudent(int studentId) async {
		final db = await AppDatabase().database;
		final rows = await db.query(
			'student_notes',
			where: 'student_id = ?',
			whereArgs: [studentId],
			orderBy: 'updated_at DESC, id DESC',
		);
		return rows.map((e) => Note.fromMap(e)).toList();
	}

	Future<int> insert(Note note) async {
		final db = await AppDatabase().database;
		final map = note.toMap()..remove('id');
		map['created_at'] ??= DateTime.now().toIso8601String();
		map['updated_at'] ??= DateTime.now().toIso8601String();
		return db.insert('student_notes', map);
	}

	Future<void> update(Note note) async {
		if (note.id == null) return;
		final db = await AppDatabase().database;
		final map = note.toMap()..remove('id');
		map['updated_at'] = DateTime.now().toIso8601String();
		await db.update('student_notes', map, where: 'id = ?', whereArgs: [note.id]);
	}

	Future<void> delete(int id) async {
		final db = await AppDatabase().database;
		await db.delete('student_notes', where: 'id = ?', whereArgs: [id]);
	}
}
