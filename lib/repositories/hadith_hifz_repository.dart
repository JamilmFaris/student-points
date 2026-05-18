import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';
import '../models/hadith_hifz_section.dart';

class HadithHifzRepository {
    Future<List<HadithHifzSection>> listForStudent(int studentId) async {
        final db = await AppDatabase().database;
        final rows = await db.query(
            'hadith_hifz',
            where: "student_id = ? AND (sync_status IS NULL OR sync_status != 'pending_delete')",
            whereArgs: [studentId],
            orderBy: 'date DESC, id DESC',
        );
        return rows.map((e) => HadithHifzSection.fromMap(Map<String, dynamic>.from(e))).toList();
    }

    Future<int> insert(HadithHifzSection section) async {
        final db = await AppDatabase().database;
        final map = section.toMap()..remove('id');
        map['created_at'] ??= DateTime.now().toIso8601String();
        map['sync_status'] = 'pending_create';
        map['last_modified'] = DateTime.now().toUtc().toIso8601String();
        return db.insert('hadith_hifz', map, conflictAlgorithm: ConflictAlgorithm.abort);
    }

    Future<void> delete(int id) async {
        final db = await AppDatabase().database;
        final rows = await db.query('hadith_hifz',
            columns: ['remote_id'], where: 'id = ?', whereArgs: [id], limit: 1);
        if (rows.isEmpty || rows.first['remote_id'] == null) {
            await db.delete('hadith_hifz', where: 'id = ?', whereArgs: [id]);
            return;
        }
        final now = DateTime.now().toUtc().toIso8601String();
        await db.update('hadith_hifz',
            {'sync_status': 'pending_delete', 'last_modified': now},
            where: 'id = ?', whereArgs: [id]);
    }
}
