class Student {
    final int? id;
    final String name;
    final int sortOrder;
    final String? dateOfBirth; // ISO yyyy-MM-dd
    final String? schoolName;
    final String? fatherName;
    final String? motherName;
    final String? phoneNumber;
    final String? birthPlace;
    final String? grade; // e.g., الصف الأول

    Student({this.id, required this.name, this.sortOrder = 0, this.dateOfBirth, this.schoolName, this.fatherName, this.motherName, this.phoneNumber, this.birthPlace, this.grade});

    Student copyWith({int? id, String? name, int? sortOrder, String? dateOfBirth, String? schoolName, String? fatherName, String? motherName, String? phoneNumber, String? birthPlace, String? grade}) {
        return Student(
            id: id ?? this.id,
            name: name ?? this.name,
            sortOrder: sortOrder ?? this.sortOrder,
            dateOfBirth: dateOfBirth ?? this.dateOfBirth,
            schoolName: schoolName ?? this.schoolName,
            fatherName: fatherName ?? this.fatherName,
            motherName: motherName ?? this.motherName,
            phoneNumber: phoneNumber ?? this.phoneNumber,
            birthPlace: birthPlace ?? this.birthPlace,
            grade: grade ?? this.grade,
        );
    }

    factory Student.fromMap(Map<String, dynamic> map) {
        return Student(
            id: map['id'] as int?,
            name: map['name'] as String,
            sortOrder: (map['sort_order'] as int?) ?? 0,
            dateOfBirth: map['date_of_birth'] as String?,
            schoolName: map['school_name'] as String?,
            fatherName: map['father_name'] as String?,
            motherName: map['mother_name'] as String?,
            phoneNumber: map['phone_number'] as String?,
            birthPlace: map['birth_place'] as String?,
            grade: map['grade'] as String?,
        );
    }

    Map<String, dynamic> toMap() {
        return {
            'id': id,
            'name': name,
            'sort_order': sortOrder,
            'date_of_birth': dateOfBirth,
            'school_name': schoolName,
            'father_name': fatherName,
            'mother_name': motherName,
            'phone_number': phoneNumber,
            'birth_place': birthPlace,
            'grade': grade,
        };
    }
}


