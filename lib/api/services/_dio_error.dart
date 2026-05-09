import 'package:dio/dio.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

String? extractDrfError(Response res) {
  final body = res.data;
  if (body is Map) {
    if (body['detail'] is String) return body['detail'] as String;
    for (final entry in body.entries) {
      final v = entry.value;
      if (v is List && v.isNotEmpty) return '${entry.key}: ${v.first}';
      if (v is String) return '${entry.key}: $v';
    }
  }
  return null;
}

ApiException toApiException(DioException e) {
  if (e.response != null) {
    final msg = extractDrfError(e.response!) ?? 'خطأ ${e.response!.statusCode}';
    return ApiException(msg, statusCode: e.response!.statusCode);
  }
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return ApiException('انتهت مهلة الاتصال');
    case DioExceptionType.connectionError:
      return ApiException('تعذّر الاتصال بالخادم');
    default:
      return ApiException(e.message ?? 'حدث خطأ غير متوقع');
  }
}
