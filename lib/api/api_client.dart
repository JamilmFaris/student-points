import 'dart:async';

import 'package:dio/dio.dart';

import '../services/token_storage.dart';
import 'api_config.dart';

typedef OnUnauthenticated = void Function();

class ApiClient {
  ApiClient({
    required this.tokenStorage,
    this.onUnauthenticated,
    Dio? dio,
    Dio? refreshDio,
  })  : _dio = dio ?? _buildDio(),
        _refreshDio = refreshDio ?? _buildDio() {
    _dio.interceptors.add(_AuthInterceptor(this));
  }

  final TokenStorage tokenStorage;
  OnUnauthenticated? onUnauthenticated;

  final Dio _dio;
  final Dio _refreshDio;

  Dio get dio => _dio;

  static Dio _buildDio() => Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: ApiConfig.connectTimeout,
          receiveTimeout: ApiConfig.receiveTimeout,
          contentType: 'application/json',
          responseType: ResponseType.json,
          validateStatus: (s) => s != null && s < 500,
        ),
      );

  Completer<String?>? _refreshing;

  Future<String?> _refreshAccessToken() async {
    if (_refreshing != null) return _refreshing!.future;
    final completer = Completer<String?>();
    _refreshing = completer;
    try {
      final refresh = await tokenStorage.readRefresh();
      if (refresh == null) {
        completer.complete(null);
        return null;
      }
      final res = await _refreshDio.post(
        '/api/auth/login/refresh/',
        data: {'refresh': refresh},
      );
      if (res.statusCode == 200 && res.data is Map) {
        final access = (res.data as Map)['access'] as String?;
        if (access != null) {
          await tokenStorage.saveAccess(access);
          completer.complete(access);
          return access;
        }
      }
      completer.complete(null);
      return null;
    } catch (_) {
      completer.complete(null);
      return null;
    } finally {
      _refreshing = null;
    }
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._client);

  final ApiClient _client;

  static const _skipAuthPaths = <String>[
    '/api/auth/login/',
    '/api/auth/login/refresh/',
  ];

  bool _shouldSkip(RequestOptions o) =>
      _skipAuthPaths.any((p) => o.path == p);

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_shouldSkip(options)) {
      final token = await _client.tokenStorage.readAccess();
      if (token != null) {
        options.headers['Authorization'] = '$token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onResponse(Response response, ResponseInterceptorHandler handler) async {
    if (response.statusCode == 401 && !_isRetry(response.requestOptions)) {
      final retried = await _tryRefreshAndRetry(response.requestOptions);
      if (retried != null) {
        return handler.resolve(retried);
      }
      _client.onUnauthenticated?.call();
    }
    handler.next(response);
  }

  bool _isRetry(RequestOptions o) => o.extra['__retry__'] == true;

  Future<Response?> _tryRefreshAndRetry(RequestOptions original) async {
    if (_shouldSkip(original)) return null;
    final newAccess = await _client._refreshAccessToken();
    if (newAccess == null) return null;
    final retryOptions = original.copyWith(
      headers: {
        ...original.headers,
        'Authorization': '$newAccess',
      },
      extra: {...original.extra, '__retry__': true},
    );
    try {
      return await _client._dio.fetch(retryOptions);
    } catch (_) {
      return null;
    }
  }
}
