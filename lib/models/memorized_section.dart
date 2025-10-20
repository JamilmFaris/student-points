class MemorizedSection {
    final int? id;
    final int studentId;
    /// Surah index 1..114
    final int surahIndex;
    /// Starting ayah number (1-based)
    final int ayahFrom;
    /// Ending ayah number (inclusive, 1-based)
    final int ayahTo;
    final String createdAt; // ISO datetime
    final String? memorizedOn; // ISO yyyy-MM-dd
    /// Kind label: حفظ / مراجعة / تثبيت
    final String? label;

    MemorizedSection({this.id, required this.studentId, required this.surahIndex, required this.ayahFrom, required this.ayahTo, required this.createdAt, this.memorizedOn, this.label});

    factory MemorizedSection.fromMap(Map<String, dynamic> map) {
        return MemorizedSection(
            id: map['id'] as int?,
            studentId: map['student_id'] as int,
            surahIndex: map['surah_index'] as int,
            ayahFrom: map['ayah_from'] as int,
            ayahTo: map['ayah_to'] as int,
            createdAt: map['created_at'] as String,
            memorizedOn: map['memorized_on'] as String?,
            label: map['label'] as String?,
        );
    }

    Map<String, dynamic> toMap() {
        return {
            'id': id,
            'student_id': studentId,
            'surah_index': surahIndex,
            'ayah_from': ayahFrom,
            'ayah_to': ayahTo,
            'created_at': createdAt,
            'memorized_on': memorizedOn,
            'label': label,
        };
    }
}


