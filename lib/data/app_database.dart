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
			version: 7,
			onCreate: (db, version) async {
				await db.execute('''
					CREATE TABLE students (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						name TEXT NOT NULL,
						sort_order INTEGER NOT NULL DEFAULT 0,
						date_of_birth TEXT,
						school_name TEXT,
						father_name TEXT,
						mother_name TEXT,
						phone_number TEXT,
						birth_place TEXT,
						grade TEXT
					);
				''');
				await db.execute('''
					CREATE TABLE habits (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						name TEXT NOT NULL,
						points INTEGER NOT NULL,
						decrease_points INTEGER NOT NULL DEFAULT 0,
						allow_negative INTEGER NOT NULL DEFAULT 0,
						once_per_day INTEGER NOT NULL DEFAULT 0,
						sort_order INTEGER NOT NULL DEFAULT 0
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
				if (oldVersion < 3) {
					await db.execute('ALTER TABLE habits ADD COLUMN allow_negative INTEGER NOT NULL DEFAULT 0');
				}
				if (oldVersion < 4) {
					await db.execute('ALTER TABLE habits ADD COLUMN once_per_day INTEGER NOT NULL DEFAULT 0');
				}
				if (oldVersion < 5) {
					await db.execute('ALTER TABLE students ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0');
				}
				if (oldVersion < 6) {
					final colsHabits = await db.rawQuery('PRAGMA table_info(habits)');
					final names = colsHabits.map((e) => e['name'] as String).toSet();
				if (!names.contains('decrease_points')) {
					await db.execute('ALTER TABLE habits ADD COLUMN decrease_points INTEGER');
				}
				await db.execute('UPDATE habits SET decrease_points = points WHERE decrease_points IS NULL');
			}
			if (oldVersion < 7) {
				final colsHabits = await db.rawQuery('PRAGMA table_info(habits)');
				final names = colsHabits.map((e) => e['name'] as String).toSet();
				if (!names.contains('sort_order')) {
					await db.execute('ALTER TABLE habits ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0');
				}
				}
				// Ensure new student columns exist on upgrade
				final colsStudentsU = await db.rawQuery('PRAGMA table_info(students)');
				final sNamesU = colsStudentsU.map((e) => e['name'] as String).toSet();
				if (!sNamesU.contains('date_of_birth')) await db.execute('ALTER TABLE students ADD COLUMN date_of_birth TEXT');
				if (!sNamesU.contains('school_name')) await db.execute('ALTER TABLE students ADD COLUMN school_name TEXT');
				if (!sNamesU.contains('father_name')) await db.execute('ALTER TABLE students ADD COLUMN father_name TEXT');
				if (!sNamesU.contains('mother_name')) await db.execute('ALTER TABLE students ADD COLUMN mother_name TEXT');
				if (!sNamesU.contains('phone_number')) await db.execute('ALTER TABLE students ADD COLUMN phone_number TEXT');
				if (!sNamesU.contains('birth_place')) await db.execute('ALTER TABLE students ADD COLUMN birth_place TEXT');
				if (!sNamesU.contains('grade')) await db.execute('ALTER TABLE students ADD COLUMN grade TEXT');
			},
			onOpen: (db) async {
				// Defensive: ensure columns exist in case prior migration was skipped
				final colsHabits = await db.rawQuery('PRAGMA table_info(habits)');
				final names = colsHabits.map((e) => e['name'] as String).toSet();
				if (!names.contains('allow_negative')) {
					await db.execute('ALTER TABLE habits ADD COLUMN allow_negative INTEGER NOT NULL DEFAULT 0');
				}
				if (!names.contains('once_per_day')) {
					await db.execute('ALTER TABLE habits ADD COLUMN once_per_day INTEGER NOT NULL DEFAULT 0');
				}
				if (!names.contains('decrease_points')) {
					await db.execute('ALTER TABLE habits ADD COLUMN decrease_points INTEGER');
					await db.execute('UPDATE habits SET decrease_points = points WHERE decrease_points IS NULL');
				}
				if (!names.contains('sort_order')) {
					await db.execute('ALTER TABLE habits ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0');
				}
				final colsStudents = await db.rawQuery('PRAGMA table_info(students)');
				final sNames = colsStudents.map((e) => e['name'] as String).toSet();
				if (!sNames.contains('sort_order')) {
					await db.execute('ALTER TABLE students ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0');
				}
				// Ensure new student info columns also exist
				if (!sNames.contains('date_of_birth')) {
					await db.execute('ALTER TABLE students ADD COLUMN date_of_birth TEXT');
				}
				if (!sNames.contains('school_name')) {
					await db.execute('ALTER TABLE students ADD COLUMN school_name TEXT');
				}
				if (!sNames.contains('father_name')) {
					await db.execute('ALTER TABLE students ADD COLUMN father_name TEXT');
				}
				if (!sNames.contains('mother_name')) {
					await db.execute('ALTER TABLE students ADD COLUMN mother_name TEXT');
				}
				if (!sNames.contains('phone_number')) {
					await db.execute('ALTER TABLE students ADD COLUMN phone_number TEXT');
				}
					if (!sNames.contains('birth_place')) {
					await db.execute('ALTER TABLE students ADD COLUMN birth_place TEXT');
				}
					if (!sNames.contains('grade')) {
						await db.execute('ALTER TABLE students ADD COLUMN grade TEXT');
					}
			},
		);
	}
}


