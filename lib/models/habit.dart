class Habit {
	final int? id;
	final String name;
	final int points;

	Habit({this.id, required this.name, required this.points});

	Habit copyWith({int? id, String? name, int? points}) {
		return Habit(id: id ?? this.id, name: name ?? this.name, points: points ?? this.points);
	}

	factory Habit.fromMap(Map<String, dynamic> map) {
		return Habit(
			id: map['id'] as int?,
			name: map['name'] as String,
			points: map['points'] as int,
		);
	}

	Map<String, dynamic> toMap() {
		return {
			'id': id,
			'name': name,
			'points': points,
		};
	}
}


