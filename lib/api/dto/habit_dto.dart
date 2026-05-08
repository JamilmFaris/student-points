/// Read-only mirror of `GET /api/habits/`. Used purely to resolve
/// local habit names to server `habit_id` for the points batch push.
/// Habits are not pushed from the client (per user decision); the server
/// is the source of truth for the habit catalogue.
class HabitDto {
  HabitDto({required this.id, required this.name});

  final int id;
  final String name;

  factory HabitDto.fromJson(Map<String, dynamic> json) => HabitDto(
        id: json['id'] as int,
        name: (json['name'] ?? '') as String,
      );
}
