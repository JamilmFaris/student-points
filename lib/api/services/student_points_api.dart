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

class StudentPointsDto {
  const StudentPointsDto({
    required this.id,
    required this.student,
    required this.habit,
    required this.isMinus,
    required this.points,
    required this.date,
  });

  final int id;
  final int student;
  final int habit;
  final bool isMinus;
  final int points;
  final String date;

  factory StudentPointsDto.fromJson(Map<String, dynamic> json) => StudentPointsDto(
        id: json['id'] as int,
        student: json['student'] as int,
        habit: json['habit'] as int,
        isMinus: json['isMinus'] as bool? ?? false,
        points: (json['points'] as int?) ?? 0,
        date: json['date'] as String? ?? '',
      );
}

class StudentPointsApi {
  StudentPointsApi(this._client);

  final ApiClient _client;
  Dio get _dio => _client.dio;

  /// `GET /api/student-points/` — fetch all student points from the server.
  Future<List<StudentPointsDto>> getAll({DateTime? updatedSince}) async {
    try {
      final res = await _dio.get(
        '/api/student-points/',
        queryParameters: updatedSince != null
            ? {'updated_since': updatedSince.toUtc().toIso8601String()}
            : null,
      );
      if (res.statusCode == 200 && res.data is List) {
        return (res.data as List)
            .map((e) => StudentPointsDto.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      throw ApiException(extractDrfError(res) ?? 'فشل تحميل النقاط');
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  /// `POST /api/student-points/` — create a single point record with the
  /// accumulated points value. `points` is signed; `isMinus` mirrors its sign.
  Future<void> create({
    required int studentId,
    required int habitId,
    required int points, // signed: negative when isMinus=true
    required bool isMinus,
    required String date, // YYYY-MM-DD
    int? lessonId,
  }) async {
    try {
      final res = await _dio.post(
        '/api/student-points/',
        data: {
          'student': studentId,
          'habit': habitId,
          'points': points,
          'isMinus': isMinus,
          'date': date,
          if (lessonId != null) 'lesson': lessonId,
        },
      );
      if (res.statusCode == 201) return;
      throw ApiException(extractDrfError(res) ?? 'فشل رفع النقطة');
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

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
