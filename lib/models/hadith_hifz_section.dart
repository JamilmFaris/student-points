import 'dart:convert';

class HadithHifzSection {
    final int? id;
    final int studentId;
    final List<int> hadithNumbers;
    final String? notes;
    final String? label;
    final String date;
    final String createdAt;

    HadithHifzSection({
        this.id,
        required this.studentId,
        required this.hadithNumbers,
        this.notes,
        this.label,
        required this.date,
        required this.createdAt,
    });

    factory HadithHifzSection.fromMap(Map<String, dynamic> map) {
        List<int> numbers = [];
        final raw = map['hadith_numbers'];
        if (raw is String && raw.isNotEmpty) {
            try {
                final decoded = jsonDecode(raw);
                if (decoded is List) numbers = decoded.map((e) => e as int).toList();
            } catch (_) {}
        } else if (raw is List) {
            numbers = raw.map((e) => e as int).toList();
        }
        return HadithHifzSection(
            id: map['id'] as int?,
            studentId: map['student_id'] as int,
            hadithNumbers: numbers,
            notes: map['notes'] as String?,
            label: map['label'] as String?,
            date: map['date'] as String,
            createdAt: map['created_at'] as String,
        );
    }

    Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'hadith_numbers': jsonEncode(hadithNumbers),
        'notes': notes,
        'label': label,
        'date': date,
        'created_at': createdAt,
    };
}
