import 'package:flutter_bloc/flutter_bloc.dart';

import '../api/dto/user_dto.dart';
import '../api/services/auth_api.dart';
import '../services/token_storage.dart';

enum AuthStatus { unknown, unauthenticated, authenticating, authenticated, error }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  final AuthStatus status;
  final UserDto? user;
  final String? errorMessage;

  const AuthState.unknown() : this(status: AuthStatus.unknown);
  const AuthState.unauthenticated({String? error})
      : this(status: AuthStatus.unauthenticated, errorMessage: error);
  const AuthState.authenticating() : this(status: AuthStatus.authenticating);
  AuthState.authenticated(UserDto user)
      : this(status: AuthStatus.authenticated, user: user);
  const AuthState.error(String message)
      : this(status: AuthStatus.error, errorMessage: message);
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required this.authApi,
    required this.tokenStorage,
  }) : super(const AuthState.unknown());

  final AuthApi authApi;
  final TokenStorage tokenStorage;

  /// Called from app start: if tokens exist, fetch /me/. Otherwise unauthenticated.
  Future<void> restore() async {
    if (!await tokenStorage.hasTokens()) {
      emit(const AuthState.unauthenticated());
      return;
    }
    try {
      final user = await authApi.me();
      emit(AuthState.authenticated(user));
    } on AuthApiException {
      // Token rejected (e.g. token_version bumped on another device).
      await tokenStorage.clear();
      emit(const AuthState.unauthenticated());
    }
  }

  Future<void> login(String username, String password) async {
    emit(const AuthState.authenticating());
    try {
      final pair = await authApi.login(username, password);
      await tokenStorage.save(access: pair.access, refresh: pair.refresh);
      final user = await authApi.me();
      emit(AuthState.authenticated(user));
    } on AuthApiException catch (e) {
      await tokenStorage.clear();
      emit(AuthState.error(e.message));
    }
  }

  Future<void> logout() async {
    await tokenStorage.clear();
    emit(const AuthState.unauthenticated());
  }

  /// Called by ApiClient when a request fails auth even after refresh.
  Future<void> forceUnauthenticated() async {
    await tokenStorage.clear();
    emit(const AuthState.unauthenticated(error: 'انتهت الجلسة، الرجاء تسجيل الدخول'));
  }

  void clearError() {
    if (state.status == AuthStatus.error) {
      emit(const AuthState.unauthenticated());
    }
  }

  /// PATCH /api/users/me/ with the supplied fields. On success, emits an
  /// authenticated state carrying the refreshed UserDto.
  Future<UserDto> updateProfile({
    String? email,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? study,
    String? dateOfBirth,
    String? certificates,
  }) async {
    final updated = await authApi.updateMe(
      email: email,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
      study: study,
      dateOfBirth: dateOfBirth,
      certificates: certificates,
    );
    emit(AuthState.authenticated(updated));
    return updated;
  }
}
