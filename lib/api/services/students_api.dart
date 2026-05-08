import 'package:dio/dio.dart';

import '../api_client.dart';
import '../dto/student_dto.dart';
import '_dio_error.dart';

class StudentsApi {
  StudentsApi(this._client);

  final ApiClient _client;
  Dio get _dio => _client.dio;

  /// `GET /api/students/`. When [updatedSince] is provided, the server returns
  /// only rows changed after that timestamp (and includes tombstones).
  Future<List<StudentDto>> getAll({DateTime? updatedSince}) async {
    try {
      final res = await _dio.get(
        '/api/students/',
        queryParameters: {
          if (updatedSince != null)
            'updated_since': updatedSince.toUtc().toIso8601String(),
        },
      );
      if (res.statusCode == 200 && res.data is List) {
        return (res.data as List)
            .map((e) => StudentDto.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      throw ApiException(extractDrfError(res) ?? 'فشل تحميل الطلاب');
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }
}
