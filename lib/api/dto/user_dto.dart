class UserDto {
  UserDto({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phoneNumber,
    this.mosqueName,
  });

  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phoneNumber;
  final String? mosqueName;

  factory UserDto.fromJson(Map<String, dynamic> json) => UserDto(
        id: json['id'] as int,
        username: json['username'] as String,
        firstName: (json['first_name'] ?? '') as String,
        lastName: (json['last_name'] ?? '') as String,
        email: json['email'] as String?,
        phoneNumber: json['phone_number'] as String?,
        mosqueName: json['mosque_name'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        if (email != null) 'email': email,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        if (mosqueName != null) 'mosque_name': mosqueName,
      };

  String get displayName {
    final full = '$firstName $lastName'.trim();
    return full.isEmpty ? username : full;
  }
}
