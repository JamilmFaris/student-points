import 'package:dio/dio.dart';

import '../api_client.dart';
import '_dio_error.dart';

class AttendanceApi {
  AttendanceApi(this._client);

  final ApiClient _client;
  Dio get _dio => _client.dio;

  /// `POST /api/lessons/{lesson_id}/attendances` — bulk mark attendance.
  /// Server upserts on (lesson, student, date): every student in [studentIds]
  /// gets attended=true; every other student of that lesson on [date] gets
  /// attended=false (the payload is the source of truth for that day).
  Future<void> bulkMark({
    required int lessonRemoteId,
    required String date, // YYYY-MM-DD
    required List<int> studentIds,
  }) async {
    try {
      final res = await _dio.post(
        '/api/lessons/$lessonRemoteId/attendances',
        data: {
          'date': date,
          'students': studentIds.map((id) => {'studentId': id}).toList(),
        },
      );
      if (res.statusCode == 201 || res.statusCode == 200) return;
      throw ApiException(extractDrfError(res) ?? 'فشل تسجيل الحضور');
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }
}
