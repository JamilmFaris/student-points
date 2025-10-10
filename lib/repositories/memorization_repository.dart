import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';
import '../models/memorized_section.dart';

class MemorizationRepository {
    Future<List<MemorizedSection>> listForStudent(int studentId) async {
        final db = await AppDatabase().database;
        final rows = await db.query(
            'quran_memorization',
            where: 'student_id = ?',
            whereArgs: [studentId],
            orderBy: 'created_at DESC, id DESC',
        );
        return rows.map((e) => MemorizedSection.fromMap(e)).toList();
    }

    Future<int> insert(MemorizedSection section) async {
        final db = await AppDatabase().database;
        final map = section.toMap()..remove('id');
        // Ensure insertion timestamp is current time if not provided
        map['created_at'] ??= DateTime.now().toIso8601String();
        // Backfill memorized_on from created_at date part if not provided
        map['memorized_on'] ??= (map['created_at'] as String).substring(0, 10);
        return db.insert('quran_memorization', map, conflictAlgorithm: ConflictAlgorithm.abort);
    }

    Future<void> delete(int id) async {
        final db = await AppDatabase().database;
        await db.delete('quran_memorization', where: 'id = ?', whereArgs: [id]);
    }
}


