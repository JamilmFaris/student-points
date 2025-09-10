class Habit {
	final int? id;
	final String name;
	final int points;
	final bool allowNegative;

	Habit({this.id, required this.name, required this.points, this.allowNegative = false});

	Habit copyWith({int? id, String? name, int? points, bool? allowNegative}) {
		return Habit(
			id: id ?? this.id,
			name: name ?? this.name,
			points: points ?? this.points,
			allowNegative: allowNegative ?? this.allowNegative,
		);
	}

	factory Habit.fromMap(Map<String, dynamic> map) {
		return Habit(
			id: map['id'] as int?,
			name: map['name'] as String,
			points: map['points'] as int,
			allowNegative: (map['allow_negative'] as int?) == null ? false : (map['allow_negative'] as int) != 0,
		);
	}

	Map<String, dynamic> toMap() {
		return {
			'id': id,
			'name': name,
			'points': points,
			'allow_negative': allowNegative ? 1 : 0,
		};
	}
}


