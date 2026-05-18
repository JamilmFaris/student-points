import 'package:dio/dio.dart';

import '../api_client.dart';
import '../dto/hadith_hifz_dto.dart';
import '_dio_error.dart';

class HadithHifzApi {
    HadithHifzApi(this._client);

    final ApiClient _client;
    Dio get _dio => _client.dio;

    Future<List<HadithHifzDto>> getAll({DateTime? updatedSince}) async {
        try {
            final res = await _dio.get(
                '/api/hadith/hifz/',
                queryParameters: {
                    if (updatedSince != null)
                        'updated_since': updatedSince.toUtc().toIso8601String(),
                },
            );
            if (res.statusCode == 200 && res.data is List) {
                return (res.data as List)
                    .map((e) => HadithHifzDto.fromJson(Map<String, dynamic>.from(e as Map)))
                    .toList();
            }
            throw ApiException(extractDrfError(res) ?? 'فشل تحميل حفظ الأحاديث');
        } on DioException catch (e) {
            throw toApiException(e);
        }
    }

    Future<HadithHifzDto> create({
        required int studentId,
        required List<int> hadithNumbers,
        required String date,
        String? notes,
        String? label,
    }) async {
        try {
            final body = <String, dynamic>{
                'student_id': studentId,
                'hadith_numbers': hadithNumbers,
                'date': date,
                if (notes != null) 'notes': notes,
                if (label != null) 'label': label,
            };
            final res = await _dio.post('/api/hadith/hifz/', data: body);
            if (res.statusCode == 201 && res.data is Map) {
                return HadithHifzDto.fromJson(Map<String, dynamic>.from(res.data as Map));
            }
            throw ApiException(extractDrfError(res) ?? 'فشل إنشاء حفظ الحديث');
        } on DioException catch (e) {
            throw toApiException(e);
        }
    }

    Future<HadithHifzDto> update({
        required int remoteId,
        List<int>? hadithNumbers,
        String? date,
        String? notes,
        String? label,
    }) async {
        try {
            final body = <String, dynamic>{
                if (hadithNumbers != null) 'hadith_numbers': hadithNumbers,
                if (date != null) 'date': date,
                if (notes != null) 'notes': notes,
                if (label != null) 'label': label,
            };
            final res = await _dio.patch('/api/hadith/hifz/$remoteId/', data: body);
            if ((res.statusCode == 200 || res.statusCode == 202) && res.data is Map) {
                return HadithHifzDto.fromJson(Map<String, dynamic>.from(res.data as Map));
            }
            throw ApiException(extractDrfError(res) ?? 'فشل تحديث حفظ الحديث');
        } on DioException catch (e) {
            throw toApiException(e);
        }
    }

    Future<void> delete(int remoteId) async {
        try {
            final res = await _dio.delete('/api/hadith/hifz/$remoteId/');
            if (res.statusCode == 204 || res.statusCode == 200 || res.statusCode == 404) {
                return;
            }
            throw ApiException(extractDrfError(res) ?? 'فشل حذف حفظ الحديث');
        } on DioException catch (e) {
            throw toApiException(e);
        }
    }
}
