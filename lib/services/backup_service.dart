import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_database.dart';

const _keyAutoBackupPath = 'auto_backup_path';
const _keyLastBackupMs = 'last_backup_timestamp_ms';
const _keyHasAskedBackupPath = 'has_asked_backup_path';
const _backupFileName = 'student_points_backup.mosque';

class BackupService {
	static String _suggestedName() {
		final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
		return 'student_points_$ts.mosque';
	}

	static Future<void> exportDatabase() async {
		final appDb = AppDatabase();
		final db = await appDb.database;
		// Ensure all changes are in the main db file
		await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
		final srcPath = await appDb.dbPath;

		// Android/iOS: use SAF save dialog
		if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
			final params = SaveFileDialogParams(
				sourceFilePath: srcPath,
				fileName: _suggestedName(),
			);
			await FlutterFileDialog.saveFile(params: params);
			return;
		}

		// Desktop: native save dialog
		final savePath = await FilePicker.platform.saveFile(
			dialogTitle: 'Export database',
			fileName: _suggestedName(),
			type: FileType.custom,
			allowedExtensions: ['mosque'],
			lockParentWindow: true,
		);
		if (savePath == null) return;

		final bytes = await File(srcPath).readAsBytes();
		await File(savePath).writeAsBytes(bytes, flush: true);
	}

	static Future<void> importDatabase() async {
		// Use withData: true to avoid Android content-URI path issues (File() can't read content://)
		final picked = await FilePicker.platform.pickFiles(
			type: FileType.any,
			allowMultiple: false,
			withData: true,
			lockParentWindow: true,
		);
		final bytes = picked?.files.single.bytes;
		if (bytes == null) return;

		final appDb = AppDatabase();
		// Close DB so we can replace it safely
		await appDb.close();

		final destPath = await appDb.dbPath;
		// Write bytes directly (avoids path/URI issues on Android 10+)
		await File(destPath).writeAsBytes(bytes, flush: true);

		// Clean up WAL/SHM from prior runs if any
		final wal = File('$destPath-wal');
		final shm = File('$destPath-shm');
		if (await wal.exists()) await wal.delete();
		if (await shm.exists()) await shm.delete();

		// Reopen (migrations run if needed)
		await appDb.reopen();
	}

	// --- Auto-backup (weekly, overwrites same file) ---

	static Future<String> getDefaultBackupPath() async {
		final dir = await getApplicationDocumentsDirectory();
		final backupDir = Directory(p.join(dir.path, 'StudentPointsBackup'));
		if (!await backupDir.exists()) await backupDir.create(recursive: true);
		return p.join(backupDir.path, _backupFileName);
	}

	static Future<String?> pickBackupDirectory() async {
		final dir = await FilePicker.platform.getDirectoryPath(dialogTitle: 'اختر مجلد النسخ الاحتياطي');
		if (dir == null || dir.trim().isEmpty || dir == '/') return null;
		return p.join(dir, _backupFileName);
	}

	static Future<String> getAutoBackupPath() async {
		final prefs = await SharedPreferences.getInstance();
		final stored = prefs.getString(_keyAutoBackupPath);
		if (stored != null && stored.trim().isNotEmpty) return stored;
		final defaultPath = await getDefaultBackupPath();
		await prefs.setString(_keyAutoBackupPath, defaultPath);
		return defaultPath;
	}

	static Future<void> setAutoBackupPath(String path) async {
		final prefs = await SharedPreferences.getInstance();
		await prefs.setString(_keyAutoBackupPath, path);
	}

	static Future<bool> hasAskedBackupPath() async {
		final prefs = await SharedPreferences.getInstance();
		return prefs.getBool(_keyHasAskedBackupPath) ?? false;
	}

	static Future<void> setAskedBackupPath() async {
		final prefs = await SharedPreferences.getInstance();
		await prefs.setBool(_keyHasAskedBackupPath, true);
	}

	static Future<DateTime?> getLastBackupTime() async {
		final prefs = await SharedPreferences.getInstance();
		final ms = prefs.getInt(_keyLastBackupMs);
		return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
	}

	static Future<void> _setLastBackupTime(DateTime time) async {
		final prefs = await SharedPreferences.getInstance();
		await prefs.setInt(_keyLastBackupMs, time.millisecondsSinceEpoch);
	}

	/// Copies DB to dest path, overwriting. Caller must ensure path is writable.
	static Future<void> copyToPath(String destPath) async {
		final appDb = AppDatabase();
		final db = await appDb.database;
		await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
		final srcPath = await appDb.dbPath;
		final destFile = File(destPath);
		final destDir = destFile.parent;
		if (!await destDir.exists()) await destDir.create(recursive: true);
		final bytes = await File(srcPath).readAsBytes();
		await destFile.writeAsBytes(bytes, flush: true);
		await _setLastBackupTime(DateTime.now());
	}

	/// Returns true if backup was performed.
	static Future<bool> performAutoBackupIfNeeded() async {
		final last = await getLastBackupTime();
		final now = DateTime.now();
		if (last != null && now.difference(last).inDays < 7) return false;
		final path = await getAutoBackupPath();
		try {
			await copyToPath(path);
			return true;
		} catch (_) {
			return false;
		}
	}
}



