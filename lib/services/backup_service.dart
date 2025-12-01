import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:intl/intl.dart';

import '../data/app_database.dart';

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
		// Unfiltered file picker: let the user choose any file
		final picked = await FilePicker.platform.pickFiles(
			type: FileType.any,
			allowMultiple: false,
			withData: false,
			lockParentWindow: true,
		);
		final path = picked?.files.single.path;
		if (path == null) return;

		final appDb = AppDatabase();
		// Close DB so we can replace it safely
		await appDb.close();

		final destPath = await appDb.dbPath;
		// Replace DB file
		await File(path).copy(destPath);

		// Clean up WAL/SHM from prior runs if any
		final wal = File('$destPath-wal');
		final shm = File('$destPath-shm');
		if (await wal.exists()) await wal.delete();
		if (await shm.exists()) await shm.delete();

		// Reopen (migrations run if needed)
		await appDb.reopen();
	}
}



