import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/students_cubit.dart';
import '../repositories/tracking_repository.dart';
import '../repositories/habit_repository.dart';
import '../models/habit.dart';
import 'widgets/habit_progress_chart.dart';

class StudentsScreen extends StatelessWidget {
	const StudentsScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Directionality(
			textDirection: TextDirection.rtl,
			child: Scaffold(
					appBar: AppBar(title: const Text('الطلاب')),
					body: BlocBuilder<StudentsCubit, StudentsState>(
						builder: (context, state) {
							if (state.loading) return const Center(child: CircularProgressIndicator());
							return ReorderableListView.builder(
								padding: const EdgeInsets.only(bottom: 96),
								itemCount: state.students.length,
								onReorder: (oldIndex, newIndex) => context.read<StudentsCubit>().reorderStudents(oldIndex, newIndex),
								itemBuilder: (context, index) {
									final s = state.students[index];
									return ListTile(
										key: ValueKey(s.id),
										title: Text(s.name),
										trailing: Row(
											mainAxisSize: MainAxisSize.min,
											children: [
												ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle)),
												IconButton(
													icon: const Icon(Icons.edit),
													onPressed: () async {
														final name = await _promptName(context, initial: s.name);
														if (name != null && name.trim().isNotEmpty) {
															context.read<StudentsCubit>().updateStudent(s.copyWith(name: name.trim()));
														}
													},
												),
												IconButton(
													icon: const Icon(Icons.show_chart),
													onPressed: () async {
														final habits = await HabitRepository().getAll();
														if (habits.isEmpty) return;
														Habit? selectedHabit = habits.first;
														final now = DateTime.now();
														final start = now.subtract(const Duration(days: 29));
														final habit = await showDialog<Habit>(
															context: context,
															builder: (ctx) {
																return AlertDialog(
																	title: const Text('اختر العادة'),
																	content: StatefulBuilder(
																		builder: (context, setState) {
																		return DropdownButton<Habit>(
																			isExpanded: true,
																			value: selectedHabit,
																			items: habits.map((h) => DropdownMenuItem(value: h, child: Text(h.name))).toList(),
																			onChanged: (v) => setState(() => selectedHabit = v),
																		);
																	},
																),
																actions: [
																	TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
																	TextButton(onPressed: () => Navigator.pop(ctx, selectedHabit), child: const Text('متابعة')),
																],
															);
														},
														);
														if (habit == null) return;
														showModalBottomSheet(
															context: context,
															isScrollControlled: true,
															builder: (ctx) {
																return Directionality(
																	textDirection: TextDirection.rtl,
																	child: Padding(
																		padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
																		child: HabitProgressChart(
																			habit: habit,
																			startDate: DateTime(start.year, start.month, start.day),
																			endDate: DateTime(now.year, now.month, now.day),
																			repo: TrackingRepository(),
																			fixedStudentId: s.id,
																		),
																	),
																);
															},
														);
													},
												),
												IconButton(
													icon: const Icon(Icons.delete),
													onPressed: () => context.read<StudentsCubit>().deleteStudent(s.id!),
												),
											],
										),
									);
								},
							);
						},
					),
					floatingActionButton: FloatingActionButton.extended(
						onPressed: () async {
							await _addStudentsFlow(context);
						},
						label: const Text('إضافة طالب'),
						icon: const Icon(Icons.add),
					),
				),
		);
	}

	Future<String?> _promptName(BuildContext context, {String? initial}) async {
		final controller = TextEditingController(text: initial ?? '');
		return showDialog<String>(
			context: context,
			builder: (context) => AlertDialog(
				title: const Text('اسم الطالب'),
				content: TextField(controller: controller, textDirection: TextDirection.rtl),
				actions: [
					TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
					TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('حفظ')),
				],
			),
		);
	}

	Future<void> _addStudentsFlow(BuildContext context) async {
		while (true) {
			final result = await _promptNameForAdd(context);
			if (result == null) return;
			final name = result.name.trim();
			if (name.isNotEmpty) {
				await context.read<StudentsCubit>().addStudent(name);
			}
			if (!result.addAnother) return;
		}
	}

	Future<_NameDialogResult?> _promptNameForAdd(BuildContext context) async {
		final controller = TextEditingController(text: '');
		return showDialog<_NameDialogResult>(
			context: context,
			builder: (context) => AlertDialog(
				title: const Text('اسم الطالب'),
				content: TextField(controller: controller, textDirection: TextDirection.rtl, autofocus: true),
				actions: [
					TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
					TextButton(
						onPressed: () => Navigator.pop(context, _NameDialogResult(controller.text, false)),
						child: const Text('حفظ'),
					),
					TextButton(
						onPressed: () => Navigator.pop(context, _NameDialogResult(controller.text, true)),
						child: const Text('حفظ وإضافة آخر'),
					),
				],
			),
		);
	}
}

class _NameDialogResult {
	final String name;
	final bool addAnother;

	_NameDialogResult(this.name, this.addAnother);
}


