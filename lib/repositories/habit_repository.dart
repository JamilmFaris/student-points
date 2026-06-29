import 'dart:async';

import '../data/app_database.dart';
import '../models/habit.dart';

class HabitRepository {
	/// Broadcasts whenever habits are mutated outside the normal UI flow.
	/// Screens listen and reload to avoid stale in-memory state.
	static final StreamController<void> _externalChanges =
		StreamController<void>.broadcast();
	static Stream<void> get externalChanges => _externalChanges.stream;
	/// Active habits for the tracking/habits screens: excludes server-delete
	/// tombstones and archived (hidden) habits.
	Future<List<Habit>> getAll() async {
		final db = await AppDatabase().database;
		final rows = await db.query('habits',
			where: "sync_status != 'pending_delete' AND (archived IS NULL OR archived = 0)",
			orderBy: 'sort_order, name COLLATE NOCASE');
		return rows.map((e) => Habit.fromMap(e)).toList();
	}

	/// Every habit including archived ones — used by the logs to resolve names
	/// of habits that were deleted (archived) but still have historical points.
	Future<List<Habit>> getAllIncludingArchived() async {
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
		final id = await db.insert('habits', toInsert);
		_externalChanges.add(null);
		return id;
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
		final count = await db.update('habits', values, where: 'id = ?', whereArgs: [habit.id]);
		_externalChanges.add(null);
		return count;
	}

	Future<int> delete(int id) async {
		final db = await AppDatabase().database;
		// Does this habit still have point entries? If so, archive it instead of
		// deleting: the row (and its remote_id) is kept so historical points keep
		// resolving and syncing, and the logs can still show its name. It's just
		// hidden from the active tracking/habits screens.
		final entryRows = await db.query('daily_entries',
			columns: ['id'], where: 'habit_id = ?', whereArgs: [id], limit: 1);
		late int result;
		if (entryRows.isNotEmpty) {
			result = await db.update('habits',
				{'archived': 1},
				where: 'id = ?', whereArgs: [id]);
			_externalChanges.add(null);
			return result;
		}
		// No history — safe to remove outright.
		final rows = await db.query('habits',
			columns: ['remote_id'], where: 'id = ?', whereArgs: [id], limit: 1);
		if (rows.isEmpty || rows.first['remote_id'] == null) {
			// Never made it to the server — hard delete locally.
			result = await db.delete('habits', where: 'id = ?', whereArgs: [id]);
		} else {
			// Mark for server-side deletion, then hard-remove locally after sync.
			result = await db.update('habits',
				{'sync_status': 'pending_delete'},
				where: 'id = ?', whereArgs: [id]);
		}
		_externalChanges.add(null);
		return result;
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
		_externalChanges.add(null);
	}

	Future<int> _getMaxSortOrder() async {
		final db = await AppDatabase().database;
		final result = await db.rawQuery('SELECT MAX(sort_order) as max_sort FROM habits');
		final maxSort = result.first['max_sort'] as int?;
		return maxSort ?? 0;
	}
}


