class Note {
	final int? id;
	final int studentId;
	final String title;
	final String noteText;
	final String createdAt; // ISO datetime
	final String updatedAt; // ISO datetime

	Note({
		this.id,
		required this.studentId,
		required this.title,
		this.noteText = '',
		required this.createdAt,
		required this.updatedAt,
	});

	Note copyWith({
		int? id,
		int? studentId,
		String? title,
		String? noteText,
		String? createdAt,
		String? updatedAt,
	}) {
		return Note(
			id: id ?? this.id,
			studentId: studentId ?? this.studentId,
			title: title ?? this.title,
			noteText: noteText ?? this.noteText,
			createdAt: createdAt ?? this.createdAt,
			updatedAt: updatedAt ?? this.updatedAt,
		);
	}

	factory Note.fromMap(Map<String, dynamic> map) {
		return Note(
			id: map['id'] as int?,
			studentId: map['student_id'] as int,
			title: map['title'] as String? ?? '',
			noteText: map['note_text'] as String? ?? '',
			createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
			updatedAt: map['updated_at'] as String? ?? DateTime.now().toIso8601String(),
		);
	}

	Map<String, dynamic> toMap() {
		return {
			'id': id,
			'student_id': studentId,
			'title': title,
			'note_text': noteText,
			'created_at': createdAt,
			'updated_at': updatedAt,
		};
	}
}
