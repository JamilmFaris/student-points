import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';
import '../models/lesson.dart';

class LessonRepository {
  Future<Lesson?> getByDate(String dateIso) async {
    final db = await AppDatabase().database;
    final rows = await db.query(
      'lessons',
      where: 'date = ?',
      whereArgs: [dateIso],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Lesson.fromMap(rows.first);
  }

  /// Returns the lesson for [date], creating one if none exists. Auto-created
  /// rows are marked `pending_create` so SyncService picks them up.
  Future<Lesson> ensureForDate(DateTime date) async {
    final dateIso = date.toIso8601String().substring(0, 10);
    final existing = await getByDate(dateIso);
    if (existing != null) return existing;
    final db = await AppDatabase().database;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final id = await db.insert(
      'lessons',
      {
        'date': dateIso,
        'subject': '',
        'sync_status': 'pending_create',
        'last_modified': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return Lesson(id: id, date: dateIso, subject: '');
  }

  Future<void> updateSubject(int id, String subject) async {
    final db = await AppDatabase().database;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final row = await db.query('lessons',
        columns: ['remote_id', 'sync_status'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1);
    String nextStatus = 'pending_create';
    if (row.isNotEmpty && row.first['remote_id'] != null) {
      nextStatus = 'pending_update';
    } else if (row.isNotEmpty &&
        row.first['sync_status'] == 'pending_create') {
      nextStatus = 'pending_create';
    }
    await db.update(
      'lessons',
      {
        'subject': subject,
        'sync_status': nextStatus,
        'last_modified': nowIso,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
