class Student {
	final int? id;
	final String name;

	Student({this.id, required this.name});

	Student copyWith({int? id, String? name}) {
		return Student(id: id ?? this.id, name: name ?? this.name);
	}

	factory Student.fromMap(Map<String, dynamic> map) {
		return Student(
			id: map['id'] as int?,
			name: map['name'] as String,
		);
	}

	Map<String, dynamic> toMap() {
		return {
			'id': id,
			'name': name,
		};
	}
}


