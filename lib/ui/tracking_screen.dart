import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bloc/habits_cubit.dart';
import '../bloc/students_cubit.dart';
import '../bloc/tracking_cubit.dart';
import '../repositories/habit_repository.dart';
import '../repositories/student_repository.dart';
import '../repositories/tracking_repository.dart';
import '../models/habit.dart';
import '../services/app_mode.dart';

import 'widgets/app_drawer.dart';

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
					appBar: AppBar(title: const _LessonAppBarTitle()),
					drawer: const AppDrawer(),
					body: SafeArea(top: false, left: false, right: false, bottom: true, child: const _TrackingTable()),
					floatingActionButton: Builder(
						builder: (context) {
							return FloatingActionButton.extended(
								onPressed: () async {
									await context.read<TrackingCubit>().saveAll();
									ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ التعديلات')));
								},
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

class _LessonAppBarTitle extends StatelessWidget {
	const _LessonAppBarTitle();

	@override
	Widget build(BuildContext context) {
		return BlocBuilder<TrackingCubit, TrackingState>(
			buildWhen: (a, b) => a.lesson?.subject != b.lesson?.subject || a.date != b.date,
			builder: (context, state) {
				final subject = (state.lesson?.subject ?? '').trim();
				final dateStr = state.date.toIso8601String().substring(0, 10);
				final title = subject.isEmpty ? 'تتبع النقاط ($dateStr)' : 'درس: $subject';
				return Row(
					mainAxisSize: MainAxisSize.min,
					children: [
						Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
						IconButton(
							tooltip: 'تعديل عنوان الدرس',
							icon: const Icon(Icons.edit),
							onPressed: () => _editSubject(context, subject),
						),
					],
				);
			},
		);
	}

	Future<void> _editSubject(BuildContext context, String current) async {
		final controller = TextEditingController(text: current);
		final result = await showDialog<String>(
			context: context,
			builder: (ctx) => Directionality(
				textDirection: TextDirection.rtl,
				child: AlertDialog(
					title: const Text('عنوان الدرس'),
					content: TextField(
						controller: controller,
						autofocus: true,
						decoration: const InputDecoration(labelText: 'مثال: درس الفقه'),
					),
					actions: [
						TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
						FilledButton(
							onPressed: () => Navigator.pop(ctx, controller.text.trim()),
							child: const Text('حفظ'),
						),
					],
				),
			),
		);
		controller.dispose();
		if (result == null) return;
		if (!context.mounted) return;
		await context.read<TrackingCubit>().setLessonSubject(result);
	}
}

class _TrackingTable extends StatefulWidget {
	const _TrackingTable();

	@override
	State<_TrackingTable> createState() => _TrackingTableState();
}

class _TrackingTableState extends State<_TrackingTable> {
	static const double _leftColumnWidth = 140;
	static const double _totalColumnWidth = 55;
	// Adaptive widths
	static const double _checkboxColumnWidth = 64; // once per day, no negative (Checkbox only)
	static const double _plusMinusColumnWidth = 128; // - number +

	double _widthForHabit(Habit h) {
		if (h.oncePerDay && !h.allowNegative) return _checkboxColumnWidth;
		return _plusMinusColumnWidth;
	}

	static const double _rowHeight = 56;
	static const double _headerHeight = 56;

	final ScrollController _horizontalBodyController = ScrollController();
	final ScrollController _horizontalHeaderController = ScrollController();
	final ScrollController _verticalBodyController = ScrollController();
	final ScrollController _verticalLeftController = ScrollController();

	@override
	void initState() {
		super.initState();
		_horizontalBodyController.addListener(() {
			if (_horizontalHeaderController.hasClients &&
				_horizontalHeaderController.offset != _horizontalBodyController.offset) {
				_horizontalHeaderController.jumpTo(_horizontalBodyController.offset);
			}
		});
		_verticalBodyController.addListener(() {
			if (_verticalLeftController.hasClients &&
				_verticalLeftController.offset != _verticalBodyController.offset) {
				_verticalLeftController.jumpTo(_verticalBodyController.offset);
			}
		});
		// Show reminder dialog after first frame, then force the user to pick
		// an attendance habit if no حضور habit exists.
		WidgetsBinding.instance.addPostFrameCallback((_) async {
			await _showReminderIfNeeded(context);
			if (!context.mounted) return;
			await _ensureAttendanceHabit(context);
		});
	}

	Future<void> _ensureAttendanceHabit(BuildContext context) async {
		// Wait until habits load (HabitsCubit emits a non-empty list).
		final cubit = context.read<HabitsCubit>();
		List<Habit> habits = cubit.state.habits;
		if (habits.isEmpty) {
			// One-shot await: subscribe briefly until first non-empty load.
			await cubit.stream
				.firstWhere((s) => !s.loading)
				.timeout(const Duration(seconds: 5), onTimeout: () => cubit.state);
			habits = cubit.state.habits;
		}
		if (habits.isEmpty) return; // No habits at all — nothing to force.
		final resolved = await AppMode.resolveAttendanceHabit(habits);
		if (resolved != null) return;
		if (!context.mounted) return;
		final picked = await _showAttendancePicker(context, habits);
		if (picked != null) {
			await AppMode.setAttendanceHabitOverride(picked.id);
			return;
		}
		// User dismissed without picking — back out of tracking.
		if (!context.mounted) return;
		Navigator.of(context).maybePop();
	}

	Future<Habit?> _showAttendancePicker(BuildContext context, List<Habit> habits) async {
		return showDialog<Habit>(
			context: context,
			barrierDismissible: false,
			builder: (ctx) => Directionality(
				textDirection: TextDirection.rtl,
				child: AlertDialog(
					title: const Text('اختر العادة الخاصة بالحضور'),
					content: SizedBox(
						width: double.maxFinite,
						child: Column(
							mainAxisSize: MainAxisSize.min,
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								const Text(
									'لا توجد عادة باسم "حضور". اختر عادة لتُستخدم كمؤشر للحضور — '
									'إعطاء الطالب نقاط موجبة على هذه العادة يعني أنه حضر اليوم.',
									style: TextStyle(fontSize: 13),
								),
								const SizedBox(height: 12),
								Flexible(
									child: ListView.builder(
										shrinkWrap: true,
										itemCount: habits.length,
										itemBuilder: (_, i) => ListTile(
											title: Text(habits[i].name),
											onTap: () => Navigator.pop(ctx, habits[i]),
										),
									),
								),
							],
						),
					),
					actions: [
						TextButton(
							onPressed: () => Navigator.pop(ctx),
							child: const Text('إلغاء'),
						),
					],
				),
			),
		);
	}

	@override
	void dispose() {
		_horizontalBodyController.dispose();
		_horizontalHeaderController.dispose();
		_verticalBodyController.dispose();
		_verticalLeftController.dispose();
		super.dispose();
	}

	Future<void> _showReminderIfNeeded(BuildContext context) async {
		final prefs = await SharedPreferences.getInstance();
		final reminderPref = prefs.getString('tracking_save_reminder');
		
		// If preference is 'dont_show', don't show the reminder
		if (reminderPref == 'dont_show') return;
		
		// Show reminder if preference is 'show_always' or if it doesn't exist (first time)
		if (reminderPref == null || reminderPref == 'show_always') {
			if (!context.mounted) return;
			await _showSaveReminderDialog(context);
		}
	}

	Future<void> _showSaveReminderDialog(BuildContext context) async {
		final prefs = await SharedPreferences.getInstance();
		await showDialog(
			context: context,
			barrierDismissible: false,
			builder: (ctx) => Directionality(
				textDirection: TextDirection.rtl,
				child: AlertDialog(
					title: const Text('تذكير'),
					content: const Text('لا تنسَ الضغط على زر "حفظ" بعد الانتهاء من تتبع النقاط لحفظ التعديلات.'),
					actions: [
						TextButton(
							onPressed: () async {
								await prefs.setString('tracking_save_reminder', 'show_always');
								if (!ctx.mounted) return;
								Navigator.pop(ctx);
							},
							child: const Text('نعم، فهمت'),
						),
						TextButton(
							onPressed: () async {
								await prefs.setString('tracking_save_reminder', 'dont_show');
								if (!ctx.mounted) return;
								Navigator.pop(ctx);
							},
							child: const Text('نعم فهمت ولا تذكرني في المرة القادمة'),
						),
					],
				),
			),
		);
	}

	Color _zebraColor(int rowIndex) {
		final scheme = Theme.of(context).colorScheme;
		return rowIndex.isEven ? scheme.surface : scheme.surfaceVariant.withOpacity(0.35);
	}

	Widget _headerCell(Widget child, {double? width, Color? backgroundColor}) {
		return Container(
			alignment: Alignment.center,
			width: width,
			height: _headerHeight,
			decoration: BoxDecoration(
				color: backgroundColor ?? Theme.of(context).colorScheme.primaryContainer,
				border: Border(
					right: BorderSide(color: Colors.grey.shade300),
					bottom: BorderSide(color: Colors.grey.shade300),
				),
			),
			child: DefaultTextStyle.merge(
				style: TextStyle(
					fontWeight: FontWeight.w600,
					color: Theme.of(context).colorScheme.onPrimaryContainer,
				),
				child: child,
			),
		);
	}

	Widget _cell(Widget child, {double? width, Color? backgroundColor}) {
		return Container(
			alignment: Alignment.center,
			width: width,
			height: _rowHeight,
			decoration: BoxDecoration(
				color: backgroundColor,
				border: Border(
					right: BorderSide(color: Colors.grey.shade300),
					bottom: BorderSide(color: Colors.grey.shade300),
				),
			),
			child: child,
		);
	}

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

					final scheme = Theme.of(context).colorScheme;
					return Padding(
						padding: const EdgeInsets.only(bottom: 80),
						child: Column(
							children: [
								Row(
									children: [
										_headerCell(const Text('الطالب'), width: _leftColumnWidth, backgroundColor: scheme.primaryContainer),
										_headerCell(const Text('المجموع'), width: _totalColumnWidth, backgroundColor: scheme.secondaryContainer),
										Expanded(
											child: SingleChildScrollView(
												controller: _horizontalHeaderController,
												physics: const NeverScrollableScrollPhysics(),
												scrollDirection: Axis.horizontal,
												child: Row(
													children: [
														for (final h in habits)
															_headerCell(Center(child: Text(h.name)), width: _widthForHabit(h), backgroundColor: scheme.primaryContainer),
													],
												),
											),
										),
									],
								),
								Expanded(
									child: Row(
										children: [
											SingleChildScrollView(
												controller: _verticalLeftController,
												physics: const NeverScrollableScrollPhysics(),
												child: Column(
													children: [
														for (int i = 0; i < students.length; i++)
															Row(children: [
																_cell(Align(
																	alignment: Alignment.center,
																	child: Padding(
																		padding: const EdgeInsets.symmetric(horizontal: 8),
																		child: Text(students[i].name),
																	),
																), width: _leftColumnWidth, backgroundColor: _zebraColor(i)),
																_cell(Builder(builder: (context) {
																	final student = students[i];
																	final counts = tState.countsByStudentHabit[student.id] ?? {};
																	int total = 0;
																	for (final h in habits) {
																		final c = counts[h.id] ?? 0;
																		total += c;
																	}
																	return Text('$total', style: const TextStyle(fontWeight: FontWeight.w600));
																}), width: _totalColumnWidth, backgroundColor: scheme.secondaryContainer),
															]),
													],
												),
											),
											Expanded(
												child: SingleChildScrollView(
													controller: _verticalBodyController,
													scrollDirection: Axis.vertical,
													child: SingleChildScrollView(
														controller: _horizontalBodyController,
														scrollDirection: Axis.horizontal,
														child: Column(
															children: [
																for (int i = 0; i < students.length; i++)
																	Row(
																		children: [
																			for (final h in habits)
																				Builder(builder: (context) {
																					final counts = tState.countsByStudentHabit[students[i].id] ?? {};
																					final c = counts[h.id] ?? 0;
																					
																					// Handle once per day habits (both with and without negative values)
																					if (h.oncePerDay) {
																						if (!h.allowNegative) {
																							// Simple checkbox for once per day without negative
																							return _cell(
																								Checkbox(
																									value: c > 0,
																									onChanged: (v) {
																										if (v == true && c <= 0) {
																											context.read<TrackingCubit>().setHabitValue(students[i].id!, h.id!, h.points);
																										} else if (v == false && c > 0) {
																											context.read<TrackingCubit>().setHabitValue(students[i].id!, h.id!, 0);
																										}
																									},
																								),
																								width: _widthForHabit(h),
																								backgroundColor: c > 0 ? scheme.primary.withOpacity(0.08) : (c < 0 ? scheme.error.withOpacity(0.07) : _zebraColor(i)),
																							);
																						} else {
																							// Once per day with negative: cycle through 0 → +points → -points → 0
																							return _cell(
																								Row(
																									mainAxisSize: MainAxisSize.min,
																									children: [
																										IconButton(
																											icon: const Icon(Icons.remove),
																											color: scheme.error,
																										onPressed: () {
																											int newVal = c - h.decreasePoints;
																											if (newVal < -h.decreasePoints) newVal = -h.decreasePoints;
																											if (newVal > h.points) newVal = h.points;
																											context.read<TrackingCubit>().setHabitValue(students[i].id!, h.id!, newVal);
																										},
																										),
																										Text('$c', style: const TextStyle(fontWeight: FontWeight.w500)),
																										IconButton(
																											icon: const Icon(Icons.add),
																											color: scheme.primary,
																										onPressed: () {
																											int newVal = c + h.points;
																											if (newVal > h.points) newVal = h.points;
																											if (newVal < -h.decreasePoints) newVal = -h.decreasePoints;
																											context.read<TrackingCubit>().setHabitValue(students[i].id!, h.id!, newVal);
																										},
																										),
																									],
																								),
																								width: _widthForHabit(h),
																								backgroundColor: (() {
																									if (c > 0) return scheme.primary.withOpacity(0.08);
																									if (c < 0) return scheme.error.withOpacity(0.07);
																									return _zebraColor(i);
																								})(),
																							);
																						}
																					}
																					
																					// Handle multiple times per day habits (normal increment/decrement)
																					int displayedPoints = c;
																					return _cell(
																						Row(
																							mainAxisSize: MainAxisSize.min,
																							children: [
																								IconButton(
																									icon: const Icon(Icons.remove),
																									color: scheme.error,
																									onPressed: () => context.read<TrackingCubit>().decrement(students[i].id!, h.id!, h.decreasePoints),
																								),
																								Text('$displayedPoints', style: const TextStyle(fontWeight: FontWeight.w500)),
																								IconButton(
																									icon: const Icon(Icons.add),
																									color: scheme.primary,
																								onPressed: () {
																									context.read<TrackingCubit>().increment(students[i].id!, h.id!, h.points);
																								},
																								),
																							],
																						),
																						width: _widthForHabit(h),
																						backgroundColor: (() {
																							final counts = tState.countsByStudentHabit[students[i].id] ?? {};
																							final c = counts[h.id] ?? 0;
																							if (c > 0) return scheme.primary.withOpacity(0.08);
																							if (c < 0) return scheme.error.withOpacity(0.07);
																							return _zebraColor(i);
																						})(),
																					);
																				}),
																		],
																	),
															],
														),
													),
												),
											),
										],
									),
								),
							],
						),
					);
				});
			});
		});
	}
}


