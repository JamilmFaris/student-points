import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';
import '../models/daily_entry.dart';
import '../models/habit_daily_point.dart';

class TrackingRepository {
	Future<void> incrementHabitCount({required DateTime date, required int studentId, required int habitId}) async {
		final db = await AppDatabase().database;
		final dateStr = date.toIso8601String().substring(0, 10);
		await db.transaction((txn) async {
			// Get current habit points once per increment
			final habitRows = await txn.query('habits', columns: ['points'], where: 'id = ?', whereArgs: [habitId], limit: 1);
			final habitPoints = (habitRows.first['points'] as int);
			final existing = await txn.query('daily_entries',
				where: 'date = ? AND student_id = ? AND habit_id = ?',
				whereArgs: [dateStr, studentId, habitId], limit: 1);
			if (existing.isEmpty) {
				await txn.insert('daily_entries', {
					'date': dateStr,
					'student_id': studentId,
					'habit_id': habitId,
					'count': 1,
					'points_earned': habitPoints,
				});
			} else {
				final count = (existing.first['count'] as int) + 1;
				final prevPoints = (existing.first['points_earned'] as int? ?? 0);
				await txn.update('daily_entries', {
					'count': count,
					'points_earned': prevPoints + habitPoints,
				},
					where: 'id = ?', whereArgs: [existing.first['id']]);
			}
		});
	}

	Future<void> saveEntries(List<DailyEntry> entries) async {
		final db = await AppDatabase().database;
		await db.transaction((txn) async {
			for (final e in entries) {
				final habitRows = await txn.query('habits', columns: ['points','decrease_points'], where: 'id = ?', whereArgs: [e.habitId], limit: 1);
				final habitPoints = (habitRows.first['points'] as int);
				final habitDecreasePoints = (habitRows.first['decrease_points'] as int? ?? habitPoints);
				await txn.insert(
					'daily_entries',
					{
						...e.toMap(),
						'points_earned': (e.count >= 0 ? e.count * habitPoints : (-e.count) * -habitDecreasePoints),
					},
					conflictAlgorithm: ConflictAlgorithm.replace,
				);
			}
		});
	}

	Future<void> replaceDayEntries(DateTime date, Map<int, Map<int, int>> counts) async {
		final db = await AppDatabase().database;
		final d = date.toIso8601String().substring(0, 10);
		await db.transaction((txn) async {
			await txn.delete('daily_entries', where: 'date = ?', whereArgs: [d]);
			// Preload habit points into a map to avoid repeated queries
			final habitRows = await txn.query('habits', columns: ['id', 'points', 'decrease_points']);
			final habitIdToPoints = {for (final r in habitRows) r['id'] as int: r['points'] as int};
			final habitIdToDecreasePoints = {for (final r in habitRows) r['id'] as int: (r['decrease_points'] as int? ?? (r['points'] as int))};
			for (final entry in counts.entries) {
				final studentId = entry.key;
				final habits = entry.value;
				for (final h in habits.entries) {
					final habitId = h.key;
					final count = h.value;
					if (count == 0) continue;
					final inc = habitIdToPoints[habitId] ?? 0;
					final dec = habitIdToDecreasePoints[habitId] ?? inc;
					final points = count >= 0 ? inc * count : -dec * (-count);
					await txn.insert('daily_entries', {
						'date': d,
						'student_id': studentId,
						'habit_id': habitId,
						'count': count,
						'points_earned': points,
					});
				}
			}
		});
	}

	Future<List<DailyEntry>> getEntriesForDate(DateTime date) async {
		final db = await AppDatabase().database;
		final dateStr = date.toIso8601String().substring(0, 10);
		final rows = await db.query('daily_entries', where: 'date = ?', whereArgs: [dateStr]);
		return rows.map((e) => DailyEntry.fromMap(e)).toList();
	} 

	Future<Map<int, int>> getDailyTotals(DateTime date) async {
		final db = await AppDatabase().database;
		final dateStr = date.toIso8601String().substring(0, 10);
		final rows = await db.rawQuery('''
			SELECT de.student_id as student_id, SUM(de.points_earned) AS totalPoints
			FROM daily_entries de
			WHERE de.date = ?
			GROUP BY de.student_id
		''', [dateStr]);
		return {for (final r in rows) r['student_id'] as int: (r['totalPoints'] as int? ?? 0)};
	}

	Future<Map<int, int>> getMonthlyTotals(int year, int month) async {
		final db = await AppDatabase().database;
		final monthStr = month.toString().padLeft(2, '0');
		final rows = await db.rawQuery('''
			SELECT de.student_id as student_id, SUM(de.points_earned) AS totalPoints
			FROM daily_entries de
			WHERE substr(de.date,1,7) = ?
			GROUP BY de.student_id
		''', ['$year-$monthStr']);
		return {for (final r in rows) r['student_id'] as int: (r['totalPoints'] as int? ?? 0)};
	}

	Future<Map<int, int>> getYearlyTotals(int year) async {
		final db = await AppDatabase().database;
		final rows = await db.rawQuery('''
			SELECT de.student_id as student_id, SUM(de.points_earned) AS totalPoints
			FROM daily_entries de
			WHERE substr(de.date,1,4) = ?
			GROUP BY de.student_id
		''', ['$year']);
		return {for (final r in rows) r['student_id'] as int: (r['totalPoints'] as int? ?? 0)};
	}

	Future<Map<int, int>> getTotalsInRange(DateTime start, DateTime end) async {
		final db = await AppDatabase().database;
		final s = start.toIso8601String().substring(0, 10);
		final e = end.toIso8601String().substring(0, 10);
		final rows = await db.rawQuery('''
			SELECT de.student_id as student_id, SUM(de.points_earned) AS totalPoints
			FROM daily_entries de
			WHERE de.date BETWEEN ? AND ?
			GROUP BY de.student_id
		''', [s, e]);
		return {for (final r in rows) r['student_id'] as int: (r['totalPoints'] as int? ?? 0)};
	}

	Future<List<String>> getDistinctDates() async {
		final db = await AppDatabase().database;
		final rows = await db.rawQuery('SELECT DISTINCT date FROM daily_entries ORDER BY date DESC');
		return rows.map((e) => e['date'] as String).toList();
	}

	Future<Map<int, Map<int, int>>> getDayBreakdown(DateTime date) async {
		final db = await AppDatabase().database;
		final d = date.toIso8601String().substring(0, 10);
		final rows = await db.query('daily_entries', where: 'date = ?', whereArgs: [d]);
		final result = <int, Map<int, int>>{};
		for (final r in rows) {
			final studentId = r['student_id'] as int;
			final habitId = r['habit_id'] as int;
			final count = r['count'] as int;
			result.putIfAbsent(studentId, () => {});
			result[studentId]![habitId] = count;
		}
		return result;
	}

	Future<Map<int, Map<int, int>>> getDayPointsBreakdown(DateTime date) async {
		final db = await AppDatabase().database;
		final d = date.toIso8601String().substring(0, 10);
		final rows = await db.query('daily_entries', columns: ['student_id', 'habit_id', 'points_earned'], where: 'date = ?', whereArgs: [d]);
		final result = <int, Map<int, int>>{};
		for (final r in rows) {
			final studentId = r['student_id'] as int;
			final habitId = r['habit_id'] as int;
			final points = r['points_earned'] as int? ?? 0;
			result.putIfAbsent(studentId, () => {});
			result[studentId]![habitId] = points;
		}
		return result;
	}

	Future<List<HabitDailyPoint>> getHabitDailyPointsSeries(int habitId, {required DateTime startDate, required DateTime endDate, int? studentId}) async {
		final db = await AppDatabase().database;
		final s = startDate.toIso8601String().substring(0, 10);
		final e = endDate.toIso8601String().substring(0, 10);
		var sql = '''
			SELECT date, SUM(points_earned) as total
			FROM daily_entries
			WHERE habit_id = ? AND date BETWEEN ? AND ?
		''';
		final args = <Object?>[habitId, s, e];
		if (studentId != null) {
			sql += ' AND student_id = ?';
			args.add(studentId);
		}
		sql += '\n\t\t\tGROUP BY date\n\t\t\tORDER BY date ASC';
		final rows = await db.rawQuery(sql, args);
		final byDate = {for (final r in rows) (r['date'] as String): (r['total'] as int? ?? 0)};
		final result = <HabitDailyPoint>[];
		DateTime cursor = DateTime(startDate.year, startDate.month, startDate.day);
		final DateTime end = DateTime(endDate.year, endDate.month, endDate.day);
		while (!cursor.isAfter(end)) {
			final d = cursor.toIso8601String().substring(0, 10);
			result.add(HabitDailyPoint(date: cursor, points: byDate[d] ?? 0));
			cursor = cursor.add(const Duration(days: 1));
		}
		return result;
	}
}


