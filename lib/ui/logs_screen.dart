import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/logs_cubit.dart';
import '../bloc/students_cubit.dart';
import '../models/habit.dart';
import '../models/student.dart';
import '../repositories/habit_repository.dart';
import '../repositories/student_repository.dart';
import '../repositories/tracking_repository.dart';

class LogsScreen extends StatelessWidget {
	const LogsScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Directionality(
			textDirection: TextDirection.rtl,
			child: MultiBlocProvider(
				providers: [
					BlocProvider(create: (_) => LogsCubit(TrackingRepository())),
					BlocProvider(create: (_) => StudentsCubit(StudentRepository())),
				],
				child: DefaultTabController(
					length: 3,
					child: Scaffold(
						appBar: AppBar(
							title: const Text('سجل النقاط'),
							bottom: const TabBar(tabs: [
								Tab(text: 'يومي'),
								Tab(text: 'شهري'),
								Tab(text: 'سنوي'),
							]),
						),
						body: const TabBarView(children: [
							_DailyTab(),
							_MonthlyTab(),
							_YearlyTab(),
						]),
					),
				),
			),
		);
	}
}

class _DailyTab extends StatelessWidget {
	const _DailyTab();

	@override
	Widget build(BuildContext context) {
		return BlocBuilder<LogsCubit, LogsState>(builder: (context, state) {
			final logsCubit = context.read<LogsCubit>();
			return Column(children: [
				Expanded(
					child: ListView.builder(
						itemCount: state.dates.length,
						itemBuilder: (context, index) {
							final d = state.dates[index];
							return ListTile(
								title: Text(d),
								onTap: () => logsCubit.loadDaily(DateTime.parse(d)),
								trailing: IconButton(
									icon: const Icon(Icons.table_chart),
									onPressed: () async {
									final date = DateTime.parse(d);
									await logsCubit.loadDaily(date);
									showDialog(
										context: context,
										builder: (_) => _DayBreakdownDialog(date: date),
									);
								},
								),
							);
						},
					),
				),
				Expanded(child: _TotalsList(map: state.dailyTotals)),
			]);
		});
	}
}

class _MonthlyTab extends StatefulWidget {
	const _MonthlyTab();
	@override
	State<_MonthlyTab> createState() => _MonthlyTabState();
}

class _MonthlyTabState extends State<_MonthlyTab> {
	int year = DateTime.now().year;
	int month = DateTime.now().month;

	@override
	Widget build(BuildContext context) {
		return Column(children: [
			Row(children: [
				IconButton(onPressed: () => setState(() => year--), icon: const Icon(Icons.chevron_right)),
				Text('السنة: $year'),
				IconButton(onPressed: () => setState(() => year++), icon: const Icon(Icons.chevron_left)),
				const SizedBox(width: 12),
				IconButton(onPressed: () => setState(() => month = month > 1 ? month - 1 : 12), icon: const Icon(Icons.chevron_right)),
				Text('الشهر: $month'),
				IconButton(onPressed: () => setState(() => month = month < 12 ? month + 1 : 1), icon: const Icon(Icons.chevron_left)),
				TextButton(
					onPressed: () => context.read<LogsCubit>().loadMonthly(year, month),
					child: const Text('عرض'),
				),
			]),
			Expanded(child: BlocBuilder<LogsCubit, LogsState>(builder: (_, s) => _TotalsList(map: s.monthlyTotals))),
		]);
	}
}

class _YearlyTab extends StatefulWidget {
	const _YearlyTab();
	@override
	State<_YearlyTab> createState() => _YearlyTabState();
}

class _YearlyTabState extends State<_YearlyTab> {
	int year = DateTime.now().year;

	@override
	Widget build(BuildContext context) {
		return Column(children: [
			Row(children: [
				IconButton(onPressed: () => setState(() => year--), icon: const Icon(Icons.chevron_right)),
				Text('السنة: $year'),
				IconButton(onPressed: () => setState(() => year++), icon: const Icon(Icons.chevron_left)),
				TextButton(
					onPressed: () => context.read<LogsCubit>().loadYearly(year),
					child: const Text('عرض'),
				),
				const SizedBox(width: 12),
				TextButton(
					onPressed: () async {
						final range = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now());
						if (range != null) {
							final map = await context.read<LogsCubit>().loadRange(range.start, range.end);
							if (!context.mounted) return;
							showDialog(
								context: context,
								builder: (_) => BlocProvider.value(
									value: context.read<StudentsCubit>(),
									child: _RangeDialog(map: map),
								),
							);
						}
					},
					child: const Text('نطاق التواريخ'),
				),
			]),
			Expanded(child: BlocBuilder<LogsCubit, LogsState>(builder: (_, s) => _TotalsList(map: s.yearlyTotals))),
		]);
	}
}

class _TotalsList extends StatelessWidget {
	final Map<int, int> map;
	const _TotalsList({required this.map});

	@override
	Widget build(BuildContext context) {
		return BlocBuilder<StudentsCubit, StudentsState>(builder: (_, s) {
			return ListView(
				children: [
					for (final entry in map.entries)
						ListTile(
							title: Text(s.students.firstWhere((e) => e.id == entry.key, orElse: () => s.students.isEmpty ? (throw Exception('No students')) : s.students.first).name),
							subtitle: Text('المجموع: ${entry.value}')
						),
				],
			);
		});
	}
}

class _DayBreakdownDialog extends StatefulWidget {
	final DateTime date;
	const _DayBreakdownDialog({required this.date});

	@override
	State<_DayBreakdownDialog> createState() => _DayBreakdownDialogState();
}

class _DayBreakdownDialogState extends State<_DayBreakdownDialog> {
	final _studentsRepo = StudentRepository();
	final _habitsRepo = HabitRepository();
	final _trackingRepo = TrackingRepository();

	bool _loading = true;
	List<Student> _students = const [];
	List<Habit> _habits = const [];
	Map<int, Map<int, int>> _counts = const {};

	@override
	void initState() {
		super.initState();
		_load();
	}

	Future<void> _load() async {
		setState(() => _loading = true);
		final students = await _studentsRepo.getAll();
		final habits = await _habitsRepo.getAll();
		final counts = await _trackingRepo.getDayBreakdown(widget.date);
		if (!mounted) return;
		setState(() {
			_students = students;
			_habits = habits;
			_counts = counts;
			_loading = false;
		});
	}

	@override
	Widget build(BuildContext context) {
		return Directionality(
			textDirection: TextDirection.rtl,
			child: AlertDialog(
				title: Text('جدول اليوم: ${widget.date.toIso8601String().substring(0, 10)}'),
				content: SizedBox(
					width: double.maxFinite,
					child: _loading
						? const Center(child: CircularProgressIndicator())
						: SingleChildScrollView(
							scrollDirection: Axis.horizontal,
							child: DataTable(
								columns: [
									const DataColumn(label: Text('الطالب')),
									for (final h in _habits) DataColumn(label: Text(h.name)),
								],
								rows: [
									for (final s in _students)
										DataRow(cells: [
											DataCell(Text(s.name)),
											for (final h in _habits)
												DataCell(Text(_formatPoints(_counts[s.id]?[h.id] ?? 0, h.points))),
										]),
								],
							),
						),
				),
				actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
			),
		);
	}

	String _formatPoints(int count, int pointsPerHabit) {
		final pts = count * pointsPerHabit;
		return '$pts';
	}
}

class _RangeDialog extends StatelessWidget {
	final Map<int, int> map;
	const _RangeDialog({required this.map});

	@override
	Widget build(BuildContext context) {
		return AlertDialog(
			title: const Text('نطاق التواريخ'),
			content: SizedBox(
				width: double.maxFinite,
				height: 300,
				child: BlocBuilder<StudentsCubit, StudentsState>(builder: (_, s) {
					return ListView(
						shrinkWrap: true,
						children: [
							for (final entry in map.entries)
								ListTile(
									title: Text(s.students.firstWhere((e) => e.id == entry.key, orElse: () => s.students.isEmpty ? (throw Exception('No students')) : s.students.first).name),
									subtitle: Text('المجموع: ${entry.value}')
								),
						],
					);
				}),
			),
			actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
		);
	}
}


