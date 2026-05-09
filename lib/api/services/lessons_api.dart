import 'package:dio/dio.dart';

import '../api_client.dart';
import '../dto/lesson_dto.dart';
import '_dio_error.dart';

class LessonsApi {
  LessonsApi(this._client);

  final ApiClient _client;
  Dio get _dio => _client.dio;

  Future<LessonDto> create({required String subject}) async {
    try {
      final res = await _dio.post('/api/lessons/', data: {'subject': subject});
      if (res.statusCode == 201 && res.data is Map) {
        return LessonDto.fromJson(Map<String, dynamic>.from(res.data as Map));
      }
      throw ApiException(extractDrfError(res) ?? 'فشل إنشاء الدرس');
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<LessonDto> update({required int remoteId, required String subject}) async {
    try {
      final res = await _dio
          .patch('/api/lessons/$remoteId/', data: {'subject': subject});
      if ((res.statusCode == 200 || res.statusCode == 202) && res.data is Map) {
        return LessonDto.fromJson(Map<String, dynamic>.from(res.data as Map));
      }
      throw ApiException(extractDrfError(res) ?? 'فشل تحديث الدرس');
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> delete(int remoteId) async {
    try {
      final res = await _dio.delete('/api/lessons/$remoteId/');
      if (res.statusCode == 204 || res.statusCode == 200 || res.statusCode == 404) {
        return;
      }
      throw ApiException(extractDrfError(res) ?? 'فشل حذف الدرس');
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }
}
