/// Server-side Lesson row. Local Lesson rows add a `date` column the server
/// doesn't store — server lessons are date-agnostic; the date lives on
/// Attendance. We map one local-date → one server Lesson.
class LessonDto {
  LessonDto({
    required this.id,
    required this.subject,
    this.updatedAt,
    this.isDeleted = false,
  });

  final int id;
  final String subject;
  final String? updatedAt;
  final bool isDeleted;

  factory LessonDto.fromJson(Map<String, dynamic> json) => LessonDto(
        id: json['id'] as int,
        subject: (json['subject'] ?? '') as String,
        updatedAt: json['updated_at'] as String?,
        isDeleted: (json['is_deleted'] as bool?) ?? false,
      );
}
