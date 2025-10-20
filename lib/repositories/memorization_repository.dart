import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';
import '../models/memorized_section.dart';

class MemorizationRepository {
    Future<List<MemorizedSection>> listForStudent(int studentId, {String? label}) async {
        final db = await AppDatabase().database;
        final where = StringBuffer('student_id = ?');
        final whereArgs = <Object?>[studentId];
        if (label != null && label.trim().isNotEmpty) {
            where.write(' AND label = ?');
            whereArgs.add(label.trim());
        }
        final rows = await db.query(
            'quran_memorization',
            where: where.toString(),
            whereArgs: whereArgs,
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
        // Ensure label is trimmed or null
        final label = (map['label'] as String?)?.trim();
        map['label'] = (label == null || label.isEmpty) ? null : label;
        return db.insert('quran_memorization', map, conflictAlgorithm: ConflictAlgorithm.abort);
    }

    Future<void> delete(int id) async {
        final db = await AppDatabase().database;
        await db.delete('quran_memorization', where: 'id = ?', whereArgs: [id]);
    }
}


