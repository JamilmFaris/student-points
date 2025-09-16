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

class _TrackingTable extends StatefulWidget {
	const _TrackingTable();

	@override
	State<_TrackingTable> createState() => _TrackingTableState();
}

class _TrackingTableState extends State<_TrackingTable> {
	static const double _leftColumnWidth = 140;
	static const double _totalColumnWidth = 80;
	static const double _habitColumnWidth = 115;

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
		WidgetsBinding.instance.addPostFrameCallback((_) {
			final messenger = ScaffoldMessenger.of(context);
			messenger.clearSnackBars();
			messenger.showSnackBar(const SnackBar(
				content: Text('لزيادة النقاط: كل ضغطة تزيد بعدد نقاط العادة (مرتين = 2×النقاط).'),
				duration: Duration(seconds: 6),
			));
		});
	}

	@override
	void dispose() {
		_horizontalBodyController.dispose();
		_horizontalHeaderController.dispose();
		_verticalBodyController.dispose();
		_verticalLeftController.dispose();
		super.dispose();
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
										Expanded(
											child: SingleChildScrollView(
												controller: _horizontalHeaderController,
												physics: const NeverScrollableScrollPhysics(),
												scrollDirection: Axis.horizontal,
												child: Row(
													children: [
														_headerCell(const Text('المجموع'), width: _totalColumnWidth, backgroundColor: scheme.secondaryContainer),
														for (final h in habits)
															_headerCell(Center(child: Text(h.name)), width: _habitColumnWidth, backgroundColor: scheme.primaryContainer),
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
															_cell(Align(
																alignment: Alignment.center,
																child: Padding(
																	padding: const EdgeInsets.symmetric(horizontal: 8),
																	child: Text(students[i].name),
																),
															), width: _leftColumnWidth, backgroundColor: _zebraColor(i)),
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
																			_cell(Builder(builder: (context) {
																				final student = students[i];
																				final counts = tState.countsByStudentHabit[student.id] ?? {};
																				int total = 0;
																				for (final h in habits) {
																					final c = counts[h.id] ?? 0;
																					total += c * h.points;
																				}
																				return Text('$total', style: const TextStyle(fontWeight: FontWeight.w600));
																			}), width: _totalColumnWidth, backgroundColor: scheme.secondaryContainer),
																			for (final h in habits)
																				Builder(builder: (context) {
																					final counts = tState.countsByStudentHabit[students[i].id] ?? {};
																					final c = counts[h.id] ?? 0;
																					if (h.oncePerDay && !h.allowNegative) {
																						return _cell(
																							Checkbox(
																								value: c > 0,
																								onChanged: (v) {
																									if (v == true && c <= 0) {
																										context.read<TrackingCubit>().increment(students[i].id!, h.id!);
																									} else if (v == false && c > 0) {
																										context.read<TrackingCubit>().decrement(students[i].id!, h.id!);
																									}
																								},
																							),
																							width: _habitColumnWidth,
																							backgroundColor: c > 0 ? scheme.primary.withOpacity(0.08) : _zebraColor(i),
																						);
																					}
																					return _cell(
																						Row(
																							mainAxisSize: MainAxisSize.min,
																							children: [
																								if (h.allowNegative)
																									IconButton(
																										icon: const Icon(Icons.remove),
																										color: scheme.error,
																										onPressed: () => context.read<TrackingCubit>().decrement(students[i].id!, h.id!),
																									),
																								Builder(builder: (context) {
																									final counts = tState.countsByStudentHabit[students[i].id] ?? {};
																									final c = counts[h.id] ?? 0;
																									final displayed = h.oncePerDay ? (c > 0 ? 1 : (h.allowNegative ? (c < 0 ? -1 : 0) : (c > 0 ? 1 : 0))) : c;
																									return Text('$displayed', style: const TextStyle(fontWeight: FontWeight.w500));
																								}),
																								IconButton(
																									icon: const Icon(Icons.add),
																									color: scheme.primary,
																									onPressed: () {
																										final counts = tState.countsByStudentHabit[students[i].id] ?? {};
																										final c = counts[h.id] ?? 0;
																										if (h.oncePerDay && c >= 1) return;
																										context.read<TrackingCubit>().increment(students[i].id!, h.id!);
																									},
																								),
																							],
																						),
																						width: _habitColumnWidth,
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


