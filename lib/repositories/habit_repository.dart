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
		late Habit habitToInsert;
		if (habit.sortOrder == 0) {
			final maxSortOrder = await _getMaxSortOrder();
			habitToInsert = habit.copyWith(sortOrder: maxSortOrder + 1);
		} else {
			habitToInsert = habit;
		}
		// Mark new habits as pending_create for sync
		final toInsert = habitToInsert.toMap()..remove('id')..['sync_status'] = 'pending_create';
		return db.insert('habits', toInsert);
	}

	Future<int> update(Habit habit) async {
		final db = await AppDatabase().database;
		final existing = await db.query('habits',
			columns: ['remote_id', 'sync_status'],
			where: 'id = ?',
			whereArgs: [habit.id],
			limit: 1);

		String syncStatus = 'pending_create';
		if (existing.isNotEmpty && existing.first['remote_id'] != null) {
			syncStatus = 'pending_update';
		} else if (existing.isNotEmpty && existing.first['sync_status'] == 'pending_create') {
			syncStatus = 'pending_create';
		}

		final values = habit.toMap()..remove('id')..['sync_status'] = syncStatus;
		return db.update('habits', values, where: 'id = ?', whereArgs: [habit.id]);
	}

	Future<int> delete(int id) async {
		final db = await AppDatabase().database;
		final rows = await db.query('habits',
			columns: ['remote_id'], where: 'id = ?', whereArgs: [id], limit: 1);
		if (rows.isEmpty || rows.first['remote_id'] == null) {
			// Never made it to the server — hard delete locally.
			return db.delete('habits', where: 'id = ?', whereArgs: [id]);
		}
		// Mark for server-side deletion, then hard-remove locally after sync.
		return db.update('habits',
			{'sync_status': 'pending_delete'},
			where: 'id = ?', whereArgs: [id]);
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


