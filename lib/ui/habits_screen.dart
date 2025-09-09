import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/habits_cubit.dart';
import '../repositories/habit_repository.dart';

class HabitsScreen extends StatelessWidget {
	const HabitsScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Directionality(
			textDirection: TextDirection.rtl,
			child: BlocProvider(
				create: (_) => HabitsCubit(HabitRepository()),
				child: Scaffold(
					appBar: AppBar(title: const Text('العادات')),
					body: BlocBuilder<HabitsCubit, HabitsState>(
						builder: (context, state) {
							if (state.loading) return const Center(child: CircularProgressIndicator());
							return ListView.builder(
                padding: const EdgeInsets.only(bottom: 96),
								itemCount: state.habits.length,
								itemBuilder: (context, index) {
									final h = state.habits[index];
									return ListTile(
										title: Text(h.name),
										subtitle: Text('النقاط: ${h.points}'),
										trailing: Row(
											mainAxisSize: MainAxisSize.min,
											children: [
												IconButton(
													icon: const Icon(Icons.edit),
													onPressed: () async {
														final result = await _promptHabit(context, name: h.name, points: h.points.toString());
														if (result != null) {
															try {
																await context.read<HabitsCubit>().updateHabit(
																	h.copyWith(name: result.$1, points: int.parse(result.$2)),
																);
																ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث العادة')));
															} catch (e) {
																print(e); 
															}
														}
													},
												),
												IconButton(
													icon: const Icon(Icons.delete),
													onPressed: () => context.read<HabitsCubit>().deleteHabit(h.id!),
												),
											],
										),
									);
								},
							);
						},
					),
					floatingActionButton: Builder(
						builder: (innerContext) {
							return FloatingActionButton.extended(
								onPressed: () async {
									final result = await _promptHabit(innerContext);
									if (result != null) {
										try {
											await innerContext.read<HabitsCubit>().addHabit(result.$1, int.parse(result.$2));
											ScaffoldMessenger.of(innerContext).showSnackBar(const SnackBar(content: Text('تمت إضافة العادة')));
										} catch (e) {
											print(e); 
										}
									}
								},
								label: const Text('إضافة عادة'),
								icon: const Icon(Icons.add),
							);
						},
					),
				),
			),
		);
	}

	Future<(String, String)?> _promptHabit(BuildContext context, {String? name, String? points}) async {
		final nameController = TextEditingController(text: name ?? '');
		final pointsController = TextEditingController(text: points ?? '1');
		return showDialog<(String, String)>(
			context: context,
			builder: (context) => AlertDialog(
				title: const Text('العادة'),
				content: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						TextField(controller: nameController, decoration: const InputDecoration(labelText: 'الاسم'), textDirection: TextDirection.rtl),
						TextField(controller: pointsController, decoration: const InputDecoration(labelText: 'النقاط'), keyboardType: TextInputType.number, textDirection: TextDirection.rtl),
					],
				),
				actions: [
					TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
					TextButton(onPressed: () => Navigator.pop(context, (nameController.text, pointsController.text)), child: const Text('حفظ')),
				],
			),
		);
	}
}


