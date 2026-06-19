import 'package:dio/dio.dart';

import '../api_client.dart';
import '../dto/habit_dto.dart';
import '_dio_error.dart';

class HabitsApi {
  HabitsApi(this._client);

  final ApiClient _client;
  Dio get _dio => _client.dio;

  /// Read-only list. Used for `name → remote_id` resolution when pushing
  /// daily-points batches.
  Future<List<HabitDto>> getAll() async {
    try {
      final res = await _dio.get('/api/habits/');
      if (res.statusCode == 200 && res.data is List) {
        return (res.data as List)
            .map((e) => HabitDto.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      throw ApiException(extractDrfError(res) ?? 'فشل تحميل العادات');
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  /// `POST /api/habits/`. Creates a new habit.
  Future<HabitDto> create(String name, int points, int minusPoints, {bool allowNegative = false, bool oncePerDay = false}) async {
    try {
      final body = {
        'name': name,
        'description': name,
        'points': points,
        'minusPoints': minusPoints,
        'allowNegative': allowNegative,
        'oncePerDay': oncePerDay,
      };
      final res = await _dio.post('/api/habits/', data: body);
      if (res.statusCode == 201 && res.data is Map) {
        return HabitDto.fromJson(Map<String, dynamic>.from(res.data as Map));
      }
      throw ApiException(extractDrfError(res) ?? 'فشل إنشاء العادة');
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  /// `PATCH /api/habits/{id}/`. Updates an existing habit.
  Future<HabitDto> update(int remoteId, String name, int points, int minusPoints, {bool allowNegative = false, bool oncePerDay = false}) async {
    try {
      final body = {
        'name': name,
        'description': name,
        'points': points,
        'minusPoints': minusPoints,
        'allowNegative': allowNegative,
        'oncePerDay': oncePerDay,
      };
      final res = await _dio.patch('/api/habits/$remoteId/', data: body);
      if ((res.statusCode == 200 || res.statusCode == 202) && res.data is Map) {
        return HabitDto.fromJson(Map<String, dynamic>.from(res.data as Map));
      }
      throw ApiException(extractDrfError(res) ?? 'فشل تحديث العادة');
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  /// `DELETE /api/habits/{id}/`. Deletes a habit.
  Future<void> delete(int remoteId) async {
    try {
      final res = await _dio.delete('/api/habits/$remoteId/');
      if (res.statusCode == 204 || res.statusCode == 200 || res.statusCode == 404) {
        return;
      }
      throw ApiException(extractDrfError(res) ?? 'فشل حذف العادة');
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }
}
