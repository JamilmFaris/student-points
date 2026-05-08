import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../api/dto/hifz_dto.dart';
import '../api/dto/student_dto.dart';
import '../api/services/hifz_api.dart';
import '../api/services/students_api.dart';
import '../data/app_database.dart';

class SyncResult {
  const SyncResult({
    required this.studentsPulled,
    required this.studentsDeleted,
    required this.hifzPulled,
    required this.hifzDeleted,
    this.skippedHifz = 0,
  });

  final int studentsPulled;
  final int studentsDeleted;
  final int hifzPulled;
  final int hifzDeleted;
  final int skippedHifz;
}

class SyncService {
  SyncService({
    required this.studentsApi,
    required this.hifzApi,
    AppDatabase? db,
  }) : _db = db ?? AppDatabase();

  static const _lastSyncKey = 'sync.last_at';

  final StudentsApi studentsApi;
  final HifzApi hifzApi;
  final AppDatabase _db;

  Future<DateTime?> readLastSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_lastSyncKey);
    return iso == null ? null : DateTime.tryParse(iso);
  }

  Future<void> _writeLastSyncAt(DateTime t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, t.toUtc().toIso8601String());
  }

  /// Full pull. Used right after login per linking.md §6.1. The server may have
  /// data from another device, so we don't filter by `updated_since`.
  Future<SyncResult> performLoginSync() async {
    final db = await _db.database;
    final students = await studentsApi.getAll();
    final hifz = await hifzApi.getAll();

    final studentStats = await _mergeStudents(db, students);
    final hifzStats = await _mergeHifz(db, hifz);

    await _writeLastSyncAt(DateTime.now());
    return SyncResult(
      studentsPulled: studentStats.pulled,
      studentsDeleted: studentStats.deleted,
      hifzPulled: hifzStats.pulled,
      hifzDeleted: hifzStats.deleted,
      skippedHifz: hifzStats.skipped,
    );
  }

  /// Delta pull using `updated_since=<lastSyncAt>`. Includes tombstones.
  Future<SyncResult> performDeltaSync() async {
    final last = await readLastSyncAt();
    if (last == null) return performLoginSync();

    final db = await _db.database;
    final students = await studentsApi.getAll(updatedSince: last);
    final hifz = await hifzApi.getAll(updatedSince: last);

    final studentStats = await _mergeStudents(db, students);
    final hifzStats = await _mergeHifz(db, hifz);

    await _writeLastSyncAt(DateTime.now());
    return SyncResult(
      studentsPulled: studentStats.pulled,
      studentsDeleted: studentStats.deleted,
      hifzPulled: hifzStats.pulled,
      hifzDeleted: hifzStats.deleted,
      skippedHifz: hifzStats.skipped,
    );
  }

  Future<_MergeStats> _mergeStudents(Database db, List<StudentDto> remote) async {
    int pulled = 0;
    int deleted = 0;
    await db.transaction((txn) async {
      for (final s in remote) {
        final existing = await txn.query(
          'students',
          where: 'remote_id = ?',
          whereArgs: [s.id],
          limit: 1,
        );
        if (s.isDeleted) {
          if (existing.isNotEmpty) {
            await txn.delete('students', where: 'id = ?', whereArgs: [existing.first['id']]);
            deleted++;
          }
          continue;
        }
        final values = <String, Object?>{
          'name': s.joinedName,
          'date_of_birth': s.dateOfBirth,
          'school_name': s.school,
          'father_name': s.fatherName,
          'mother_name': s.motherName,
          'phone_number': s.phoneNumber,
          'birth_place': s.birthPlace,
          'remote_id': s.id,
          'sync_status': 'synced',
          'server_updated_at': s.updatedAt,
        };
        if (existing.isEmpty) {
          await txn.insert('students', values);
        } else {
          await txn.update('students', values,
              where: 'id = ?', whereArgs: [existing.first['id']]);
        }
        pulled++;
      }
    });
    return _MergeStats(pulled: pulled, deleted: deleted);
  }

  Future<_MergeStats> _mergeHifz(Database db, List<HifzDto> remote) async {
    int pulled = 0;
    int deleted = 0;
    int skipped = 0;
    await db.transaction((txn) async {
      // Build server_student_id → local_student_id index once.
      final studentMap = <int, int>{};
      final localStudents = await txn.query(
        'students',
        columns: ['id', 'remote_id'],
        where: 'remote_id IS NOT NULL',
      );
      for (final r in localStudents) {
        studentMap[r['remote_id'] as int] = r['id'] as int;
      }

      for (final h in remote) {
        final existing = await txn.query(
          'quran_memorization',
          where: 'remote_id = ?',
          whereArgs: [h.id],
          limit: 1,
        );
        if (h.isDeleted) {
          if (existing.isNotEmpty) {
            await txn.delete('quran_memorization',
                where: 'id = ?', whereArgs: [existing.first['id']]);
            deleted++;
          }
          continue;
        }
        final localStudentId = studentMap[h.studentId];
        if (localStudentId == null) {
          // Server hifz row references a student that has no local mirror yet.
          // Skip — will be picked up on the next sync once the student is pulled.
          skipped++;
          continue;
        }
        final values = <String, Object?>{
          'student_id': localStudentId,
          'surah_index': h.chapterIndex,
          'ayah_from': h.start,
          'ayah_to': h.end,
          'memorized_on': h.memorizedOnDate,
          'label': h.label,
          'notes': h.notes,
          'remote_id': h.id,
          'sync_status': 'synced',
          'server_updated_at': h.updatedAt,
        };
        if (existing.isEmpty) {
          // created_at has DEFAULT (datetime('now')) — let the column default fire.
          await txn.insert('quran_memorization', values);
        } else {
          await txn.update('quran_memorization', values,
              where: 'id = ?', whereArgs: [existing.first['id']]);
        }
        pulled++;
      }
    });
    return _MergeStats(pulled: pulled, deleted: deleted, skipped: skipped);
  }
}

class _MergeStats {
  const _MergeStats({required this.pulled, required this.deleted, this.skipped = 0});
  final int pulled;
  final int deleted;
  final int skipped;
}
