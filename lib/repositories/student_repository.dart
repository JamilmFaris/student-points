import '../data/app_database.dart';
import '../models/student.dart';

class StudentRepository {
	Future<List<Student>> getAll() async {
		final db = await AppDatabase().database;
		final rows = await db.query('students', orderBy: 'name COLLATE NOCASE');
		return rows.map((e) => Student.fromMap(e)).toList();
	}

	Future<int> insert(Student student) async {
		final db = await AppDatabase().database;
		return db.insert('students', student.toMap()..remove('id'));
	}

	Future<int> update(Student student) async {
		final db = await AppDatabase().database;
		return db.update('students', student.toMap()..remove('id'), where: 'id = ?', whereArgs: [student.id]);
	}

	Future<int> delete(int id) async {
		final db = await AppDatabase().database;
		return db.delete('students', where: 'id = ?', whereArgs: [id]);
	}
}


