/// Hifz row from `GET /api/quran/hifz/`. Local model uses different naming:
///   server `chapter_index` → local `surah_index`
///   server `start`         → local `ayah_from`
///   server `end`           → local `ayah_to`
///   server `date`          → local `memorized_on` (date portion)
///   server `label`         → local `label` (kind: حفظ/مراجعة/تثبيت)
///   server `notes`         → local `notes`
class HifzDto {
  HifzDto({
    required this.id,
    required this.studentId,
    required this.chapterIndex,
    required this.start,
    required this.end,
    this.label,
    this.notes,
    this.date,
    this.updatedAt,
    this.isDeleted = false,
  });

  final int id;
  final int studentId; // server-side student id
  final int chapterIndex;
  final int start;
  final int end;
  final String? label;
  final String? notes;
  final String? date; // ISO datetime
  final String? updatedAt;
  final bool isDeleted;

  factory HifzDto.fromJson(Map<String, dynamic> json) => HifzDto(
        id: json['id'] as int,
        studentId: json['student_id'] as int,
        chapterIndex: json['chapter_index'] as int,
        start: json['start'] as int,
        end: json['end'] as int,
        label: json['label'] as String?,
        notes: json['notes'] as String?,
        date: json['date'] as String?,
        updatedAt: json['updated_at'] as String?,
        isDeleted: (json['is_deleted'] as bool?) ?? false,
      );

  /// Date portion (YYYY-MM-DD) of `date` for the local `memorized_on` column.
  String? get memorizedOnDate {
    if (date == null || date!.isEmpty) return null;
    final t = date!.indexOf('T');
    return t > 0 ? date!.substring(0, t) : date;
  }
}
