import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../api/dto/hifz_dto.dart';
import '../api/dto/student_dto.dart';
import '../api/services/_dio_error.dart';
import '../api/services/habits_api.dart';
import '../api/services/hifz_api.dart';
import '../api/services/student_points_api.dart';
import '../api/services/students_api.dart';
import '../data/app_database.dart';

class SyncResult {
  const SyncResult({
    this.studentsPushed = 0,
    this.studentsPushFailed = 0,
    this.hifzPushed = 0,
    this.hifzPushFailed = 0,
    this.hifzPushSkipped = 0,
    this.pointsBatchesPushed = 0,
    this.pointsBatchesFailed = 0,
    this.pointsRowsSkipped = 0,
    this.studentsPulled = 0,
    this.studentsDeleted = 0,
    this.hifzPulled = 0,
    this.hifzDeleted = 0,
    this.skippedHifz = 0,
  });

  final int studentsPushed;
  final int studentsPushFailed;
  final int hifzPushed;
  final int hifzPushFailed;
  final int hifzPushSkipped; // hifz rows whose parent student isn't synced yet
  final int pointsBatchesPushed; // # of /batch/ calls that succeeded
  final int pointsBatchesFailed; // # of /batch/ calls that failed
  final int pointsRowsSkipped;   // local rows skipped (unmapped student/habit)
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
    required this.habitsApi,
    required this.studentPointsApi,
    AppDatabase? db,
  }) : _db = db ?? AppDatabase();

  static const _lastSyncKey = 'sync.last_at';

  final StudentsApi studentsApi;
  final HifzApi hifzApi;
  final HabitsApi habitsApi;
  final StudentPointsApi studentPointsApi;
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

  /// Used right after login. Pushes any pre-existing local rows that have no
  /// remote_id yet (initial upload), then pulls the full server state.
  Future<SyncResult> performLoginSync() async {
    final pushStudent = await _pushPendingStudents();
    final pushHifz = await _pushPendingHifz();
    // Habit name→id resolution must happen after students are pushed (so
    // students.remote_id is available) but before points push.
    final habitMap = await _loadHabitNameMap();
    final pushPoints = await _pushPendingPoints(habitMap);

    final db = await _db.database;
    final students = await studentsApi.getAll();
    final hifz = await hifzApi.getAll();
    final studentStats = await _mergeStudents(db, students);
    final hifzStats = await _mergeHifz(db, hifz);

    await _writeLastSyncAt(DateTime.now());
    return SyncResult(
      studentsPushed: pushStudent.pushed,
      studentsPushFailed: pushStudent.failed,
      hifzPushed: pushHifz.pushed,
      hifzPushFailed: pushHifz.failed,
      hifzPushSkipped: pushHifz.skipped,
      pointsBatchesPushed: pushPoints.batchesPushed,
      pointsBatchesFailed: pushPoints.batchesFailed,
      pointsRowsSkipped: pushPoints.rowsSkipped,
      studentsPulled: studentStats.pulled,
      studentsDeleted: studentStats.deleted,
      hifzPulled: hifzStats.pulled,
      hifzDeleted: hifzStats.deleted,
      skippedHifz: hifzStats.skipped,
    );
  }

  /// Push pending writes, then pull only rows changed since `lastSyncAt`.
  Future<SyncResult> performDeltaSync() async {
    final last = await readLastSyncAt();
    if (last == null) return performLoginSync();

    final pushStudent = await _pushPendingStudents();
    final pushHifz = await _pushPendingHifz();
    final habitMap = await _loadHabitNameMap();
    final pushPoints = await _pushPendingPoints(habitMap);

    final db = await _db.database;
    final students = await studentsApi.getAll(updatedSince: last);
    final hifz = await hifzApi.getAll(updatedSince: last);
    final studentStats = await _mergeStudents(db, students);
    final hifzStats = await _mergeHifz(db, hifz);

    await _writeLastSyncAt(DateTime.now());
    return SyncResult(
      studentsPushed: pushStudent.pushed,
      studentsPushFailed: pushStudent.failed,
      hifzPushed: pushHifz.pushed,
      hifzPushFailed: pushHifz.failed,
      hifzPushSkipped: pushHifz.skipped,
      pointsBatchesPushed: pushPoints.batchesPushed,
      pointsBatchesFailed: pushPoints.batchesFailed,
      pointsRowsSkipped: pushPoints.rowsSkipped,
      studentsPulled: studentStats.pulled,
      studentsDeleted: studentStats.deleted,
      hifzPulled: hifzStats.pulled,
      hifzDeleted: hifzStats.deleted,
      skippedHifz: hifzStats.skipped,
    );
  }

  // ────────────────────────── habit name resolution ──────────────────────────

  /// Fetches /api/habits/ and indexes by name. Empty map on failure (so a
  /// flaky habits endpoint doesn't break the rest of sync).
  Future<Map<String, int>> _loadHabitNameMap() async {
    try {
      final remote = await habitsApi.getAll();
      return {for (final h in remote) h.name.trim(): h.id};
    } on ApiException {
      return const <String, int>{};
    }
  }

  // ────────────────────────── push ──────────────────────────

  Future<_PushStats> _pushPendingStudents() async {
    final db = await _db.database;
    final rows = await db.query(
      'students',
      where: 'remote_id IS NULL',
    );
    int pushed = 0;
    int failed = 0;
    for (final row in rows) {
      try {
        final dto = _localStudentToDto(row);
        final created = await studentsApi.create(dto);
        await db.update(
          'students',
          {
            'remote_id': created.id,
            'server_updated_at': created.updatedAt,
            'sync_status': 'synced',
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );
        pushed++;
      } on ApiException {
        failed++;
        continue;
      }
    }
    return _PushStats(pushed: pushed, failed: failed);
  }

  Future<_PushStats> _pushPendingHifz() async {
    final db = await _db.database;

    // Build local_student_id → server_student_id once. Hifz rows with a parent
    // student that has no remote_id yet are skipped (they'll go up on the next
    // sync after the student is pushed).
    final studentRows = await db.query(
      'students',
      columns: ['id', 'remote_id'],
      where: 'remote_id IS NOT NULL',
    );
    final remoteByLocal = <int, int>{
      for (final r in studentRows) r['id'] as int: r['remote_id'] as int,
    };

    final rows = await db.query(
      'quran_memorization',
      where: 'remote_id IS NULL',
    );
    int pushed = 0;
    int failed = 0;
    int skipped = 0;
    for (final row in rows) {
      final localStudentId = row['student_id'] as int;
      final remoteStudentId = remoteByLocal[localStudentId];
      if (remoteStudentId == null) {
        skipped++;
        continue;
      }
      try {
        final created = await hifzApi.create(
          studentId: remoteStudentId,
          chapterIndex: row['surah_index'] as int,
          start: row['ayah_from'] as int,
          end: row['ayah_to'] as int,
          date: _toServerDate(row['memorized_on'] as String?,
              row['created_at'] as String?),
          label: row['label'] as String?,
          notes: row['notes'] as String?,
        );
        await db.update(
          'quran_memorization',
          {
            'remote_id': created.id,
            'server_updated_at': created.updatedAt,
            'sync_status': 'synced',
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );
        pushed++;
      } on ApiException {
        failed++;
        continue;
      }
    }
    return _PushStats(pushed: pushed, failed: failed, skipped: skipped);
  }

  /// Push the day's daily_entries via the batch endpoint. One HTTP call per
  /// distinct date with at least one pending row. Server replaces all rows for
  /// each (student, habit, date) tuple in the payload, so absolute counts work.
  Future<_PointsPushStats> _pushPendingPoints(Map<String, int> habitNameMap) async {
    final db = await _db.database;
    final pending = await db.query(
      'daily_entries',
      where: "sync_status IN ('pending_create', 'pending_update')",
    );
    if (pending.isEmpty) {
      return const _PointsPushStats(batchesPushed: 0, batchesFailed: 0, rowsSkipped: 0);
    }

    // local_student_id → server_student_id and local_habit_id → server_habit_id.
    final studentRows = await db.query(
      'students',
      columns: ['id', 'remote_id'],
      where: 'remote_id IS NOT NULL',
    );
    final remoteStudentByLocal = <int, int>{
      for (final r in studentRows) r['id'] as int: r['remote_id'] as int,
    };
    final habitRows = await db.query('habits', columns: ['id', 'name']);
    final remoteHabitByLocal = <int, int>{};
    for (final r in habitRows) {
      final remoteId = habitNameMap[(r['name'] as String).trim()];
      if (remoteId != null) remoteHabitByLocal[r['id'] as int] = remoteId;
    }

    // Group pending rows by date. Track local row ids per group so we can
    // mark them synced on success.
    final byDate = <String, List<Map<String, Object?>>>{};
    for (final row in pending) {
      final date = row['date'] as String;
      byDate.putIfAbsent(date, () => []).add(row);
    }

    int batchesPushed = 0;
    int batchesFailed = 0;
    int rowsSkipped = 0;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    for (final entry in byDate.entries) {
      final date = entry.key;
      final rows = entry.value;
      final entries = <BatchPointEntry>[];
      final pushableLocalIds = <int>[];
      for (final row in rows) {
        final remoteStudent = remoteStudentByLocal[row['student_id'] as int];
        final remoteHabit = remoteHabitByLocal[row['habit_id'] as int];
        if (remoteStudent == null || remoteHabit == null) {
          rowsSkipped++;
          continue;
        }
        final count = (row['count'] as int?) ?? 0;
        // Local stores a signed count: positive = "+" taps, negative = "−" taps.
        final plus = count > 0 ? count : 0;
        final minus = count < 0 ? -count : 0;
        entries.add(BatchPointEntry(
          studentId: remoteStudent,
          habitId: remoteHabit,
          plusCount: plus,
          minusCount: minus,
        ));
        pushableLocalIds.add(row['id'] as int);
      }
      if (entries.isEmpty) continue;
      try {
        await studentPointsApi.batchPush(date: date, entries: entries);
        await db.update(
          'daily_entries',
          {'sync_status': 'synced', 'server_updated_at': nowIso},
          where: 'id IN (${List.filled(pushableLocalIds.length, '?').join(',')})',
          whereArgs: pushableLocalIds,
        );
        batchesPushed++;
      } on ApiException {
        batchesFailed++;
        continue;
      }
    }
    return _PointsPushStats(
      batchesPushed: batchesPushed,
      batchesFailed: batchesFailed,
      rowsSkipped: rowsSkipped,
    );
  }

  StudentDto _localStudentToDto(Map<String, Object?> row) {
    final fullName = ((row['name'] as String?) ?? '').trim();
    final parts = fullName.split(RegExp(r'\s+'));
    final firstName = parts.isNotEmpty ? parts.first : '';
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    return StudentDto(
      id: 0, // ignored on POST
      firstName: firstName,
      lastName: lastName,
      fatherName: row['father_name'] as String?,
      motherName: row['mother_name'] as String?,
      dateOfBirth: row['date_of_birth'] as String?,
      phoneNumber: row['phone_number'] as String?,
      birthPlace: row['birth_place'] as String?,
      school: row['school_name'] as String?,
    );
  }

  /// Server `date` is a datetime. Local has only a date (YYYY-MM-DD).
  /// Stamp it at noon UTC so day-rounding is unambiguous either way.
  String _toServerDate(String? memorizedOn, String? createdAt) {
    final base = (memorizedOn != null && memorizedOn.isNotEmpty)
        ? memorizedOn
        : (createdAt != null && createdAt.length >= 10
            ? createdAt.substring(0, 10)
            : DateTime.now().toUtc().toIso8601String().substring(0, 10));
    return '${base}T12:00:00Z';
  }

  // ────────────────────────── merge (pull) ──────────────────────────

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

class _PushStats {
  const _PushStats({required this.pushed, required this.failed, this.skipped = 0});
  final int pushed;
  final int failed;
  final int skipped;
}

class _PointsPushStats {
  const _PointsPushStats({
    required this.batchesPushed,
    required this.batchesFailed,
    required this.rowsSkipped,
  });
  final int batchesPushed;
  final int batchesFailed;
  final int rowsSkipped;
}
