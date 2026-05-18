import 'dart:convert';

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

  /// Called from app start: restores session from storage without a network
  /// round-trip. Expiry is caught lazily by [forceUnauthenticated] when the
  /// first real API call (e.g. sync) fails after a failed token refresh.
  Future<void> restore() async {
    if (!await tokenStorage.hasTokens()) {
      emit(const AuthState.unauthenticated());
      return;
    }
    final userJson = await tokenStorage.readUserJson();
    if (userJson != null) {
      try {
        final user = UserDto.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
        emit(AuthState.authenticated(user));
        return;
      } catch (_) {}
    }
    // Tokens exist but no cached user (first run after this change) — fetch once.
    try {
      final user = await authApi.me();
      await tokenStorage.saveUserJson(jsonEncode(user.toJson()));
      emit(AuthState.authenticated(user));
    } on AuthApiException {
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
      await tokenStorage.saveUserJson(jsonEncode(user.toJson()));
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
    await tokenStorage.saveUserJson(jsonEncode(updated.toJson()));
    emit(AuthState.authenticated(updated));
    return updated;
  }

  /// POST /api/users/me/change-password/ — change the user's password.
  Future<void> changePassword(String currentPassword, String newPassword) async {
    await authApi.changePassword(currentPassword, newPassword);
  }
}
