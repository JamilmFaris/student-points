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
}
