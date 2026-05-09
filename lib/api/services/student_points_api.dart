import 'package:dio/dio.dart';

import '../api_client.dart';
import '_dio_error.dart';

class BatchPointEntry {
  const BatchPointEntry({
    required this.studentId,
    required this.habitId,
    required this.plusCount,
    required this.minusCount,
  });

  final int studentId;
  final int habitId;
  final int plusCount;
  final int minusCount;

  Map<String, dynamic> toJson() => {
        'student_id': studentId,
        'habit_id': habitId,
        'plus_count': plusCount,
        'minus_count': minusCount,
      };
}

class BatchPointsResult {
  const BatchPointsResult({required this.written, required this.deleted});
  final int written;
  final int deleted;
}

class StudentPointsApi {
  StudentPointsApi(this._client);

  final ApiClient _client;
  Dio get _dio => _client.dio;

  /// `POST /api/student-points/batch/` — overwrite-semantics push of one
  /// day's points. Server replaces all rows for each (student, habit, date)
  /// tuple in the payload.
  Future<BatchPointsResult> batchPush({
    required String date, // YYYY-MM-DD
    required List<BatchPointEntry> entries,
    int? lessonId,
  }) async {
    try {
      final res = await _dio.post(
        '/api/student-points/batch/',
        data: {
          'date': date,
          if (lessonId != null) 'lesson_id': lessonId,
          'entries': entries.map((e) => e.toJson()).toList(),
        },
      );
      if (res.statusCode == 201 && res.data is Map) {
        final data = res.data as Map;
        return BatchPointsResult(
          written: (data['written'] as int?) ?? 0,
          deleted: (data['deleted'] as int?) ?? 0,
        );
      }
      throw ApiException(extractDrfError(res) ?? 'فشل رفع النقاط');
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }
}
