import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../api/dto/hifz_dto.dart';
import '../api/dto/student_dto.dart';
import '../api/services/_dio_error.dart';
import '../api/services/attendance_api.dart';
import '../api/services/habits_api.dart';
import '../api/services/hifz_api.dart';
import '../api/services/lessons_api.dart';
import '../api/services/student_points_api.dart';
import '../api/services/students_api.dart';
import '../data/app_database.dart';
import 'app_mode.dart';

class SyncResult {
  const SyncResult({
    this.studentsPushed = 0,
    this.studentsPushFailed = 0,
    this.studentsUpdated = 0,
    this.studentsUpdateFailed = 0,
    this.studentsServerDeleted = 0,
    this.studentsDeleteFailed = 0,
    this.habitsPushed = 0,
    this.habitsPushFailed = 0,
    this.habitsUpdated = 0,
    this.habitsUpdateFailed = 0,
    this.habitsServerDeleted = 0,
    this.habitsDeleteFailed = 0,
    this.hifzPushed = 0,
    this.hifzPushFailed = 0,
    this.hifzPushSkipped = 0,
    this.hifzUpdated = 0,
    this.hifzUpdateFailed = 0,
    this.hifzServerDeleted = 0,
    this.hifzDeleteFailed = 0,
    this.lessonsPushed = 0,
    this.lessonsPushFailed = 0,
    this.lessonsUpdated = 0,
    this.lessonsUpdateFailed = 0,
    this.lessonsServerDeleted = 0,
    this.lessonsDeleteFailed = 0,
    this.attendancePushed = 0,
    this.attendancePushFailed = 0,
    this.pointsBatchesPushed = 0,
    this.pointsBatchesFailed = 0,
    this.pointsRowsSkipped = 0,
    this.studentsPulled = 0,
    this.studentsDeleted = 0,
    this.hifzPulled = 0,
    this.hifzDeleted = 0,
    this.skippedHifz = 0,
    this.failedHifzDetails = const {},
  });

  // Push: create.
  final int studentsPushed;
  final int studentsPushFailed;
  final int habitsPushed;
  final int habitsPushFailed;
  final int hifzPushed;
  final int hifzPushFailed;
  final int hifzPushSkipped;        // parent student not synced yet
  // Push: update.
  final int studentsUpdated;
  final int studentsUpdateFailed;
  final int habitsUpdated;
  final int habitsUpdateFailed;
  final int hifzUpdated;
  final int hifzUpdateFailed;
  // Push: delete (server-side success).
  final int studentsServerDeleted;
  final int studentsDeleteFailed;
  final int habitsServerDeleted;
  final int habitsDeleteFailed;
  final int hifzServerDeleted;
  final int hifzDeleteFailed;
  // Push: lessons.
  final int lessonsPushed;
  final int lessonsPushFailed;
  final int lessonsUpdated;
  final int lessonsUpdateFailed;
  final int lessonsServerDeleted;
  final int lessonsDeleteFailed;
  // Push: attendance (one bulk POST per (lesson, date)).
  final int attendancePushed;
  final int attendancePushFailed;
  // Push: points.
  final int pointsBatchesPushed;
  final int pointsBatchesFailed;
  final int pointsRowsSkipped;      // unmapped student/habit
  // Pull.
  final int studentsPulled;
  final int studentsDeleted;        // server-tombstoned rows pruned locally
  final int hifzPulled;
  final int hifzDeleted;
  final int skippedHifz;
  // Error details.
  final Map<int, String> failedHifzDetails;  // local id -> error message
}

class SyncService {
  SyncService({
    required this.studentsApi,
    required this.hifzApi,
    required this.habitsApi,
    required this.studentPointsApi,
    required this.lessonsApi,
    required this.attendanceApi,
    AppDatabase? db,
  }) : _db = db ?? AppDatabase();

  static const _lastSyncKey = 'sync.last_at';

  final StudentsApi studentsApi;
  final HifzApi hifzApi;
  final HabitsApi habitsApi;
  final StudentPointsApi studentPointsApi;
  final LessonsApi lessonsApi;
  final AttendanceApi attendanceApi;
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
  Future<SyncResult> performLoginSync() async => _runSync(fullPull: true);

  /// Push pending writes, then pull only rows changed since `lastSyncAt`.
  Future<SyncResult> performDeltaSync() async {
    final last = await readLastSyncAt();
    if (last == null) return performLoginSync();
    return _runSync(fullPull: false, since: last);
  }

  Future<SyncResult> _runSync({required bool fullPull, DateTime? since}) async {
    // Push order matters:
    //  - creates first (so updates/points can resolve remote_ids).
    //  - updates next.
    //  - deletes next (after dependent rows have caught up).
    //  - lessons before points so attendance push has lesson.remote_id.
    //  - points last; attendance push piggybacks per successful date.
    final createStudents = await _pushPendingStudents();
    final updateStudents = await _pushUpdatedStudents();
    final deleteStudents = await _pushDeletedStudents();
    final createHabits = await _pushPendingHabits();
    final updateHabits = await _pushUpdatedHabits();
    final deleteHabits = await _pushDeletedHabits();
    final createHifz = await _pushPendingHifz();
    final updateHifz = await _pushUpdatedHifz();
    final deleteHifz = await _pushDeletedHifz();
    final createLessons = await _pushPendingLessons();
    final updateLessons = await _pushUpdatedLessons();
    final deleteLessons = await _pushDeletedLessons();
    final habitMap = await _loadHabitNameMap();
    final attendanceHabitId = await _resolveAttendanceHabitLocalId();
    final pushPoints = await _pushPendingPoints(
      habitMap,
      attendanceHabitLocalId: attendanceHabitId,
    );

    final db = await _db.database;
    final students = fullPull
        ? await studentsApi.getAll()
        : await studentsApi.getAll(updatedSince: since);
    final hifz = fullPull
        ? await hifzApi.getAll()
        : await hifzApi.getAll(updatedSince: since);
    final studentStats = await _mergeStudents(db, students);
    final hifzStats = await _mergeHifz(db, hifz);

    await _writeLastSyncAt(DateTime.now());
    return SyncResult(
      studentsPushed: createStudents.pushed,
      studentsPushFailed: createStudents.failed,
      studentsUpdated: updateStudents.pushed,
      studentsUpdateFailed: updateStudents.failed,
      studentsServerDeleted: deleteStudents.pushed,
      studentsDeleteFailed: deleteStudents.failed,
      habitsPushed: createHabits.pushed,
      habitsPushFailed: createHabits.failed,
      habitsUpdated: updateHabits.pushed,
      habitsUpdateFailed: updateHabits.failed,
      habitsServerDeleted: deleteHabits.pushed,
      habitsDeleteFailed: deleteHabits.failed,
      hifzPushed: createHifz.pushed,
      hifzPushFailed: createHifz.failed,
      hifzPushSkipped: createHifz.skipped,
      hifzUpdated: updateHifz.pushed,
      hifzUpdateFailed: updateHifz.failed,
      hifzServerDeleted: deleteHifz.pushed,
      hifzDeleteFailed: deleteHifz.failed,
      lessonsPushed: createLessons.pushed,
      lessonsPushFailed: createLessons.failed,
      lessonsUpdated: updateLessons.pushed,
      lessonsUpdateFailed: updateLessons.failed,
      lessonsServerDeleted: deleteLessons.pushed,
      lessonsDeleteFailed: deleteLessons.failed,
      attendancePushed: pushPoints.attendancePushed,
      attendancePushFailed: pushPoints.attendanceFailed,
      pointsBatchesPushed: pushPoints.batchesPushed,
      pointsBatchesFailed: pushPoints.batchesFailed,
      pointsRowsSkipped: pushPoints.rowsSkipped,
      studentsPulled: studentStats.pulled,
      studentsDeleted: studentStats.deleted,
      hifzPulled: hifzStats.pulled,
      hifzDeleted: hifzStats.deleted,
      skippedHifz: hifzStats.skipped,
      failedHifzDetails: createHifz.failureDetails,
    );
  }

  // ────────────────────── attendance habit resolution ──────────────────────

  Future<int?> _resolveAttendanceHabitLocalId() async {
    final db = await _db.database;
    final byName = await db.query(
      'habits',
      columns: ['id'],
      where: 'name = ?',
      whereArgs: [AppMode.defaultAttendanceHabitName],
      limit: 1,
    );
    if (byName.isNotEmpty) return byName.first['id'] as int;
    final overrideId = await AppMode.getAttendanceHabitOverride();
    if (overrideId == null) return null;
    final row = await db.query('habits',
        columns: ['id'], where: 'id = ?', whereArgs: [overrideId], limit: 1);
    return row.isEmpty ? null : row.first['id'] as int;
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
            'father_name': created.fatherName,
            'mother_name': created.motherName,
            'date_of_birth': created.dateOfBirth,
            'school_name': created.school,
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
    final failureDetails = <int, String>{};
    for (final row in rows) {
      final localStudentId = row['student_id'] as int;
      final remoteStudentId = remoteByLocal[localStudentId];
      if (remoteStudentId == null) {
        skipped++;
        continue;
      }
      try {
        final surahIndex = row['surah_index'] as int;
        final ayahFrom = row['ayah_from'] as int;
        final ayahTo = row['ayah_to'] as int;
        final date = _toServerDate(row['memorized_on'] as String?,
            row['created_at'] as String?);
        final label = row['label'] as String?;
        final notes = row['notes'] as String?;

        final created = await hifzApi.create(
          studentId: remoteStudentId,
          chapterIndex: surahIndex,
          start: ayahFrom,
          end: ayahTo,
          date: date,
          label: label,
          notes: notes,
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
      } on ApiException catch (e) {
        final hifzLocalId = row['id'] as int;
        final surahIndex = row['surah_index'] as int;
        final ayahFrom = row['ayah_from'] as int;
        final ayahTo = row['ayah_to'] as int;
        failureDetails[hifzLocalId] = 'Student ID: $remoteStudentId, Surah: $surahIndex, Ayah: $ayahFrom-$ayahTo | Error: ${e.message}';
        failed++;
        continue;
      }
    }
    return _PushStats(pushed: pushed, failed: failed, skipped: skipped, failureDetails: failureDetails);
  }

  Future<_PushStats> _pushUpdatedStudents() async {
    final db = await _db.database;
    final rows = await db.query(
      'students',
      where: "sync_status = 'pending_update' AND remote_id IS NOT NULL",
    );
    int pushed = 0;
    int failed = 0;
    for (final row in rows) {
      try {
        final dto = _localStudentToDto(row);
        final updated = await studentsApi.update(row['remote_id'] as int, dto);
        await db.update(
          'students',
          {
            'sync_status': 'synced',
            'server_updated_at': updated.updatedAt,
            'father_name': updated.fatherName,
            'mother_name': updated.motherName,
            'date_of_birth': updated.dateOfBirth,
            'school_name': updated.school,
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

  Future<_PushStats> _pushDeletedStudents() async {
    final db = await _db.database;
    final rows = await db.query(
      'students',
      columns: ['id', 'remote_id'],
      where: "sync_status = 'pending_delete'",
    );
    int pushed = 0;
    int failed = 0;
    for (final row in rows) {
      final remoteId = row['remote_id'] as int?;
      if (remoteId == null) {
        // Inconsistent state — tombstoned but never on the server. Hard-remove.
        await db.delete('students', where: 'id = ?', whereArgs: [row['id']]);
        continue;
      }
      try {
        await studentsApi.delete(remoteId);
        await db.delete('students', where: 'id = ?', whereArgs: [row['id']]);
        pushed++;
      } on ApiException {
        failed++;
        continue;
      }
    }
    return _PushStats(pushed: pushed, failed: failed);
  }

  Future<_PushStats> _pushPendingHabits() async {
    final db = await _db.database;
    final rows = await db.query(
      'habits',
      where: 'remote_id IS NULL',
    );
    int pushed = 0;
    int failed = 0;
    for (final row in rows) {
      try {
        final created = await habitsApi.create(
          row['name'] as String,
          row['points'] as int,
          row['decrease_points'] as int,
        );
        await db.update(
          'habits',
          {
            'remote_id': created.id,
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

  Future<_PushStats> _pushUpdatedHabits() async {
    final db = await _db.database;
    final rows = await db.query(
      'habits',
      where: "sync_status = 'pending_update' AND remote_id IS NOT NULL",
    );
    int pushed = 0;
    int failed = 0;
    for (final row in rows) {
      try {
        await habitsApi.update(
          row['remote_id'] as int,
          row['name'] as String,
          row['points'] as int,
          row['decrease_points'] as int,
        );
        await db.update(
          'habits',
          {'sync_status': 'synced'},
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

  Future<_PushStats> _pushDeletedHabits() async {
    final db = await _db.database;
    final rows = await db.query(
      'habits',
      columns: ['id', 'remote_id'],
      where: "sync_status = 'pending_delete'",
    );
    int pushed = 0;
    int failed = 0;
    for (final row in rows) {
      final remoteId = row['remote_id'] as int?;
      if (remoteId == null) {
        await db.delete('habits', where: 'id = ?', whereArgs: [row['id']]);
        continue;
      }
      try {
        await habitsApi.delete(remoteId);
        await db.delete('habits', where: 'id = ?', whereArgs: [row['id']]);
        pushed++;
      } on ApiException {
        failed++;
        continue;
      }
    }
    return _PushStats(pushed: pushed, failed: failed);
  }

  Future<_PushStats> _pushUpdatedHifz() async {
    final db = await _db.database;
    final rows = await db.query(
      'quran_memorization',
      where: "sync_status = 'pending_update' AND remote_id IS NOT NULL",
    );
    int pushed = 0;
    int failed = 0;
    for (final row in rows) {
      try {
        final updated = await hifzApi.update(
          remoteId: row['remote_id'] as int,
          chapterIndex: row['surah_index'] as int,
          start: row['ayah_from'] as int,
          end: row['ayah_to'] as int,
          date: _toServerDate(
              row['memorized_on'] as String?, row['created_at'] as String?),
          label: row['label'] as String?,
          notes: row['notes'] as String?,
        );
        await db.update(
          'quran_memorization',
          {
            'sync_status': 'synced',
            'server_updated_at': updated.updatedAt,
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

  Future<_PushStats> _pushDeletedHifz() async {
    final db = await _db.database;
    final rows = await db.query(
      'quran_memorization',
      columns: ['id', 'remote_id'],
      where: "sync_status = 'pending_delete'",
    );
    int pushed = 0;
    int failed = 0;
    for (final row in rows) {
      final remoteId = row['remote_id'] as int?;
      if (remoteId == null) {
        await db.delete('quran_memorization',
            where: 'id = ?', whereArgs: [row['id']]);
        continue;
      }
      try {
        await hifzApi.delete(remoteId);
        await db.delete('quran_memorization',
            where: 'id = ?', whereArgs: [row['id']]);
        pushed++;
      } on ApiException {
        failed++;
        continue;
      }
    }
    return _PushStats(pushed: pushed, failed: failed);
  }

  // ────────────────────────── lessons push ──────────────────────────

  /// Server requires a non-empty `subject`; substitute a date-based fallback
  /// when the local row's subject is empty.
  String _effectiveLessonSubject(String? subject, String date) {
    final s = (subject ?? '').trim();
    return s.isEmpty ? 'درس $date' : s;
  }

  Future<_PushStats> _pushPendingLessons() async {
    final db = await _db.database;
    final rows = await db.query(
      'lessons',
      where: "sync_status = 'pending_create' AND remote_id IS NULL",
    );
    int pushed = 0;
    int failed = 0;
    for (final row in rows) {
      try {
        final created = await lessonsApi.create(
          subject: _effectiveLessonSubject(
              row['subject'] as String?, row['date'] as String),
        );
        await db.update(
          'lessons',
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

  Future<_PushStats> _pushUpdatedLessons() async {
    final db = await _db.database;
    final rows = await db.query(
      'lessons',
      where: "sync_status = 'pending_update' AND remote_id IS NOT NULL",
    );
    int pushed = 0;
    int failed = 0;
    for (final row in rows) {
      try {
        final updated = await lessonsApi.update(
          remoteId: row['remote_id'] as int,
          subject: _effectiveLessonSubject(
              row['subject'] as String?, row['date'] as String),
        );
        await db.update(
          'lessons',
          {
            'sync_status': 'synced',
            'server_updated_at': updated.updatedAt,
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

  Future<_PushStats> _pushDeletedLessons() async {
    final db = await _db.database;
    final rows = await db.query(
      'lessons',
      columns: ['id', 'remote_id'],
      where: "sync_status = 'pending_delete'",
    );
    int pushed = 0;
    int failed = 0;
    for (final row in rows) {
      final remoteId = row['remote_id'] as int?;
      if (remoteId == null) {
        await db.delete('lessons', where: 'id = ?', whereArgs: [row['id']]);
        continue;
      }
      try {
        await lessonsApi.delete(remoteId);
        await db.delete('lessons', where: 'id = ?', whereArgs: [row['id']]);
        pushed++;
      } on ApiException {
        failed++;
        continue;
      }
    }
    return _PushStats(pushed: pushed, failed: failed);
  }

  /// Push the day's daily_entries via the batch endpoint. One HTTP call per
  /// distinct date with at least one pending row. Server replaces all rows for
  /// each (student, habit, date) tuple in the payload, so absolute counts work.
  /// After a successful batch push for a date, also push the attendance roster
  /// for that date (derived from positive counts on the attendance habit).
  Future<_PointsPushStats> _pushPendingPoints(
    Map<String, int> habitNameMap, {
    int? attendanceHabitLocalId,
  }) async {
    final db = await _db.database;
    final pending = await db.query(
      'daily_entries',
      where: "sync_status IN ('pending_create', 'pending_update')",
    );
    if (pending.isEmpty) {
      return const _PointsPushStats(
          batchesPushed: 0, batchesFailed: 0, rowsSkipped: 0);
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
    int attendancePushed = 0;
    int attendanceFailed = 0;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    // Cache of date → lesson row for attendance push. Refreshed lazily.
    Future<Map<String, Object?>?> lessonForDate(String date) async {
      final rows = await db.query('lessons',
          where: 'date = ?', whereArgs: [date], limit: 1);
      return rows.isEmpty ? null : rows.first;
    }

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

      // Attendance push for this date: every student with count > 0 on the
      // attendance habit is marked attended; the others (in the lesson's
      // roster on that date) are marked absent by the server.
      if (attendanceHabitLocalId == null) continue;
      final lesson = await lessonForDate(date);
      final lessonRemoteId = lesson?['remote_id'] as int?;
      if (lessonRemoteId == null) continue;
      final attendedRows = await db.rawQuery(
        '''
        SELECT student_id FROM daily_entries
        WHERE date = ? AND habit_id = ? AND count > 0
        ''',
        [date, attendanceHabitLocalId],
      );
      final attendedRemoteIds = <int>[];
      for (final r in attendedRows) {
        final remote = remoteStudentByLocal[r['student_id'] as int];
        if (remote != null) attendedRemoteIds.add(remote);
      }
      try {
        await attendanceApi.bulkMark(
          lessonRemoteId: lessonRemoteId,
          date: date,
          studentIds: attendedRemoteIds,
        );
        await db.update(
          'lessons',
          {'attendance_pushed_at': nowIso},
          where: 'id = ?',
          whereArgs: [lesson!['id']],
        );
        attendancePushed++;
      } on ApiException {
        attendanceFailed++;
        continue;
      }
    }
    return _PointsPushStats(
      batchesPushed: batchesPushed,
      batchesFailed: batchesFailed,
      rowsSkipped: rowsSkipped,
      attendancePushed: attendancePushed,
      attendanceFailed: attendanceFailed,
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
      fatherName: (row['father_name'] as String?) ?? 'والد',
      motherName: (row['mother_name'] as String?) ?? 'والدة',
      dateOfBirth: (row['date_of_birth'] as String?) ?? '2010-01-01',
      phoneNumber: row['phone_number'] as String?,
      birthPlace: row['birth_place'] as String?,
      school: (row['school_name'] as String?) ?? 'مدرسة',
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
  const _PushStats({
    required this.pushed,
    required this.failed,
    this.skipped = 0,
    this.failureDetails = const {},
  });
  final int pushed;
  final int failed;
  final int skipped;
  final Map<int, String> failureDetails;
}

class _PointsPushStats {
  const _PointsPushStats({
    required this.batchesPushed,
    required this.batchesFailed,
    required this.rowsSkipped,
    this.attendancePushed = 0,
    this.attendanceFailed = 0,
  });
  final int batchesPushed;
  final int batchesFailed;
  final int rowsSkipped;
  final int attendancePushed;
  final int attendanceFailed;
}
