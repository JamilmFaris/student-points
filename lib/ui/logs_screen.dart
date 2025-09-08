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
								Tab(text: 'نطاق'),
							]),
						),
						body: const TabBarView(children: [
							_DailyTab(),
							_MonthlyTab(),
							_RangeTab(),
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
			String _arabicWeekday(String isoDate) {
				final dt = DateTime.parse(isoDate);
				switch (dt.weekday) {
					case DateTime.monday:
						return 'الاثنين';
					case DateTime.tuesday:
						return 'الثلاثاء';
					case DateTime.wednesday:
						return 'الأربعاء';
					case DateTime.thursday:
						return 'الخميس';
					case DateTime.friday:
						return 'الجمعة';
					case DateTime.saturday:
						return 'السبت';
					default:
						return 'الأحد';
				}
			}
			return Column(children: [
				Expanded(
					child: ListView.builder(
						itemCount: state.dates.length,
						itemBuilder: (context, index) {
							final d = state.dates[index];
							final isSelected = state.selectedDate?.toIso8601String().substring(0, 10) == d;
							return Card(
								margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
								shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
								child: ListTile(
									leading: CircleAvatar(
										backgroundColor: Theme.of(context).colorScheme.primaryContainer,
										child: const Icon(Icons.calendar_today),
									),
									title: Text(d, style: const TextStyle(fontWeight: FontWeight.w600)),
									subtitle: Text('اليوم: ${_arabicWeekday(d)}'),
									onTap: () => logsCubit.loadDaily(DateTime.parse(d)),
									trailing: Row(
										mainAxisSize: MainAxisSize.min,
										children: [
											IconButton(
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
											if (isSelected)
												Chip(
													label: const Text('محدد'),
													backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
												),
										],
									),
									tileColor: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.06) : null,
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

class _RangeTab extends StatefulWidget {
	const _RangeTab();
	@override
	State<_RangeTab> createState() => _RangeTabState();
}

class _RangeTabState extends State<_RangeTab> {
	DateTime? start;
	DateTime? end;
	Map<int, int>? totals;
	bool loading = false;

	Future<void> _pickRange(BuildContext context) async {
		final picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now());
		if (picked != null) {
			setState(() {
				start = picked.start;
				end = picked.end;
				loading = true;
			});
			final map = await context.read<LogsCubit>().loadRange(picked.start, picked.end);
			if (!mounted) return;
			setState(() {
				totals = map;
				loading = false;
			});
		}
	}

	@override
	Widget build(BuildContext context) {
		return Column(children: [
			Padding(
				padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
				child: Row(children: [
					FilledButton.icon(
						onPressed: () => _pickRange(context),
						icon: const Icon(Icons.date_range),
						label: const Text('اختيار النطاق'),
					),
					const SizedBox(width: 12),
					if (start != null && end != null)
						Chip(label: Text('${start!.toIso8601String().substring(0, 10)} → ${end!.toIso8601String().substring(0, 10)}')),
				]),
			),
			if (totals == null && !loading)
				Padding(
					padding: const EdgeInsets.all(16),
					child: Column(
						children: [
							Card(
								shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										children: const [
											Icon(Icons.timeline, size: 36),
											SizedBox(height: 12),
											Text('اختر نطاقًا لعرض إجمالي النقاط خلال فترة محددة', textAlign: TextAlign.center),
										],
									),
								),
							),
							const SizedBox(height: 12),
							Wrap(
								spacing: 8,
								runSpacing: 8,
								children: [
									ActionChip(label: const Text('اليوم'), onPressed: () {
										final now = DateTime.now();
										setState(() => loading = true);
										context.read<LogsCubit>().loadRange(DateTime(now.year, now.month, now.day), DateTime(now.year, now.month, now.day)).then((map) {
											if (!mounted) return; setState(() { start = DateTime(now.year, now.month, now.day); end = start; totals = map; loading = false; });
										});
									}),
									ActionChip(label: const Text('آخر 7 أيام'), onPressed: () {
										final now = DateTime.now();
										final s = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
										final e = DateTime(now.year, now.month, now.day);
										setState(() => loading = true);
										context.read<LogsCubit>().loadRange(s, e).then((map) { if (!mounted) return; setState(() { start = s; end = e; totals = map; loading = false; }); });
									}),
									ActionChip(label: const Text('هذا الشهر'), onPressed: () {
										final now = DateTime.now();
										final s = DateTime(now.year, now.month, 1);
										final e = DateTime(now.year, now.month + 1, 1).subtract(const Duration(days: 1));
										setState(() => loading = true);
										context.read<LogsCubit>().loadRange(s, e).then((map) { if (!mounted) return; setState(() { start = s; end = e; totals = map; loading = false; }); });
									}),
									ActionChip(label: const Text('آخر 30 يومًا'), onPressed: () {
										final now = DateTime.now();
										final e = DateTime(now.year, now.month, now.day);
										final s = e.subtract(const Duration(days: 29));
										setState(() => loading = true);
										context.read<LogsCubit>().loadRange(s, e).then((map) { if (!mounted) return; setState(() { start = s; end = e; totals = map; loading = false; }); });
									}),
								],
							),
						],
					),
				),
			if (loading)
				const Expanded(child: Center(child: CircularProgressIndicator())),
			if (totals != null && !loading)
				Expanded(child: _TotalsList(map: totals!)),
		]);
	}
}

class _TotalsList extends StatelessWidget {
	final Map<int, int> map;
	const _TotalsList({required this.map});

	@override
	Widget build(BuildContext context) {
		return BlocBuilder<StudentsCubit, StudentsState>(builder: (_, s) {
			final entries = map.entries.toList()
				..sort((a, b) => (b.value).compareTo(a.value));
			Color _chipColor(int v) {
				final scheme = Theme.of(context).colorScheme;
				if (v > 0) return scheme.primaryContainer;
				if (v < 0) return scheme.errorContainer;
				return scheme.surfaceVariant;
			}
			return ListView.builder(
				padding: const EdgeInsets.all(12),
				itemCount: entries.length,
				itemBuilder: (_, i) {
					final entry = entries[i];
					final student = s.students.firstWhere(
						(e) => e.id == entry.key,
						orElse: () => s.students.isEmpty ? (throw Exception('No students')) : s.students.first,
					);
					final name = student.name;
					final initial = name.isNotEmpty ? name.characters.first : '?';
					return Card(
						shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
						margin: const EdgeInsets.symmetric(vertical: 6),
						child: ListTile(
							leading: CircleAvatar(child: Text(initial)),
							title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
							subtitle: const Text('إجمالي نقاط اليوم'),
							trailing: Chip(
								label: Text('${entry.value}'),
								backgroundColor: _chipColor(entry.value),
							),
						),
					);
				},
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
	Map<int, Map<int, int>> _points = const {};

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
		final points = await _trackingRepo.getDayPointsBreakdown(widget.date);
		if (!mounted) return;
		setState(() {
			_students = students;
			_habits = habits;
			_counts = counts;
			_points = points;
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
					height: 420,
					child: _loading
						? const Center(child: CircularProgressIndicator())
						: SingleChildScrollView(
							child: SingleChildScrollView(
								scrollDirection: Axis.horizontal,
								child: DataTable(
									columns: [
										const DataColumn(label: Text('الطالب')),
										for (final h in _habits) DataColumn(label: Text(h.name)),
										const DataColumn(label: Text('المجموع')),
									],
									rows: [
										for (final s in _students)
											DataRow(cells: [
												DataCell(Text(s.name)),
												for (final h in _habits)
													DataCell(Container(
														padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
														decoration: BoxDecoration(
															color: (() {
																final v = _points[s.id]?[h.id] ?? 0;
																if (v > 0) return Theme.of(context).colorScheme.primary.withOpacity(0.08);
																if (v < 0) return Theme.of(context).colorScheme.error.withOpacity(0.08);
																return null;
															})(),
															borderRadius: BorderRadius.circular(8),
														),
														child: Text('${_points[s.id]?[h.id] ?? ((_counts[s.id]?[h.id] ?? 0) * h.points)}'),
													)),
												DataCell(Text('${(_points[s.id]?.values ?? const Iterable<int>.empty()).fold<int>(0, (a, b) => a + b)}')),
											]),
										if (_students.isNotEmpty)
											DataRow(cells: [
												const DataCell(Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.w700))),
												for (final h in _habits)
													DataCell(Text('${_students.fold<int>(0, (sum, s) => sum + (_points[s.id]?[h.id] ?? 0))}')),
												DataCell(Text('${_students.fold<int>(0, (sum, s) => sum + (_points[s.id]?.values.fold<int>(0, (a, b) => a + b) ?? 0))}')),
											]),
									],
								),
							),
					),
				),
				actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
			),
		);
	}
}

// removed _RangeDialog (replaced with inline Range tab)


