class DailyEntry {
	final int? id;
	final DateTime date;
	final int studentId;
	final int habitId;
	final int count;

	DailyEntry({this.id, required this.date, required this.studentId, required this.habitId, required this.count});

	DailyEntry copyWith({int? id, DateTime? date, int? studentId, int? habitId, int? count}) {
		return DailyEntry(
			id: id ?? this.id,
			date: date ?? this.date,
			studentId: studentId ?? this.studentId,
			habitId: habitId ?? this.habitId,
			count: count ?? this.count,
		);
	}

	factory DailyEntry.fromMap(Map<String, dynamic> map) {
		return DailyEntry(
			id: map['id'] as int?,
			date: DateTime.parse(map['date'] as String),
			studentId: map['student_id'] as int,
			habitId: map['habit_id'] as int,
			count: map['count'] as int,
		);
	}

	Map<String, dynamic> toMap() {
		return {
			'id': id,
			'date': date.toIso8601String().substring(0, 10),
			'student_id': studentId,
			'habit_id': habitId,
			'count': count,
		};
	}
}


