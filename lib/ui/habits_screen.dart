import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';

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
														final result = await _promptHabit(context, name: h.name, points: h.points.toString(), allowNegative: h.allowNegative);
														if (result != null) {
															try {
																await context.read<HabitsCubit>().updateHabit(
																	h.copyWith(name: result.$1, points: int.parse(result.$2), allowNegative: result.$3),
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
									await _addHabitsFlow(innerContext);
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

	Future<(String, String, bool)?> _promptHabit(BuildContext context, {String? name, String? points, bool? allowNegative}) async {
		final nameController = TextEditingController(text: name ?? '');
		final pointsController = TextEditingController(text: points ?? '1');
		bool allowNegativeValue = allowNegative ?? false;
		final nameFocusNode = FocusNode();
		return showDialog<(String, String, bool)>(
			context: context,
			builder: (context) {
				WidgetsBinding.instance.addPostFrameCallback((_) {
					FocusScope.of(context).requestFocus(nameFocusNode);
				});
				return AlertDialog(
					scrollable: true,
					title: const Text('العادة'),
					content: StatefulBuilder(
						builder: (context, setState) {
							return Padding(
								padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
								child: SingleChildScrollView(
									child: Column(
										mainAxisSize: MainAxisSize.min,
										children: [
											TextField(
												controller: nameController, 
												decoration: const InputDecoration(labelText: 'الاسم'), 
												textDirection: TextDirection.rtl,
												autofocus: true,
												focusNode: nameFocusNode,
											),
											TextField(
												controller: pointsController,
												decoration: const InputDecoration(labelText: 'النقاط'),
												keyboardType: TextInputType.number,
												textDirection: TextDirection.ltr,
												textAlign: TextAlign.left,
												inputFormatters: [FilteringTextInputFormatter.digitsOnly],
											),
											const SizedBox(height: 8),
											Align(
												alignment: Alignment.centerRight,
												child: Text('نوع العادة', style: Theme.of(context).textTheme.bodyMedium),
											),
											RadioListTile<bool>(
												contentPadding: EdgeInsets.zero,
												title: const Text('إضافة فقط'),
												subtitle: const Text('لا يمكن الطرح (قيم سالبة)'),
												value: false,
												groupValue: allowNegativeValue,
												onChanged: (v) => setState(() => allowNegativeValue = v ?? false),
											),
											RadioListTile<bool>(
												contentPadding: EdgeInsets.zero,
												title: const Text('السماح بالطرح'),
												subtitle: const Text('يمكن زيادة أو إنقاص'),
												value: true,
												groupValue: allowNegativeValue,
												onChanged: (v) => setState(() => allowNegativeValue = v ?? false),
											),
										],
									),
								),
							);
						},
					),
					actions: [
						TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
						TextButton(onPressed: () => Navigator.pop(context, (nameController.text, pointsController.text, allowNegativeValue)), child: const Text('حفظ')),
					],
				);
			},
		);
	}

	Future<void> _addHabitsFlow(BuildContext context) async {
		while (true) {
			final result = await _promptHabitForAdd(context);
			if (result == null) return;
			final String name = result.name.trim();
			final int points = int.tryParse(result.points) ?? 1;
			if (name.isNotEmpty) {
				await context.read<HabitsCubit>().addHabit(name, points, allowNegative: result.allowNegative);
				ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة العادة')));
			}
			if (!result.addAnother) return;
		}
	}

	Future<_HabitAddDialogResult?> _promptHabitForAdd(BuildContext context) async {
		final nameController = TextEditingController(text: '');
		final pointsController = TextEditingController(text: '1');
		final nameFocusNode = FocusNode();
		bool allowNegativeValue = false;
		return showDialog<_HabitAddDialogResult>(
			context: context,
			builder: (context) {
				WidgetsBinding.instance.addPostFrameCallback((_) {
					FocusScope.of(context).requestFocus(nameFocusNode);
				});
				return AlertDialog(
					scrollable: true,
					title: const Text('العادة'),
					content: StatefulBuilder(
						builder: (context, setState) {
							return Padding(
								padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
								child: SingleChildScrollView(
									child: Column(
										mainAxisSize: MainAxisSize.min,
										children: [
											TextField(
												controller: nameController,
												decoration: const InputDecoration(labelText: 'الاسم'),
												textDirection: TextDirection.rtl,
												autofocus: true,
												focusNode: nameFocusNode,
											),
											TextField(
												controller: pointsController,
												decoration: const InputDecoration(labelText: 'النقاط'),
												keyboardType: TextInputType.number,
												textDirection: TextDirection.ltr,
												textAlign: TextAlign.left,
												inputFormatters: [FilteringTextInputFormatter.digitsOnly],
											),
											const SizedBox(height: 8),
											Align(
												alignment: Alignment.centerRight,
												child: Text('نوع العادة', style: Theme.of(context).textTheme.bodyMedium),
											),
											RadioListTile<bool>(
												contentPadding: EdgeInsets.zero,
												title: const Text('إضافة فقط'),
												subtitle: const Text('لا يمكن الطرح (قيم سالبة)'),
												value: false,
												groupValue: allowNegativeValue,
												onChanged: (v) => setState(() => allowNegativeValue = v ?? false),
											),
											RadioListTile<bool>(
												contentPadding: EdgeInsets.zero,
												title: const Text('السماح بالطرح'),
												subtitle: const Text('يمكن زيادة أو إنقاص'),
												value: true,
												groupValue: allowNegativeValue,
												onChanged: (v) => setState(() => allowNegativeValue = v ?? false),
											),
										],
									),
								),
							);
						},
					),
					actions: [
						TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
						TextButton(
							onPressed: () => Navigator.pop(context, _HabitAddDialogResult(nameController.text, pointsController.text, allowNegativeValue, false)),
							child: const Text('حفظ'),
						),
						TextButton(
							onPressed: () => Navigator.pop(context, _HabitAddDialogResult(nameController.text, pointsController.text, allowNegativeValue, true)),
							child: const Text('حفظ وإضافة آخر'),
						),
					],
				);
			},
		);
	}
}

class _HabitAddDialogResult {
	final String name;
	final String points;
	final bool allowNegative;
	final bool addAnother;

	_HabitAddDialogResult(this.name, this.points, this.allowNegative, this.addAnother);
}


