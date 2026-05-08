/// Student row from `GET /api/students/`. Per backend_changes.md the response now
/// includes `updated_at` (always) and `is_deleted` (only when `?updated_since=` was sent).
class StudentDto {
  StudentDto({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.fatherName,
    this.motherName,
    this.dateOfBirth,
    this.phoneNumber,
    this.parentPhoneNumber,
    this.birthPlace,
    this.school,
    this.updatedAt,
    this.isDeleted = false,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String? fatherName;
  final String? motherName;
  final String? dateOfBirth;
  final String? phoneNumber;
  final String? parentPhoneNumber;
  final String? birthPlace;
  final String? school;
  final String? updatedAt;
  final bool isDeleted;

  factory StudentDto.fromJson(Map<String, dynamic> json) => StudentDto(
        id: json['id'] as int,
        firstName: (json['first_name'] ?? '') as String,
        lastName: (json['last_name'] ?? '') as String,
        fatherName: json['father_name'] as String?,
        motherName: json['mother_name'] as String?,
        dateOfBirth: json['date_of_birth'] as String?,
        phoneNumber: json['phone_number'] as String?,
        parentPhoneNumber: json['parent_phone_number'] as String?,
        birthPlace: json['birth_place'] as String?,
        school: json['school'] as String?,
        updatedAt: json['updated_at'] as String?,
        isDeleted: (json['is_deleted'] as bool?) ?? false,
      );

  String get joinedName => '$firstName $lastName'.trim();
}
