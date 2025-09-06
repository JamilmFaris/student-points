import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';
import '../models/daily_entry.dart';

class TrackingRepository {
	Future<void> incrementHabitCount({required DateTime date, required int studentId, required int habitId}) async {
		final db = await AppDatabase().database;
		final dateStr = date.toIso8601String().substring(0, 10);
		await db.transaction((txn) async {
			final existing = await txn.query('daily_entries',
				where: 'date = ? AND student_id = ? AND habit_id = ?',
				whereArgs: [dateStr, studentId, habitId], limit: 1);
			if (existing.isEmpty) {
				await txn.insert('daily_entries', {
					'date': dateStr,
					'student_id': studentId,
					'habit_id': habitId,
					'count': 1,
				});
			} else {
				final count = (existing.first['count'] as int) + 1;
				await txn.update('daily_entries', {'count': count},
					where: 'id = ?', whereArgs: [existing.first['id']]);
			}
		});
	}

	Future<void> saveEntries(List<DailyEntry> entries) async {
		final db = await AppDatabase().database;
		await db.transaction((txn) async {
			for (final e in entries) {
				await txn.insert(
					'daily_entries',
					e.toMap(),
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
			for (final entry in counts.entries) {
				final studentId = entry.key;
				final habits = entry.value;
				for (final h in habits.entries) {
					final habitId = h.key;
					final count = h.value;
					if (count == 0) continue;
					await txn.insert('daily_entries', {
						'date': d,
						'student_id': studentId,
						'habit_id': habitId,
						'count': count,
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
			SELECT de.student_id as student_id, SUM(de.count * h.points) AS totalPoints
			FROM daily_entries de
			JOIN habits h ON h.id = de.habit_id
			WHERE de.date = ?
			GROUP BY de.student_id
		''', [dateStr]);
		return {for (final r in rows) r['student_id'] as int: (r['totalPoints'] as int? ?? 0)};
	}

	Future<Map<int, int>> getMonthlyTotals(int year, int month) async {
		final db = await AppDatabase().database;
		final monthStr = month.toString().padLeft(2, '0');
		final rows = await db.rawQuery('''
			SELECT de.student_id as student_id, SUM(de.count * h.points) AS totalPoints
			FROM daily_entries de
			JOIN habits h ON h.id = de.habit_id
			WHERE substr(de.date,1,7) = ?
			GROUP BY de.student_id
		''', ['$year-$monthStr']);
		return {for (final r in rows) r['student_id'] as int: (r['totalPoints'] as int? ?? 0)};
	}

	Future<Map<int, int>> getYearlyTotals(int year) async {
		final db = await AppDatabase().database;
		final rows = await db.rawQuery('''
			SELECT de.student_id as student_id, SUM(de.count * h.points) AS totalPoints
			FROM daily_entries de
			JOIN habits h ON h.id = de.habit_id
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
			SELECT de.student_id as student_id, SUM(de.count * h.points) AS totalPoints
			FROM daily_entries de
			JOIN habits h ON h.id = de.habit_id
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
}


