import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/students_cubit.dart';
import '../models/student.dart';
import '../repositories/tracking_repository.dart';
import '../repositories/habit_repository.dart';
import '../models/habit.dart';
import 'widgets/habit_progress_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

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
                                        onTap: () => _showStudentInfo(context, s),
									trailing: Row(
											mainAxisSize: MainAxisSize.min,
											children: [
												ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle)),
											if (s.phoneNumber != null && s.phoneNumber!.trim().isNotEmpty)
												IconButton(
													icon: const Icon(Icons.phone),
													onPressed: () async {
														final uri = Uri(scheme: 'tel', path: s.phoneNumber!.trim());
														try {
															await launchUrl(uri, mode: LaunchMode.externalApplication);
														} catch (e) {
															ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح تطبيق الاتصال')));
														}
													},
												),
                                        IconButton(
											icon: const Icon(Icons.edit),
											onPressed: () async {
												final details = await _promptStudentDetails(
													context,
													name: s.name,
													dateOfBirth: s.dateOfBirth,
													schoolName: s.schoolName,
													fatherName: s.fatherName,
													motherName: s.motherName,
													phoneNumber: s.phoneNumber,
                                                    birthPlace: s.birthPlace,
                                                    grade: s.grade,
												);
												if (details != null) {
													context.read<StudentsCubit>().updateStudent(
														s.copyWith(
															name: details.name.trim(),
															dateOfBirth: details.dateOfBirth.trim().isEmpty ? null : details.dateOfBirth.trim(),
															schoolName: details.schoolName.trim().isEmpty ? null : details.schoolName.trim(),
															fatherName: details.fatherName.trim().isEmpty ? null : details.fatherName.trim(),
															motherName: details.motherName.trim().isEmpty ? null : details.motherName.trim(),
															phoneNumber: details.phoneNumber.trim().isEmpty ? null : details.phoneNumber.trim(),
                                                            birthPlace: details.birthPlace.trim().isEmpty ? null : details.birthPlace.trim(),
                                                            grade: details.grade.trim().isEmpty ? null : details.grade.trim(),
														),
													);
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

// moved to top-level below

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

class _StudentDetailsResult {
	final String name;
	final String dateOfBirth;
	final String schoolName;
	final String fatherName;
	final String motherName;
	final String phoneNumber;
	final String birthPlace;
    final String grade;

    _StudentDetailsResult(this.name, this.dateOfBirth, this.schoolName, this.fatherName, this.motherName, this.phoneNumber, this.birthPlace, this.grade);
}

void _showStudentInfo(BuildContext context, Student s) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) {
            return Directionality(
                textDirection: TextDirection.rtl,
                child: SafeArea(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                    Row(
                                        children: [
                                            Expanded(child: Text(s.name, style: Theme.of(ctx).textTheme.titleLarge)),
                                            IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                                        ],
                                    ),
                                    const SizedBox(height: 8),
                                    _infoRow(ctx, 'تاريخ الميلاد', s.dateOfBirth),
                                    _infoRow(ctx, 'اسم المدرسة', s.schoolName),
                                    _infoRow(ctx, 'اسم الأب', s.fatherName),
                                    _infoRow(ctx, 'اسم الأم', s.motherName),
                                    _infoRow(ctx, 'مكان الولادة', s.birthPlace),
                                    _infoRow(ctx, 'الصف', s.grade),
                                    _infoRow(ctx, 'رقم الهاتف', s.phoneNumber),
                                    const SizedBox(height: 12),
                                    Row(
                                        children: [
                                            if ((s.phoneNumber ?? '').trim().isNotEmpty)
                                                ElevatedButton.icon(
                                                    onPressed: () async {
                                                        final uri = Uri(scheme: 'tel', path: s.phoneNumber!.trim());
                                                        try {
                                                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                                                        } catch (_) {
                                                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('تعذر فتح تطبيق الاتصال')));
                                                        }
                                                    },
                                                    icon: const Icon(Icons.phone),
                                                    label: const Text('اتصال'),
                                                ),
                                            const SizedBox(width: 8),
                                            OutlinedButton.icon(
                                                onPressed: () async {
                                                    Navigator.pop(ctx);
                                                    // Open edit dialog prefilled
                                                    final details = await _promptStudentDetails(
                                                        context,
                                                        name: s.name,
                                                        dateOfBirth: s.dateOfBirth,
                                                        schoolName: s.schoolName,
                                                        fatherName: s.fatherName,
                                                        motherName: s.motherName,
                                                        phoneNumber: s.phoneNumber,
                                                        birthPlace: s.birthPlace,
                                                        grade: s.grade,
                                                    );
                                                    if (details != null) {
                                                        // ignore: use_build_context_synchronously
                                                        context.read<StudentsCubit>().updateStudent(
                                                            s.copyWith(
                                                                name: details.name.trim(),
                                                                dateOfBirth: details.dateOfBirth.trim().isEmpty ? null : details.dateOfBirth.trim(),
                                                                schoolName: details.schoolName.trim().isEmpty ? null : details.schoolName.trim(),
                                                                fatherName: details.fatherName.trim().isEmpty ? null : details.fatherName.trim(),
                                                                motherName: details.motherName.trim().isEmpty ? null : details.motherName.trim(),
                                                                phoneNumber: details.phoneNumber.trim().isEmpty ? null : details.phoneNumber.trim(),
                                                                birthPlace: details.birthPlace.trim().isEmpty ? null : details.birthPlace.trim(),
                                                                grade: details.grade.trim().isEmpty ? null : details.grade.trim(),
                                                            ),
                                                        );
                                                    }
                                                },
                                                icon: const Icon(Icons.edit),
                                                label: const Text('تعديل'),
                                            ),
                                        ],
                                    ),
                                ],
                            ),
                        ),
                    ),
                ),
            );
        },
    );
}

Widget _infoRow(BuildContext context, String label, String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return const SizedBox.shrink();
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                SizedBox(width: 110, child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
                const SizedBox(width: 12),
                Expanded(child: Text(v, textDirection: label == 'تاريخ الميلاد' || label == 'رقم الهاتف' ? TextDirection.ltr : TextDirection.rtl, textAlign: TextAlign.start)),
            ],
        ),
    );
}

Future<_StudentDetailsResult?> _promptStudentDetails(BuildContext context, {String? name, String? dateOfBirth, String? schoolName, String? fatherName, String? motherName, String? phoneNumber, String? birthPlace, String? grade}) async {
    final nameController = TextEditingController(text: name ?? '');
    final dobController = TextEditingController(text: dateOfBirth ?? '');
    final schoolController = TextEditingController(text: schoolName ?? '');
    final fatherController = TextEditingController(text: fatherName ?? '');
    final motherController = TextEditingController(text: motherName ?? '');
    final phoneController = TextEditingController(text: phoneNumber ?? '');
    final birthPlaceController = TextEditingController(text: birthPlace ?? '');
    final gradeController = TextEditingController(text: grade ?? '');
    Future<void> pickDob() async {
        DateTime? initial;
        try {
            if ((dobController.text).trim().isNotEmpty) {
                initial = DateTime.tryParse(dobController.text.trim());
            }
        } catch (_) {}
        final now = DateTime.now();
        final first = DateTime(1990, 1, 1);
        final init = initial == null
            ? DateTime(now.year - 10, now.month, now.day)
            : (initial.isBefore(first) ? first : (initial.isAfter(now) ? now : initial));
        final picked = await showDatePicker(
            context: context,
            firstDate: first,
            lastDate: now,
            initialDate: init ?? now,
        );
        if (picked != null) {
            dobController.text = picked.toIso8601String().substring(0, 10);
        }
    }
    return showDialog<_StudentDetailsResult>(
        context: context,
        builder: (context) {
            return AlertDialog(
                scrollable: true,
                title: const Text('بيانات الطالب'),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        TextField(controller: nameController, decoration: const InputDecoration(labelText: 'الاسم'), textDirection: TextDirection.rtl),
                        TextField(
                            controller: dobController,
                            decoration: InputDecoration(
                                labelText: 'تاريخ الميلاد',
                                suffixIcon: IconButton(icon: const Icon(Icons.calendar_today), onPressed: pickDob),
                            ),
                            readOnly: true,
                            onTap: pickDob,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.left,
                        ),
                        TextField(controller: schoolController, decoration: const InputDecoration(labelText: 'اسم المدرسة'), textDirection: TextDirection.rtl),
                        TextField(controller: fatherController, decoration: const InputDecoration(labelText: 'اسم الأب'), textDirection: TextDirection.rtl),
                        TextField(controller: motherController, decoration: const InputDecoration(labelText: 'اسم الأم'), textDirection: TextDirection.rtl),
                        TextField(
                            controller: phoneController,
                            decoration: InputDecoration(
                                labelText: 'رقم الهاتف',
                                suffixIcon: IconButton(
                                    icon: const Icon(Icons.contacts),
                                    onPressed: () async {
                                        try {
                                            if (!await FlutterContacts.requestPermission(readonly: true)) return;
                                            final contact = await FlutterContacts.openExternalPick();
                                            if (contact == null) return;
                                            // To get numbers, refetch with properties
                                            final full = await FlutterContacts.getContact(contact.id, withProperties: true);
                                            final number = (full?.phones.isNotEmpty ?? false) ? full!.phones.first.number : '';
                                            if (number.trim().isNotEmpty) {
                                                phoneController.text = number.trim();
                                            }
                                        } catch (_) {}
                                    },
                                ),
                            ),
                            keyboardType: TextInputType.phone,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.left,
                        ),
                        TextField(controller: birthPlaceController, decoration: const InputDecoration(labelText: 'مكان الولادة'), textDirection: TextDirection.rtl),
                        TextField(controller: gradeController, decoration: const InputDecoration(labelText: 'الصف'), textDirection: TextDirection.rtl),
                    ],
                ),
                actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
                    TextButton(onPressed: () => Navigator.pop(context, _StudentDetailsResult(
                        nameController.text,
                        dobController.text,
                        schoolController.text,
                        fatherController.text,
                        motherController.text,
                        phoneController.text,
                        birthPlaceController.text,
                        gradeController.text,
                    )), child: const Text('حفظ')),
                ],
            );
        },
    );
}


