/// Read-only mirror of `GET /api/habits/`. Used to pull habits from server.
/// Habits are not pushed from the client (per user decision); the server
/// is the source of truth for the habit catalogue.
class HabitDto {
  HabitDto({
    required this.id,
    required this.name,
    this.points = 1,
    this.minusPoints = 1,
    this.allowNegative = true,
    this.oncePerDay = false,
  });

  final int id;
  final String name;
  final int points;
  final int minusPoints;
  final bool allowNegative;
  final bool oncePerDay;

  factory HabitDto.fromJson(Map<String, dynamic> json) => HabitDto(
        id: json['id'] as int,
        name: (json['name'] ?? '') as String,
        points: (json['points'] as int?) ?? 5,
        minusPoints: (json['minusPoints'] as int?) ?? 5,
        allowNegative: true,
        oncePerDay: false,
      );
}
