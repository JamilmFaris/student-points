class HadithHifzDto {
    final int id;
    final int studentId;
    final List<int> hadithNumbers;
    final String? notes;
    final String? label;
    final String? date;
    final String? updatedAt;
    final bool isDeleted;

    HadithHifzDto({
        required this.id,
        required this.studentId,
        required this.hadithNumbers,
        this.notes,
        this.label,
        this.date,
        this.updatedAt,
        this.isDeleted = false,
    });

    factory HadithHifzDto.fromJson(Map<String, dynamic> json) => HadithHifzDto(
        id: json['id'] as int,
        studentId: json['student_id'] as int,
        hadithNumbers: (json['hadith_numbers'] as List? ?? []).map((e) => e as int).toList(),
        notes: json['notes'] as String?,
        label: json['label'] as String?,
        date: json['date'] as String?,
        updatedAt: json['updated_at'] as String?,
        isDeleted: (json['is_deleted'] as bool?) ?? false,
    );

    String? get datePortion {
        if (date == null || date!.isEmpty) return null;
        final t = date!.indexOf('T');
        return t > 0 ? date!.substring(0, t) : date;
    }
}
