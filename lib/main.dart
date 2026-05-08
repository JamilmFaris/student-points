import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api/api_client.dart';
import 'api/services/attendance_api.dart';
import 'api/services/auth_api.dart';
import 'api/services/habits_api.dart';
import 'api/services/hifz_api.dart';
import 'api/services/lessons_api.dart';
import 'api/services/student_points_api.dart';
import 'api/services/students_api.dart';
import 'bloc/auth_cubit.dart';
import 'bloc/students_cubit.dart';
import 'bloc/sync_cubit.dart';
import 'repositories/student_repository.dart';
import 'services/connectivity_watcher.dart';
import 'services/sync_service.dart';
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
  final studentsApi = StudentsApi(apiClient);
  final hifzApi = HifzApi(apiClient);
  final habitsApi = HabitsApi(apiClient);
  final studentPointsApi = StudentPointsApi(apiClient);
  final lessonsApi = LessonsApi(apiClient);
  final attendanceApi = AttendanceApi(apiClient);

  final authCubit = AuthCubit(authApi: authApi, tokenStorage: tokenStorage);
  final syncService = SyncService(
    studentsApi: studentsApi,
    hifzApi: hifzApi,
    habitsApi: habitsApi,
    studentPointsApi: studentPointsApi,
    lessonsApi: lessonsApi,
    attendanceApi: attendanceApi,
  );
  final syncCubit = SyncCubit(syncService: syncService);

  apiClient.onUnauthenticated = authCubit.forceUnauthenticated;

  ConnectivityWatcher(authCubit: authCubit, syncCubit: syncCubit).start();

  runApp(MyApp(authCubit: authCubit, syncCubit: syncCubit));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.authCubit, required this.syncCubit});

  final AuthCubit authCubit;
  final SyncCubit syncCubit;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: authCubit),
        BlocProvider.value(value: syncCubit),
      ],
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
        builder: (context, child) {
          // Trigger a full pull whenever auth flips to authenticated. Sits at the
          // MaterialApp builder so it runs regardless of which screen is mounted.
          return BlocListener<AuthCubit, AuthState>(
            listenWhen: (prev, curr) =>
                prev.status != AuthStatus.authenticated &&
                curr.status == AuthStatus.authenticated,
            listener: (context, _) =>
                context.read<SyncCubit>().performLoginSync(),
            child: child ?? const SizedBox.shrink(),
          );
        },
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
