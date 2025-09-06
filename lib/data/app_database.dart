import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
	static final AppDatabase _instance = AppDatabase._internal();
	factory AppDatabase() => _instance;
	AppDatabase._internal();

	Database? _db;

	Future<Database> get database async {
		if (_db != null) return _db!;
		_db = await _openDatabase();
		return _db!;
	}

	Future<Database> _openDatabase() async {
		final dbDir = await getDatabasesPath();
		final dbPath = p.join(dbDir, 'student_points.db');
		return openDatabase(
			dbPath,
			version: 2,
			onCreate: (db, version) async {
				await db.execute('''
					CREATE TABLE students (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						name TEXT NOT NULL
					);
				''');
				await db.execute('''
					CREATE TABLE habits (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						name TEXT NOT NULL,
						points INTEGER NOT NULL
					);
				''');
				await db.execute('''
					CREATE TABLE daily_entries (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						date TEXT NOT NULL,
						student_id INTEGER NOT NULL,
						habit_id INTEGER NOT NULL,
						count INTEGER NOT NULL DEFAULT 0,
						points_earned INTEGER NOT NULL DEFAULT 0,
						UNIQUE(date, student_id, habit_id),
						FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE,
						FOREIGN KEY(habit_id) REFERENCES habits(id) ON DELETE CASCADE
					);
				''');
			},
			onUpgrade: (db, oldVersion, newVersion) async {
				if (oldVersion < 2) {
					await db.execute('ALTER TABLE daily_entries ADD COLUMN points_earned INTEGER');
					await db.execute('''
						UPDATE daily_entries
						SET points_earned = (
							SELECT points FROM habits WHERE habits.id = daily_entries.habit_id
						) * count
						WHERE points_earned IS NULL;
					''');
				}
			},
		);
	}
}


