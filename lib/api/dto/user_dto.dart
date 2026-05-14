class UserDto {
  UserDto({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phoneNumber,
    this.mosqueName,
    this.study,
    this.dateOfBirth,
    this.certificates,
  });

  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phoneNumber;
  final String? mosqueName;
  final String? study;
  final String? dateOfBirth;
  final String? certificates;

  factory UserDto.fromJson(Map<String, dynamic> json) => UserDto(
        id: json['id'] as int? ?? 0,
        username: (json['username'] ?? '') as String,
        firstName: (json['first_name'] ?? '') as String,
        lastName: (json['last_name'] ?? '') as String,
        email: json['email'] as String?,
        phoneNumber: json['phone_number'] as String?,
        mosqueName: json['mosque_name'] as String?,
        study: json['study'] as String?,
        dateOfBirth: json['date_of_birth'] as String?,
        certificates: json['certificates'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        if (email != null) 'email': email,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        if (mosqueName != null) 'mosque_name': mosqueName,
        if (study != null) 'study': study,
        if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
        if (certificates != null) 'certificates': certificates,
      };

  String get displayName {
    final full = '$firstName $lastName'.trim();
    return full.isEmpty ? username : full;
  }

  UserDto copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phoneNumber,
    String? mosqueName,
    String? study,
    String? dateOfBirth,
    String? certificates,
  }) {
    return UserDto(
      id: id,
      username: username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      mosqueName: mosqueName ?? this.mosqueName,
      study: study ?? this.study,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      certificates: certificates ?? this.certificates,
    );
  }
}
