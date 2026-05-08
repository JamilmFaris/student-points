import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api/api_client.dart';
import 'api/services/auth_api.dart';
import 'bloc/auth_cubit.dart';
import 'bloc/students_cubit.dart';
import 'repositories/student_repository.dart';
import 'services/token_storage.dart';
import 'ui/habits_screen.dart';
import 'ui/home_screen.dart';
import 'ui/login_screen.dart';
import 'ui/logs_screen.dart';
import 'ui/memorization_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/splash_screen.dart';
import 'ui/students_screen.dart';
import 'ui/tracking_screen.dart';

void main() {
  final tokenStorage = TokenStorage();
  final apiClient = ApiClient(tokenStorage: tokenStorage);
  final authApi = AuthApi(apiClient);
  final authCubit = AuthCubit(authApi: authApi, tokenStorage: tokenStorage);
  apiClient.onUnauthenticated = authCubit.forceUnauthenticated;

  runApp(MyApp(authCubit: authCubit));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.authCubit});

  final AuthCubit authCubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: authCubit,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'نقاط الطلاب',
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
        locale: const Locale('ar'),
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar')],
        home: const _AuthGate(),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/home': (_) => const HomeScreen(),
          '/students': (_) => BlocProvider(
                create: (_) => StudentsCubit(StudentRepository()),
                child: const StudentsScreen(),
              ),
          '/habits': (_) => const HabitsScreen(),
          '/tracking': (_) => const TrackingScreen(),
          '/logs': (_) => const LogsScreen(),
          '/quran': (_) => const MemorizationScreen(),
          '/settings': (_) => const SettingsScreen(),
        },
      ),
    );
  }
}

/// Routes between Splash / Home / Login based on the current auth state.
/// Splash performs the initial token-restore call.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (prev, curr) => prev.status != curr.status,
      builder: (context, state) {
        switch (state.status) {
          case AuthStatus.unknown:
          case AuthStatus.authenticating:
            return const SplashScreen();
          case AuthStatus.authenticated:
            return const HomeScreen();
          case AuthStatus.unauthenticated:
          case AuthStatus.error:
            return const LoginScreen();
        }
      },
    );
  }
}
