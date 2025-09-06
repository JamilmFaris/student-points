import '../data/app_database.dart';
import '../models/habit.dart';

class HabitRepository {
	Future<List<Habit>> getAll() async {
		final db = await AppDatabase().database;
		final rows = await db.query('habits', orderBy: 'name COLLATE NOCASE');
		return rows.map((e) => Habit.fromMap(e)).toList();
	}

	Future<int> insert(Habit habit) async {
		final db = await AppDatabase().database;
		return db.insert('habits', habit.toMap()..remove('id'));
	}

	Future<int> update(Habit habit) async {
		final db = await AppDatabase().database;
		return db.update('habits', habit.toMap()..remove('id'), where: 'id = ?', whereArgs: [habit.id]);
	}

	Future<int> delete(int id) async {
		final db = await AppDatabase().database;
		return db.delete('habits', where: 'id = ?', whereArgs: [id]);
	}
}


