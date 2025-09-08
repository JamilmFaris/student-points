import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'ui/home_screen.dart';
import 'ui/habits_screen.dart';
import 'ui/logs_screen.dart';
import 'ui/students_screen.dart';
import 'ui/tracking_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/students_cubit.dart';
import 'repositories/student_repository.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      routes: {
        '/': (_) => const HomeScreen(),
        '/students': (_) => BlocProvider(
              create: (_) => StudentsCubit(StudentRepository()),
              child: const StudentsScreen(),
            ),
        '/habits': (_) => const HabitsScreen(),
        '/tracking': (_) => const TrackingScreen(),
        '/logs': (_) => const LogsScreen(),
      },
    );
  }
}
 
