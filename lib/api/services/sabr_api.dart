import 'package:dio/dio.dart';

import '../api_client.dart';
import '_dio_error.dart';

typedef QuranSabrEntry = ({int id, int studentId, String sabrType, dynamic range});
typedef HadithSabrEntry = ({int id, int studentId, String hadithType});

class SabrApi {
  SabrApi(this._client);

  final ApiClient _client;
  Dio get _dio => _client.dio;

  Future<void> createQuranSabr({
    required int studentId,
    required String sabrType,
    required List<int> range,
  }) async {
    try {
      final res = await _dio.post('/api/quran/sabr/', data: {
        'student_id': studentId,
        'sabr_type': sabrType,
        'range': range,
      });
      if (res.statusCode == 201) return;
      throw ApiException(extractDrfError(res) ?? 'فشل إنشاء السبر');
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> createHadithSabr({
    required int studentId,
    required String hadithType,
  }) async {
    try {
      final res = await _dio.post('/api/hadith/sabr/', data: {
        'student_id': studentId,
        'hadith_type': hadithType,
      });
      if (res.statusCode == 201) return;
      throw ApiException(extractDrfError(res) ?? 'فشل إنشاء سبر الحديث');
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<List<QuranSabrEntry>> listQuranSabr() async {
    try {
      final res = await _dio.get('/api/quran/sabr/');
      if (res.statusCode == 200 && res.data is List) {
        return (res.data as List).map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return (
            id: m['id'] as int,
            studentId: m['student_id'] as int,
            sabrType: m['sabr_type'] as String,
            range: m['range'],
          );
        }).toList();
      }
      throw ApiException(extractDrfError(res) ?? 'فشل تحميل السبر');
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<List<HadithSabrEntry>> listHadithSabr() async {
    try {
      final res = await _dio.get('/api/hadith/sabr/');
      if (res.statusCode == 200 && res.data is List) {
        return (res.data as List).map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return (
            id: m['id'] as int,
            studentId: m['student_id'] as int,
            hadithType: m['hadith_type'] as String,
          );
        }).toList();
      }
      throw ApiException(extractDrfError(res) ?? 'فشل تحميل سبر الحديث');
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }
}
