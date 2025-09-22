import '../data/app_database.dart';
import '../models/habit.dart';

class HabitRepository {
	Future<List<Habit>> getAll() async {
		final db = await AppDatabase().database;
		final rows = await db.query('habits', orderBy: 'sort_order, name COLLATE NOCASE');
		return rows.map((e) => Habit.fromMap(e)).toList();
	}

	Future<int> insert(Habit habit) async {
		final db = await AppDatabase().database;
		// If no sort order specified, put it at the end
		if (habit.sortOrder == 0) {
			final maxSortOrder = await _getMaxSortOrder();
			final habitWithOrder = habit.copyWith(sortOrder: maxSortOrder + 1);
			return db.insert('habits', habitWithOrder.toMap()..remove('id'));
		}
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

	Future<void> updateSortOrders(List<Habit> habits) async {
		final db = await AppDatabase().database;
		await db.transaction((txn) async {
			for (int i = 0; i < habits.length; i++) {
				final habit = habits[i];
				await txn.update(
					'habits',
					{'sort_order': i + 1},
					where: 'id = ?',
					whereArgs: [habit.id],
				);
			}
		});
	}

	Future<int> _getMaxSortOrder() async {
		final db = await AppDatabase().database;
		final result = await db.rawQuery('SELECT MAX(sort_order) as max_sort FROM habits');
		final maxSort = result.first['max_sort'] as int?;
		return maxSort ?? 0;
	}
}


