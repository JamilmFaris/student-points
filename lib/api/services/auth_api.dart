import 'package:dio/dio.dart';

import '../api_client.dart';
import '../dto/user_dto.dart';

class AuthApiException implements Exception {
  AuthApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class TokenPair {
  TokenPair({required this.access, required this.refresh});
  final String access;
  final String refresh;
}

class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;
  Dio get _dio => _client.dio;

  Future<TokenPair> login(String username, String password) async {
    try {
      final res = await _dio.post(
        '/api/auth/login/',
        data: {'username': username, 'password': password},
      );
      if (res.statusCode == 200 && res.data is Map) {
        final data = res.data as Map;
        final access = data['access'] as String?;
        final refresh = data['refresh'] as String?;
        if (access != null && refresh != null) {
          return TokenPair(access: access, refresh: refresh);
        }
      }
      throw AuthApiException(_extractError(res) ?? 'فشل تسجيل الدخول');
    } on DioException catch (e) {
      throw AuthApiException(_dioMessage(e));
    }
  }

  Future<UserDto> me() async {
    try {
      final res = await _dio.get('/api/users/me/');
      if (res.statusCode == 200 && res.data is Map) {
        return UserDto.fromJson(Map<String, dynamic>.from(res.data as Map));
      }
      throw AuthApiException(_extractError(res) ?? 'تعذّر جلب بيانات المستخدم');
    } on DioException catch (e) {
      throw AuthApiException(_dioMessage(e));
    }
  }

  /// `PATCH /api/users/me/` — update editable profile fields.
  Future<UserDto> updateMe({
    String? email,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? study,
    String? dateOfBirth,
    String? certificates,
  }) async {
    try {
      final body = <String, dynamic>{
        if (email != null) 'email': email,
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        if (study != null) 'study': study,
        if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
        if (certificates != null) 'certificates': certificates,
      };
      final res = await _dio.patch('/api/users/me/', data: body);
      if ((res.statusCode == 200 || res.statusCode == 202) && res.data is Map) {
        return UserDto.fromJson(Map<String, dynamic>.from(res.data as Map));
      }
      throw AuthApiException(_extractError(res) ?? 'تعذّر تحديث بيانات المستخدم');
    } on DioException catch (e) {
      throw AuthApiException(_dioMessage(e));
    }
  }

  String? _extractError(Response res) {
    final body = res.data;
    if (body is Map) {
      // DRF error shapes: {"detail": "..."} or {"field": ["msg"]}
      if (body['detail'] is String) return body['detail'] as String;
      for (final entry in body.entries) {
        final v = entry.value;
        if (v is List && v.isNotEmpty) return '${entry.key}: ${v.first}';
        if (v is String) return '${entry.key}: $v';
      }
    }
    return null;
  }

  String _dioMessage(DioException e) {
    if (e.response != null) {
      return _extractError(e.response!) ?? 'خطأ ${e.response!.statusCode}';
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'انتهت مهلة الاتصال';
      case DioExceptionType.connectionError:
        return 'تعذّر الاتصال بالخادم';
      default:
        return e.message ?? 'حدث خطأ غير متوقع';
    }
  }
}
