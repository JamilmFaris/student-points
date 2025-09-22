class Habit {
	final int? id;
	final String name;
	final int points;
	final int decreasePoints;
	final bool allowNegative;
	final bool oncePerDay;
	final int sortOrder;

	Habit({this.id, required this.name, required this.points, int? decreasePoints, this.allowNegative = false, this.oncePerDay = false, this.sortOrder = 0})
		: decreasePoints = decreasePoints ?? points;

	Habit copyWith({int? id, String? name, int? points, int? decreasePoints, bool? allowNegative, bool? oncePerDay, int? sortOrder}) {
		return Habit(
			id: id ?? this.id,
			name: name ?? this.name,
			points: points ?? this.points,
			decreasePoints: decreasePoints ?? this.decreasePoints,
			allowNegative: allowNegative ?? this.allowNegative,
			oncePerDay: oncePerDay ?? this.oncePerDay,
			sortOrder: sortOrder ?? this.sortOrder,
		);
	}

	factory Habit.fromMap(Map<String, dynamic> map) {
		final p = map['points'] as int;
		final dpAny = map['decrease_points'];
		final dp = dpAny == null ? p : (dpAny as int);
		return Habit(
			id: map['id'] as int?,
			name: map['name'] as String,
			points: p,
			decreasePoints: dp,
			allowNegative: (map['allow_negative'] as int?) == null ? false : (map['allow_negative'] as int) != 0,
			oncePerDay: (map['once_per_day'] as int?) == null ? false : (map['once_per_day'] as int) != 0,
			sortOrder: (map['sort_order'] as int?) ?? 0,
		);
	}

	Map<String, dynamic> toMap() {
		return {
			'id': id,
			'name': name,
			'points': points,
			'decrease_points': decreasePoints,
			'allow_negative': allowNegative ? 1 : 0,
			'once_per_day': oncePerDay ? 1 : 0,
			'sort_order': sortOrder,
		};
	}
}


