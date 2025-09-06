import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/habits_cubit.dart';
import '../bloc/students_cubit.dart';
import '../bloc/tracking_cubit.dart';
import '../repositories/habit_repository.dart';
import '../repositories/student_repository.dart';
import '../repositories/tracking_repository.dart';

class TrackingScreen extends StatelessWidget {
	const TrackingScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Directionality(
			textDirection: TextDirection.rtl,
			child: MultiBlocProvider(
				providers: [
					BlocProvider(create: (_) => StudentsCubit(StudentRepository())),
					BlocProvider(create: (_) => HabitsCubit(HabitRepository())),
					BlocProvider(create: (_) => TrackingCubit(TrackingRepository())),
				],
				child: Scaffold(
					appBar: AppBar(title: const Text('تتبع النقاط لليوم')),
					body: const _TrackingTable(),
					floatingActionButton: Builder(
						builder: (context) {
							return FloatingActionButton.extended(
								onPressed: () => context.read<TrackingCubit>().saveAll(),
								label: const Text('حفظ'),
								icon: const Icon(Icons.save),
							);
						},
					),
				),
			),
		);
	}
}

class _TrackingTable extends StatelessWidget {
	const _TrackingTable();

	@override
	Widget build(BuildContext context) {
		return BlocBuilder<StudentsCubit, StudentsState>(builder: (context, sState) {
			return BlocBuilder<HabitsCubit, HabitsState>(builder: (context, hState) {
				return BlocBuilder<TrackingCubit, TrackingState>(builder: (context, tState) {
					if (sState.loading || hState.loading || tState.loading) {
						return const Center(child: CircularProgressIndicator());
					}
					final students = sState.students;
					final habits = hState.habits;
					final columns = <DataColumn>[
						const DataColumn(label: Text('الطالب')),
						const DataColumn(label: Text('المجموع')),
						for (final h in habits) DataColumn(label: Text(h.name)),
					];

					final rows = students.map((student) {
						final counts = tState.countsByStudentHabit[student.id] ?? {};
						int total = 0;
						for (final h in habits) {
							final c = counts[h.id] ?? 0;
							total += c * h.points;
						}
						return DataRow(cells: [
							DataCell(Text(student.name)),
							DataCell(Text('$total')),
							for (final h in habits)
								DataCell(
									ElevatedButton(
										onPressed: () => context.read<TrackingCubit>().increment(student.id!, h.id!),
										child: Text('${counts[h.id] ?? 0}'),
									),
								),
						]);
					}).toList();

					return SingleChildScrollView(
						scrollDirection: Axis.horizontal,
						child: DataTable(columns: columns, rows: rows),
					);
				});
			});
		});
	}
}


