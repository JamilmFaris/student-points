import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit.dart';

/// Settings backed by SharedPreferences.
class AppMode {
  static const String _attendanceHabitIdKey = 'mode.attendance_habit_id';
  static const String _memorizationHabitIdKey = 'mode.memorization_habit_id';

  /// Local habit name considered "attendance" by default. If a habit with this
  /// name exists, it's used regardless of any override.
  static const String defaultAttendanceHabitName = 'حضور';

  static Future<int?> getAttendanceHabitOverride() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_attendanceHabitIdKey);
  }

  static Future<void> setAttendanceHabitOverride(int? habitId) async {
    final prefs = await SharedPreferences.getInstance();
    if (habitId == null) {
      await prefs.remove(_attendanceHabitIdKey);
    } else {
      await prefs.setInt(_attendanceHabitIdKey, habitId);
    }
  }

  /// Resolves the *effective* attendance habit:
  ///   1. The habit named "حضور" or "الحضور" if one exists.
  ///   2. Otherwise, the override stored in prefs (if it still exists).
  ///   3. Otherwise, null — caller must force the user to pick.
  static Future<Habit?> resolveAttendanceHabit(List<Habit> habits) async {
    final byName = habits.where(
      (h) => h.name.trim() == defaultAttendanceHabitName || h.name.trim() == 'الحضور',
    );
    if (byName.isNotEmpty) return byName.first;
    final overrideId = await getAttendanceHabitOverride();
    if (overrideId == null) return null;
    final byId = habits.where((h) => h.id == overrideId);
    return byId.isEmpty ? null : byId.first;
  }

  static Future<int?> getMemorizationHabitOverride() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_memorizationHabitIdKey);
  }

  static Future<void> setMemorizationHabitOverride(int? habitId) async {
    final prefs = await SharedPreferences.getInstance();
    if (habitId == null) {
      await prefs.remove(_memorizationHabitIdKey);
    } else {
      await prefs.setInt(_memorizationHabitIdKey, habitId);
    }
  }

  /// Resolves the *effective* memorization habit purely from the stored
  /// override. Unlike attendance, there is no default-name match — this is
  /// optional and returns null if the user hasn't picked one.
  static Future<Habit?> resolveMemorizationHabit(List<Habit> habits) async {
    final overrideId = await getMemorizationHabitOverride();
    if (overrideId == null) return null;
    final byId = habits.where((h) => h.id == overrideId);
    return byId.isEmpty ? null : byId.first;
  }
}
