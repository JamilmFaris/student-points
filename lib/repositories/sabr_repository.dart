import '../data/app_database.dart';
import '../models/sabr_enums.dart';

class SabrRepository {
  SabrRepository();

  // ── writes (local DB, pending sync) ──────────────────────────────────────

  Future<void> createQuranSabr({
    required int localStudentId,
    required SabrMainType sabrType,
    required List<int> range,
  }) async {
    final db = await AppDatabase().database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('quran_sabr', {
      'student_id': localStudentId,
      'sabr_type': sabrType.label,
      'range_from': range[0],
      'range_to': range[1],
      'created_at': now,
      'sync_status': 'pending_create',
      'last_modified': now,
    });
  }

  Future<void> createHadithSabr({
    required int localStudentId,
    required HadithType hadithType,
  }) async {
    final db = await AppDatabase().database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('hadith_sabr', {
      'student_id': localStudentId,
      'hadith_type': hadithType.label,
      'created_at': now,
      'sync_status': 'pending_create',
      'last_modified': now,
    });
  }

  // ── reads (from local DB) ─────────────────────────────────────────────────

  /// Returns merged, sorted juz ranges for a student+type.
  Future<List<({int from, int to})>> getQuranSabrRanges({
    required int localStudentId,
    required SabrMainType sabrType,
  }) async {
    final db = await AppDatabase().database;
    final rows = await db.query(
      'quran_sabr',
      columns: ['range_from', 'range_to'],
      where: "student_id = ? AND sabr_type = ? AND sync_status != 'pending_delete'",
      whereArgs: [localStudentId, sabrType.label],
    );
    final raw = rows
        .map((r) => (from: r['range_from'] as int, to: r['range_to'] as int))
        .toList();
    return _mergeRanges(raw);
  }

  /// Returns the distinct hadith types recorded locally for a student.
  Future<List<String>> getHadithSabrTypes({
    required int localStudentId,
  }) async {
    final db = await AppDatabase().database;
    final rows = await db.rawQuery(
      "SELECT DISTINCT hadith_type FROM hadith_sabr "
      "WHERE student_id = ? AND sync_status != 'pending_delete'",
      [localStudentId],
    );
    return rows.map((r) => r['hadith_type'] as String).toList();
  }

  // ── validation ───────────────────────────────────────────────────────────

  /// Returns an error message if the addition is not allowed, or null if valid.
  Future<String?> validateQuranSabr({
    required int localStudentId,
    required SabrMainType sabrType,
    required List<int> range,
  }) async {
    final db = await AppDatabase().database;

    if (sabrType == SabrMainType.mahad) {
      final juz = range[0];
      final existing = await db.query(
        'quran_sabr',
        where: "student_id = ? AND sabr_type = ? AND range_from = ? AND sync_status != 'pending_delete'",
        whereArgs: [localStudentId, sabrType.label, juz],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        return 'الجزء $juz موجود مسبقاً في سبر المعهد لهذا الطالب.';
      }
    } else if (sabrType == SabrMainType.mahadTarakumi || sabrType == SabrMainType.awqaf) {
      final existingRanges = await getQuranSabrRanges(
        localStudentId: localStudentId,
        sabrType: sabrType,
      );
      if (existingRanges.isNotEmpty) {
        // Build set of all already-covered juzs (max 30 items, safe to enumerate)
        final covered = <int>{};
        for (final r in existingRanges) {
          for (int j = r.from; j <= r.to; j++) covered.add(j);
        }
        bool hasNewContent = false;
        for (int j = range[0]; j <= range[1]; j++) {
          if (!covered.contains(j)) {
            hasNewContent = true;
            break;
          }
        }
        if (!hasNewContent) {
          final existingStr = existingRanges
              .map((r) => r.from == r.to ? '${r.from}' : '${r.from}–${r.to}')
              .join(' ، ');
          return 'النطاق الجديد (${range[0]}–${range[1]}) مغطى بالكامل ضمن الأجزاء المُسبَرة مسبقاً: $existingStr.\n\nيجب أن يحتوي النطاق الجديد على جزء جديد غير موجود.';
        }
      }
    }
    return null;
  }

  Future<String?> validateHadithSabr({
    required int localStudentId,
    required HadithType hadithType,
  }) async {
    final db = await AppDatabase().database;
    final existing = await db.query(
      'hadith_sabr',
      where: "student_id = ? AND hadith_type = ? AND sync_status != 'pending_delete'",
      whereArgs: [localStudentId, hadithType.label],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return '"${hadithType.label}" تم إضافته مسبقاً لهذا الطالب.';
    }
    return null;
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  List<({int from, int to})> _mergeRanges(List<({int from, int to})> ranges) {
    if (ranges.isEmpty) return [];
    final sorted = List.of(ranges)..sort((a, b) => a.from.compareTo(b.from));
    final merged = <({int from, int to})>[sorted.first];
    for (final cur in sorted.skip(1)) {
      final last = merged.last;
      if (cur.from <= last.to + 1) {
        merged[merged.length - 1] =
            (from: last.from, to: cur.to > last.to ? cur.to : last.to);
      } else {
        merged.add(cur);
      }
    }
    return merged;
  }
}
