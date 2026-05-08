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
}
