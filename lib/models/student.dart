class Student {
	final int? id;
	final String name;
	final int sortOrder;

	Student({this.id, required this.name, this.sortOrder = 0});

	Student copyWith({int? id, String? name, int? sortOrder}) {
		return Student(id: id ?? this.id, name: name ?? this.name, sortOrder: sortOrder ?? this.sortOrder);
	}

	factory Student.fromMap(Map<String, dynamic> map) {
		return Student(
			id: map['id'] as int?,
			name: map['name'] as String,
			sortOrder: (map['sort_order'] as int?) ?? 0,
		);
	}

	Map<String, dynamic> toMap() {
		return {
			'id': id,
			'name': name,
			'sort_order': sortOrder,
		};
	}
}


