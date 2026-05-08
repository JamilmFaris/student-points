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

  /// `PATCH /api/students/{id}/`. Sends only the fields we have locally.
  Future<StudentDto> update(int remoteId, StudentDto payload) async {
    try {
      final body = <String, dynamic>{
        'first_name': payload.firstName,
        'last_name': payload.lastName,
        if (payload.fatherName != null) 'father_name': payload.fatherName,
        if (payload.motherName != null) 'mother_name': payload.motherName,
        if (payload.dateOfBirth != null) 'date_of_birth': payload.dateOfBirth,
        if (payload.school != null) 'school': payload.school,
        if (payload.phoneNumber != null) 'phone_number': payload.phoneNumber,
        if (payload.parentPhoneNumber != null)
          'parent_phone_number': payload.parentPhoneNumber,
        if (payload.birthPlace != null) 'birth_place': payload.birthPlace,
      };
      final res = await _dio.patch('/api/students/$remoteId/', data: body);
      if ((res.statusCode == 200 || res.statusCode == 202) && res.data is Map) {
        return StudentDto.fromJson(Map<String, dynamic>.from(res.data as Map));
      }
      throw ApiException(extractDrfError(res) ?? 'فشل تحديث الطالب');
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  /// `DELETE /api/students/{id}/`. Backend performs a soft-delete.
  Future<void> delete(int remoteId) async {
    try {
      final res = await _dio.delete('/api/students/$remoteId/');
      if (res.statusCode == 204 || res.statusCode == 200 || res.statusCode == 404) {
        return;
      }
      throw ApiException(extractDrfError(res) ?? 'فشل حذف الطالب');
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  /// `POST /api/students/`. Returns the created row (with `id`/`updated_at`).
  /// Server-required fields (date_of_birth, father_name, mother_name, school) are
  /// sent as empty strings when locally absent — matches DRF defaults rather than
  /// failing the upload.
  Future<StudentDto> create(StudentDto payload) async {
    try {
      final body = <String, dynamic>{
        'first_name': payload.firstName,
        'last_name': payload.lastName,
        'father_name': payload.fatherName ?? '',
        'mother_name': payload.motherName ?? '',
        'date_of_birth': payload.dateOfBirth ?? '',
        'school': payload.school ?? '',
        if (payload.phoneNumber != null) 'phone_number': payload.phoneNumber,
        if (payload.parentPhoneNumber != null)
          'parent_phone_number': payload.parentPhoneNumber,
        if (payload.birthPlace != null) 'birth_place': payload.birthPlace,
      };
      final res = await _dio.post('/api/students/', data: body);
      if (res.statusCode == 201 && res.data is Map) {
        return StudentDto.fromJson(Map<String, dynamic>.from(res.data as Map));
      }
      throw ApiException(extractDrfError(res) ?? 'فشل إنشاء الطالب');
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }
}
