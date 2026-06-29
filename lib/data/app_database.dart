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

	// Returns the absolute path to the SQLite database file.
	Future<String> get dbPath async {
		final dbDir = await getDatabasesPath();
		return p.join(dbDir, 'student_points.db');
	}

	// Forces a WAL checkpoint so the main db file contains all recent changes.
	Future<void> checkpoint() async {
		if (_db != null) {
			await _db!.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
		}
	}

	// Closes the current database instance (if any) so files can be replaced.
	Future<void> close() async {
		if (_db != null) {
			await _db!.close();
			_db = null;
		}
	}

	// Reopens the database, triggering migrations if needed.
	Future<void> reopen() async {
		await close();
		await database;
	}

	Future<Database> _openDatabase() async {
		final dbDir = await getDatabasesPath();
		final dbPath = p.join(dbDir, 'student_points.db');
		return openDatabase(
			dbPath,
			version: 19,
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
						grade TEXT,
						sync_status TEXT NOT NULL DEFAULT 'synced',
						remote_id INTEGER,
						last_modified TEXT,
						server_updated_at TEXT,
						archived INTEGER NOT NULL DEFAULT 0
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
						sort_order INTEGER NOT NULL DEFAULT 0,
						remote_id INTEGER,
						sync_status TEXT NOT NULL DEFAULT 'pending_create',
						archived INTEGER NOT NULL DEFAULT 0
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
						sync_status TEXT NOT NULL DEFAULT 'synced',
						remote_id INTEGER,
						last_modified TEXT,
						server_updated_at TEXT,
						UNIQUE(date, student_id, habit_id),
						FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE,
						FOREIGN KEY(habit_id) REFERENCES habits(id) ON DELETE CASCADE
					);
				''');
				await db.execute('''
					CREATE TABLE sync_queue (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						operation TEXT NOT NULL,
						payload TEXT NOT NULL,
						created_at TEXT NOT NULL,
						status TEXT NOT NULL DEFAULT 'pending',
						error_message TEXT
					);
				''');
				await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue(status)');
				await db.execute('''
					CREATE TABLE lessons (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						date TEXT NOT NULL UNIQUE,
						subject TEXT NOT NULL DEFAULT '',
						sync_status TEXT NOT NULL DEFAULT 'pending_create',
						remote_id INTEGER,
						last_modified TEXT,
						server_updated_at TEXT,
						attendance_pushed_at TEXT
					);
				''');
				await db.execute('CREATE INDEX IF NOT EXISTS idx_lessons_date ON lessons(date)');
				await db.execute('''
					CREATE TABLE IF NOT EXISTS quran_sabr (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						student_id INTEGER NOT NULL,
						sabr_type TEXT NOT NULL,
						range_from INTEGER NOT NULL,
						range_to INTEGER NOT NULL,
						created_at TEXT NOT NULL DEFAULT (datetime('now')),
						sync_status TEXT NOT NULL DEFAULT 'pending_create',
						remote_id INTEGER,
						last_modified TEXT,
						FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE
					);
				''');
				await db.execute('CREATE INDEX IF NOT EXISTS idx_quran_sabr_student ON quran_sabr(student_id)');
				await db.execute('''
					CREATE TABLE IF NOT EXISTS hadith_sabr (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						student_id INTEGER NOT NULL,
						hadith_type TEXT NOT NULL,
						created_at TEXT NOT NULL DEFAULT (datetime('now')),
						sync_status TEXT NOT NULL DEFAULT 'pending_create',
						remote_id INTEGER,
						last_modified TEXT,
						FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE
					);
				''');
				await db.execute('CREATE INDEX IF NOT EXISTS idx_hadith_sabr_student ON hadith_sabr(student_id)');
				await db.execute('''
					CREATE TABLE IF NOT EXISTS hadith_hifz (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						student_id INTEGER NOT NULL,
						hadith_numbers TEXT NOT NULL,
						notes TEXT,
						label TEXT,
						date TEXT NOT NULL,
						created_at TEXT NOT NULL DEFAULT (datetime('now')),
						sync_status TEXT NOT NULL DEFAULT 'pending_create',
						remote_id INTEGER,
						last_modified TEXT,
						server_updated_at TEXT,
						FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE
					);
				''');
				await db.execute('CREATE INDEX IF NOT EXISTS idx_hadith_hifz_student ON hadith_hifz(student_id)');
			},
			onUpgrade: (db, oldVersion, newVersion) async {
			// All ALTER TABLE calls are guarded with PRAGMA table_info checks so that
			// restoring an older backup that already has some columns doesn't crash.
			if (oldVersion < 2) {
				final colsDe = await db.rawQuery('PRAGMA table_info(daily_entries)');
				final deNames = colsDe.map((e) => e['name'] as String).toSet();
				if (!deNames.contains('points_earned')) {
					await db.execute('ALTER TABLE daily_entries ADD COLUMN points_earned INTEGER');
				}
				await db.execute('''
					UPDATE daily_entries
					SET points_earned = (
						SELECT points FROM habits WHERE habits.id = daily_entries.habit_id
					) * count
					WHERE points_earned IS NULL;
				''');
			}
			if (oldVersion < 3) {
				final colsH = await db.rawQuery('PRAGMA table_info(habits)');
				final hNames = colsH.map((e) => e['name'] as String).toSet();
				if (!hNames.contains('allow_negative')) {
					await db.execute('ALTER TABLE habits ADD COLUMN allow_negative INTEGER NOT NULL DEFAULT 0');
				}
			}
			if (oldVersion < 4) {
				final colsH = await db.rawQuery('PRAGMA table_info(habits)');
				final hNames = colsH.map((e) => e['name'] as String).toSet();
				if (!hNames.contains('once_per_day')) {
					await db.execute('ALTER TABLE habits ADD COLUMN once_per_day INTEGER NOT NULL DEFAULT 0');
				}
			}
			if (oldVersion < 5) {
				final colsS = await db.rawQuery('PRAGMA table_info(students)');
				final sNames = colsS.map((e) => e['name'] as String).toSet();
				if (!sNames.contains('sort_order')) {
					await db.execute('ALTER TABLE students ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0');
				}
			}
			if (oldVersion < 6) {
				final colsH = await db.rawQuery('PRAGMA table_info(habits)');
				final hNames = colsH.map((e) => e['name'] as String).toSet();
				if (!hNames.contains('decrease_points')) {
					await db.execute('ALTER TABLE habits ADD COLUMN decrease_points INTEGER');
				}
				await db.execute('UPDATE habits SET decrease_points = points WHERE decrease_points IS NULL');
			}
			if (oldVersion < 7) {
				final colsH = await db.rawQuery('PRAGMA table_info(habits)');
				final hNames = colsH.map((e) => e['name'] as String).toSet();
				if (!hNames.contains('sort_order')) {
					await db.execute('ALTER TABLE habits ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0');
				}
			}
			// v8: add Quran memorization table
			// Juz (part) grouping for display is computed from surah_index and ayah_from/ayah_to
			// at runtime using lib/data/juz_data.dart (no juz column stored).
			if (oldVersion < 8) {
				await db.execute('''
					CREATE TABLE IF NOT EXISTS quran_memorization (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						student_id INTEGER NOT NULL,
						surah_index INTEGER NOT NULL,
						ayah_from INTEGER NOT NULL,
						ayah_to INTEGER NOT NULL,
						created_at TEXT NOT NULL DEFAULT (datetime('now')),
						memorized_on TEXT,
						label TEXT,
						FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE
					);
				''');
				await db.execute('CREATE INDEX IF NOT EXISTS idx_qm_student ON quran_memorization(student_id)');
				await db.execute('CREATE INDEX IF NOT EXISTS idx_qm_surah ON quran_memorization(surah_index)');
			}
			// v9: add memorized_on (date-only) separate from created_at (insert time)
			if (oldVersion < 9) {
				final cols = await db.rawQuery('PRAGMA table_info(quran_memorization)');
				final qmNames = cols.map((e) => e['name'] as String).toSet();
				if (!qmNames.contains('memorized_on')) {
					await db.execute('ALTER TABLE quran_memorization ADD COLUMN memorized_on TEXT');
					await db.execute("UPDATE quran_memorization SET memorized_on = substr(created_at, 1, 10) WHERE memorized_on IS NULL");
				}
			}
			// v10: add label column for kind (حفظ/مراجعة/تثبيت)
			if (oldVersion < 10) {
				final cols = await db.rawQuery('PRAGMA table_info(quran_memorization)');
				final qmNames = cols.map((e) => e['name'] as String).toSet();
				if (!qmNames.contains('label')) {
					await db.execute('ALTER TABLE quran_memorization ADD COLUMN label TEXT');
				}
			}
			// v11: add student_notes table (notebook for each student)
			if (oldVersion < 11) {
				await db.execute('''
					CREATE TABLE IF NOT EXISTS student_notes (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						student_id INTEGER NOT NULL,
						title TEXT NOT NULL,
						note_text TEXT,
						created_at TEXT NOT NULL DEFAULT (datetime('now')),
						updated_at TEXT NOT NULL DEFAULT (datetime('now')),
						FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE
					);
				''');
				await db.execute('CREATE INDEX IF NOT EXISTS idx_student_notes_student ON student_notes(student_id)');
			}
			// v12: add sync columns + sync_queue table for backend integration.
			// Habits stay local-only (not synced), so they don't get sync columns.
			if (oldVersion < 12) {
				for (final table in ['students', 'daily_entries', 'quran_memorization']) {
					final cols = await db.rawQuery('PRAGMA table_info($table)');
					final names = cols.map((e) => e['name'] as String).toSet();
					if (!names.contains('sync_status')) {
						await db.execute("ALTER TABLE $table ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'synced'");
					}
					if (!names.contains('remote_id')) {
						await db.execute('ALTER TABLE $table ADD COLUMN remote_id INTEGER');
					}
					if (!names.contains('last_modified')) {
						await db.execute('ALTER TABLE $table ADD COLUMN last_modified TEXT');
					}
					if (!names.contains('server_updated_at')) {
						await db.execute('ALTER TABLE $table ADD COLUMN server_updated_at TEXT');
					}
				}
				await db.execute('''
					CREATE TABLE IF NOT EXISTS sync_queue (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						operation TEXT NOT NULL,
						payload TEXT NOT NULL,
						created_at TEXT NOT NULL,
						status TEXT NOT NULL DEFAULT 'pending',
						error_message TEXT
					);
				''');
				await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue(status)');
			}
			// v13: freeform notes on quran_memorization (mirrors server `notes` field).
			if (oldVersion < 13) {
				final cols = await db.rawQuery('PRAGMA table_info(quran_memorization)');
				final qmNames = cols.map((e) => e['name'] as String).toSet();
				if (!qmNames.contains('notes')) {
					await db.execute('ALTER TABLE quran_memorization ADD COLUMN notes TEXT');
				}
			}
			// v14: flip legacy daily_entries (created before backend integration) to
			// pending_create so they get picked up by the first batch push. Rows that
			// were inserted post-v12 by the new code path already carry last_modified;
			// pre-existing rows have last_modified IS NULL.
			if (oldVersion < 14) {
				await db.execute(
					"UPDATE daily_entries SET sync_status = 'pending_create' "
					"WHERE last_modified IS NULL AND sync_status = 'synced'");
			}
			// v15: lessons table — one row per tracking-points day. Pushed to
			// the server so that attendance (per lesson, per date) has a parent.
			if (oldVersion < 15) {
				await db.execute('''
					CREATE TABLE IF NOT EXISTS lessons (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						date TEXT NOT NULL UNIQUE,
						subject TEXT NOT NULL DEFAULT '',
						sync_status TEXT NOT NULL DEFAULT 'pending_create',
						remote_id INTEGER,
						last_modified TEXT,
						server_updated_at TEXT,
						attendance_pushed_at TEXT
					);
				''');
				await db.execute('CREATE INDEX IF NOT EXISTS idx_lessons_date ON lessons(date)');
				// Backfill: one lesson per existing distinct daily_entries date.
				final dates = await db.rawQuery(
					'SELECT DISTINCT date FROM daily_entries ORDER BY date ASC');
				final nowIso = DateTime.now().toUtc().toIso8601String();
				for (final r in dates) {
					await db.insert('lessons', {
						'date': r['date'],
						'subject': '',
						'sync_status': 'pending_create',
						'last_modified': nowIso,
					});
				}
			}
			// v16: habits now sync to backend — add remote_id and sync_status.
			// Existing habits are marked pending_create so they upload on next sync.
			if (oldVersion < 16) {
				final cols = await db.rawQuery('PRAGMA table_info(habits)');
				final hNames = cols.map((e) => e['name'] as String).toSet();
				if (!hNames.contains('remote_id')) {
					await db.execute('ALTER TABLE habits ADD COLUMN remote_id INTEGER');
				}
				if (!hNames.contains('sync_status')) {
					await db.execute("ALTER TABLE habits ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'pending_create'");
					await db.execute("UPDATE habits SET sync_status = 'pending_create' WHERE sync_status IS NULL");
				}
			}
			// v17: local quran_sabr and hadith_sabr tables (pushed to server on sync).
			if (oldVersion < 17) {
				await db.execute('''
					CREATE TABLE IF NOT EXISTS quran_sabr (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						student_id INTEGER NOT NULL,
						sabr_type TEXT NOT NULL,
						range_from INTEGER NOT NULL,
						range_to INTEGER NOT NULL,
						created_at TEXT NOT NULL DEFAULT (datetime('now')),
						sync_status TEXT NOT NULL DEFAULT 'pending_create',
						remote_id INTEGER,
						last_modified TEXT,
						FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE
					);
				''');
				await db.execute('CREATE INDEX IF NOT EXISTS idx_quran_sabr_student ON quran_sabr(student_id)');
				await db.execute('''
					CREATE TABLE IF NOT EXISTS hadith_sabr (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						student_id INTEGER NOT NULL,
						hadith_type TEXT NOT NULL,
						created_at TEXT NOT NULL DEFAULT (datetime('now')),
						sync_status TEXT NOT NULL DEFAULT 'pending_create',
						remote_id INTEGER,
						last_modified TEXT,
						FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE
					);
				''');
				await db.execute('CREATE INDEX IF NOT EXISTS idx_hadith_sabr_student ON hadith_sabr(student_id)');
			}
			// v18: hadith_hifz table — stores memorized hadith entries per student.
			if (oldVersion < 18) {
				await db.execute('''
					CREATE TABLE IF NOT EXISTS hadith_hifz (
						id INTEGER PRIMARY KEY AUTOINCREMENT,
						student_id INTEGER NOT NULL,
						hadith_numbers TEXT NOT NULL,
						notes TEXT,
						label TEXT,
						date TEXT NOT NULL,
						created_at TEXT NOT NULL DEFAULT (datetime('now')),
						sync_status TEXT NOT NULL DEFAULT 'pending_create',
						remote_id INTEGER,
						last_modified TEXT,
						server_updated_at TEXT,
						FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE
					);
				''');
				await db.execute('CREATE INDEX IF NOT EXISTS idx_hadith_hifz_student ON hadith_hifz(student_id)');
			}
			// v19: local-only "archived" flag on students/habits. Deleting an entity
			// that has point history archives it (hidden from active screens, kept
			// for logs/sync) instead of removing it and orphaning its daily_entries.
			if (oldVersion < 19) {
				for (final table in ['students', 'habits']) {
					final cols = await db.rawQuery('PRAGMA table_info($table)');
					final names = cols.map((e) => e['name'] as String).toSet();
					if (!names.contains('archived')) {
						await db.execute('ALTER TABLE $table ADD COLUMN archived INTEGER NOT NULL DEFAULT 0');
					}
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
				if (!names.contains('remote_id')) {
					await db.execute('ALTER TABLE habits ADD COLUMN remote_id INTEGER');
				}
				if (!names.contains('sync_status')) {
					await db.execute("ALTER TABLE habits ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'pending_create'");
					await db.execute("UPDATE habits SET sync_status = 'pending_create' WHERE sync_status IS NULL");
				}
				if (!names.contains('archived')) {
					await db.execute('ALTER TABLE habits ADD COLUMN archived INTEGER NOT NULL DEFAULT 0');
				}
				final colsStudents = await db.rawQuery('PRAGMA table_info(students)');
				final sNames = colsStudents.map((e) => e['name'] as String).toSet();
				if (!sNames.contains('sort_order')) {
					await db.execute('ALTER TABLE students ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0');
				}
				if (!sNames.contains('archived')) {
					await db.execute('ALTER TABLE students ADD COLUMN archived INTEGER NOT NULL DEFAULT 0');
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
					// Ensure quran_memorization table exists (defensive)
					// Juz grouping uses lib/data/juz_data.dart; no juz column in schema.
					await db.execute('''
						CREATE TABLE IF NOT EXISTS quran_memorization (
							id INTEGER PRIMARY KEY AUTOINCREMENT,
							student_id INTEGER NOT NULL,
							surah_index INTEGER NOT NULL,
							ayah_from INTEGER NOT NULL,
							ayah_to INTEGER NOT NULL,
							created_at TEXT NOT NULL DEFAULT (datetime('now')),
							memorized_on TEXT,
							label TEXT,
							FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE
						);
					''');
					await db.execute('CREATE INDEX IF NOT EXISTS idx_qm_student ON quran_memorization(student_id)');
					await db.execute('CREATE INDEX IF NOT EXISTS idx_qm_surah ON quran_memorization(surah_index)');
					// Defensive: ensure columns exist
					final cols = await db.rawQuery('PRAGMA table_info(quran_memorization)');
					final qmNames = cols.map((e) => e['name'] as String).toSet();
					if (!qmNames.contains('memorized_on')) {
						await db.execute('ALTER TABLE quran_memorization ADD COLUMN memorized_on TEXT');
					}
					if (!qmNames.contains('label')) {
						await db.execute('ALTER TABLE quran_memorization ADD COLUMN label TEXT');
					}
					if (!qmNames.contains('notes')) {
						await db.execute('ALTER TABLE quran_memorization ADD COLUMN notes TEXT');
					}
					// Ensure student_notes table exists (defensive)
					await db.execute('''
						CREATE TABLE IF NOT EXISTS student_notes (
							id INTEGER PRIMARY KEY AUTOINCREMENT,
							student_id INTEGER NOT NULL,
							title TEXT NOT NULL,
							note_text TEXT,
							created_at TEXT NOT NULL DEFAULT (datetime('now')),
							updated_at TEXT NOT NULL DEFAULT (datetime('now')),
							FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE
						);
					''');
					await db.execute('CREATE INDEX IF NOT EXISTS idx_student_notes_student ON student_notes(student_id)');
					// Defensive: ensure sync columns + sync_queue exist (for restored backups
					// that pre-date v12). Habits remain local-only.
					for (final table in ['students', 'daily_entries', 'quran_memorization']) {
						final cols = await db.rawQuery('PRAGMA table_info($table)');
						final names = cols.map((e) => e['name'] as String).toSet();
						if (!names.contains('sync_status')) {
							await db.execute("ALTER TABLE $table ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'synced'");
						}
						if (!names.contains('remote_id')) {
							await db.execute('ALTER TABLE $table ADD COLUMN remote_id INTEGER');
						}
						if (!names.contains('last_modified')) {
							await db.execute('ALTER TABLE $table ADD COLUMN last_modified TEXT');
						}
						if (!names.contains('server_updated_at')) {
							await db.execute('ALTER TABLE $table ADD COLUMN server_updated_at TEXT');
						}
					}
					await db.execute('''
						CREATE TABLE IF NOT EXISTS sync_queue (
							id INTEGER PRIMARY KEY AUTOINCREMENT,
							operation TEXT NOT NULL,
							payload TEXT NOT NULL,
							created_at TEXT NOT NULL,
							status TEXT NOT NULL DEFAULT 'pending',
							error_message TEXT
						);
					''');
					await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue(status)');
					// Ensure lessons table exists (defensive)
					await db.execute('''
						CREATE TABLE IF NOT EXISTS lessons (
							id INTEGER PRIMARY KEY AUTOINCREMENT,
							date TEXT NOT NULL UNIQUE,
							subject TEXT NOT NULL DEFAULT '',
							sync_status TEXT NOT NULL DEFAULT 'pending_create',
							remote_id INTEGER,
							last_modified TEXT,
							server_updated_at TEXT,
							attendance_pushed_at TEXT
						);
					''');
					await db.execute('CREATE INDEX IF NOT EXISTS idx_lessons_date ON lessons(date)');
					// Defensive: ensure sabr tables exist
					await db.execute('''
						CREATE TABLE IF NOT EXISTS quran_sabr (
							id INTEGER PRIMARY KEY AUTOINCREMENT,
							student_id INTEGER NOT NULL,
							sabr_type TEXT NOT NULL,
							range_from INTEGER NOT NULL,
							range_to INTEGER NOT NULL,
							created_at TEXT NOT NULL DEFAULT (datetime('now')),
							sync_status TEXT NOT NULL DEFAULT 'pending_create',
							remote_id INTEGER,
							last_modified TEXT,
							FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE
						);
					''');
					await db.execute('CREATE INDEX IF NOT EXISTS idx_quran_sabr_student ON quran_sabr(student_id)');
					await db.execute('''
						CREATE TABLE IF NOT EXISTS hadith_sabr (
							id INTEGER PRIMARY KEY AUTOINCREMENT,
							student_id INTEGER NOT NULL,
							hadith_type TEXT NOT NULL,
							created_at TEXT NOT NULL DEFAULT (datetime('now')),
							sync_status TEXT NOT NULL DEFAULT 'pending_create',
							remote_id INTEGER,
							last_modified TEXT,
							FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE
						);
					''');
					await db.execute('CREATE INDEX IF NOT EXISTS idx_hadith_sabr_student ON hadith_sabr(student_id)');
						// Defensive: ensure hadith_hifz table exists
						await db.execute('''
							CREATE TABLE IF NOT EXISTS hadith_hifz (
								id INTEGER PRIMARY KEY AUTOINCREMENT,
								student_id INTEGER NOT NULL,
								hadith_numbers TEXT NOT NULL,
								notes TEXT,
								label TEXT,
								date TEXT NOT NULL,
								created_at TEXT NOT NULL DEFAULT (datetime('now')),
								sync_status TEXT NOT NULL DEFAULT 'pending_create',
								remote_id INTEGER,
								last_modified TEXT,
								server_updated_at TEXT,
								FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE
							);
						''');
						await db.execute('CREATE INDEX IF NOT EXISTS idx_hadith_hifz_student ON hadith_hifz(student_id)');
			},
		);
	}
}


