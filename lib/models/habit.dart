class Habit {
	final int? id;
	final String name;
	final int points;
	final bool allowNegative;
	final bool oncePerDay;

	Habit({this.id, required this.name, required this.points, this.allowNegative = false, this.oncePerDay = false});

	Habit copyWith({int? id, String? name, int? points, bool? allowNegative, bool? oncePerDay}) {
		return Habit(
			id: id ?? this.id,
			name: name ?? this.name,
			points: points ?? this.points,
			allowNegative: allowNegative ?? this.allowNegative,
			oncePerDay: oncePerDay ?? this.oncePerDay,
		);
	}

	factory Habit.fromMap(Map<String, dynamic> map) {
		return Habit(
			id: map['id'] as int?,
			name: map['name'] as String,
			points: map['points'] as int,
			allowNegative: (map['allow_negative'] as int?) == null ? false : (map['allow_negative'] as int) != 0,
			oncePerDay: (map['once_per_day'] as int?) == null ? false : (map['once_per_day'] as int) != 0,
		);
	}

	Map<String, dynamic> toMap() {
		return {
			'id': id,
			'name': name,
			'points': points,
			'allow_negative': allowNegative ? 1 : 0,
			'once_per_day': oncePerDay ? 1 : 0,
		};
	}
}


