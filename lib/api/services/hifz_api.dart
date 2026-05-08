import 'package:dio/dio.dart';

import '../api_client.dart';
import '../dto/hifz_dto.dart';
import '_dio_error.dart';

class HifzApi {
  HifzApi(this._client);

  final ApiClient _client;
  Dio get _dio => _client.dio;

  Future<List<HifzDto>> getAll({DateTime? updatedSince}) async {
    try {
      final res = await _dio.get(
        '/api/quran/hifz/',
        queryParameters: {
          if (updatedSince != null)
            'updated_since': updatedSince.toUtc().toIso8601String(),
        },
      );
      if (res.statusCode == 200 && res.data is List) {
        return (res.data as List)
            .map((e) => HifzDto.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      throw ApiException(extractDrfError(res) ?? 'فشل تحميل الحفظ');
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  /// `POST /api/quran/hifz/`. [studentId] is the *server-side* id (resolved by
  /// the caller from the local `students.remote_id` map).
  Future<HifzDto> create({
    required int studentId,
    required int chapterIndex,
    required int start,
    required int end,
    required String date,
    String? label,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{
        'student_id': studentId,
        'chapter_index': chapterIndex,
        'start': start,
        'end': end,
        'date': date,
        if (label != null) 'label': label,
        if (notes != null) 'notes': notes,
      };
      final res = await _dio.post('/api/quran/hifz/', data: body);
      if (res.statusCode == 201 && res.data is Map) {
        return HifzDto.fromJson(Map<String, dynamic>.from(res.data as Map));
      }
      throw ApiException(extractDrfError(res) ?? 'فشل إنشاء الحفظ');
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }
}
