import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/habit.dart';
import '../../models/habit_daily_point.dart';
import '../../repositories/tracking_repository.dart';
import '../../repositories/student_repository.dart';
import '../../models/student.dart';

class HabitProgressChart extends StatefulWidget {
	final Habit habit;
	final DateTime startDate;
	final DateTime endDate;
	final TrackingRepository repo;
	final int? fixedStudentId;

	const HabitProgressChart({super.key, required this.habit, required this.startDate, required this.endDate, required this.repo, this.fixedStudentId});

	@override
	State<HabitProgressChart> createState() => _HabitProgressChartState();
}

class _HabitProgressChartState extends State<HabitProgressChart> {
	Future<List<HabitDailyPoint>>? _future;
	List<Student> _students = [];
	int? _selectedStudentId; // null => all students
	late DateTime _startDate;
	late DateTime _endDate;

	@override
	void initState() {
		super.initState();
		_startDate = widget.startDate;
		_endDate = widget.endDate;
		if (widget.fixedStudentId != null) {
			_selectedStudentId = widget.fixedStudentId;
		} else {
			_loadStudents();
		}
		_loadSeries();
	}

	Future<void> _loadStudents() async {
		final list = await StudentRepository().getAll();
		if (!mounted) return;
		setState(() {
			_students = list;
		});
	}

	void _loadSeries() {
		_future = widget.repo.getHabitDailyPointsSeries(
			widget.habit.id!,
			startDate: _startDate,
			endDate: _endDate,
			studentId: _selectedStudentId,
		);
	}

	Future<void> _pickCustomRange() async {
		final start = await showDatePicker(
			context: context,
			firstDate: DateTime(2000),
			lastDate: DateTime.now(),
			initialDate: _startDate,
		);
		if (start == null) return;
		final end = await showDatePicker(
			context: context,
			firstDate: start,
			lastDate: DateTime.now(),
			initialDate: _endDate.isBefore(start) ? start : _endDate,
		);
		if (end == null) return;
		setState(() {
			_startDate = DateTime(start.year, start.month, start.day);
			_endDate = DateTime(end.year, end.month, end.day);
			_loadSeries();
		});
	}

	String _formatDay(DateTime d) {
		return '${d.month}/${d.day}';
	}

	@override
	Widget build(BuildContext context) {
		return SafeArea(
			child: Padding(
				padding: const EdgeInsets.all(16),
				child: Column(
					mainAxisSize: MainAxisSize.min,
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						Row(
							children: [
								Expanded(child: Text('تقدم: ${widget.habit.name}', style: Theme.of(context).textTheme.titleMedium)),
								IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
							],
						),
						const SizedBox(height: 8),
		if (widget.fixedStudentId == null)
			Row(
				children: [
					Text('الطالب:', style: Theme.of(context).textTheme.bodyMedium),
					const SizedBox(width: 12),
					Expanded(
						child: DropdownButton<int?>(
							isExpanded: true,
							value: _selectedStudentId,
							items: [
								const DropdownMenuItem<int?>(value: null, child: Text('الكل')),
								..._students.map((s) => DropdownMenuItem<int?>(value: s.id, child: Text(s.name))).toList(),
							],
							onChanged: (v) {
								setState(() {
									_selectedStudentId = v;
									_loadSeries();
								});
							},
						),
					),
				],
			),
						const SizedBox(height: 8),
						SingleChildScrollView(
							scrollDirection: Axis.horizontal,
							child: Row(
								children: [
									ChoiceChip(
										label: const Text('7 أيام'),
										selected: _endDate.difference(_startDate).inDays == 6,
										onSelected: (_) {
											setState(() {
												_endDate = DateTime.now();
												_startDate = _endDate.subtract(const Duration(days: 6));
												_loadSeries();
											});
										},
									),
									const SizedBox(width: 8),
									ChoiceChip(
										label: const Text('30 يوم'),
										selected: _endDate.difference(_startDate).inDays == 29,
										onSelected: (_) {
											setState(() {
												_endDate = DateTime.now();
												_startDate = _endDate.subtract(const Duration(days: 29));
												_loadSeries();
											});
										},
									),
									const SizedBox(width: 8),
									ChoiceChip(
										label: const Text('90 يوم'),
										selected: _endDate.difference(_startDate).inDays == 89,
										onSelected: (_) {
											setState(() {
												_endDate = DateTime.now();
												_startDate = _endDate.subtract(const Duration(days: 89));
												_loadSeries();
											});
										},
									),
									const SizedBox(width: 8),
									OutlinedButton.icon(
										icon: const Icon(Icons.calendar_today, size: 18),
										label: const Text('تخصيص'),
										onPressed: _pickCustomRange,
									),
								],
							),
						),
						FutureBuilder<List<HabitDailyPoint>>(
							future: _future,
							builder: (context, snapshot) {
								if (!snapshot.hasData) {
									return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
								}
								final data = snapshot.data!;
								final maxY = (data.map((e) => e.points).fold<int>(0, (p, e) => e > p ? e : p)).toDouble();
								return SizedBox(
									height: 260,
									child: LineChart(
										LineChartData(
											minX: 0,
											maxX: (data.length - 1).toDouble(),
											minY: 0,
											maxY: (maxY == 0 ? 1 : maxY) * 1.2,
											gridData: const FlGridData(show: true, drawVerticalLine: false),
											titlesData: FlTitlesData(
												bottomTitles: AxisTitles(
													sideTitles: SideTitles(
														showTitles: true,
														getTitlesWidget: (value, meta) {
															final idx = value.toInt();
															if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
															return Padding(
																padding: const EdgeInsets.only(top: 6),
																child: Text(_formatDay(data[idx].date), style: const TextStyle(fontSize: 10)),
															);
														},
														reservedSize: 32,
													),
												),
												leftTitles: const AxisTitles(
													sideTitles: SideTitles(showTitles: true, reservedSize: 36),
												),
												rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
												topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
											),
											lineBarsData: [
												LineChartBarData(
													isCurved: true,
													color: Theme.of(context).colorScheme.primary,
													barWidth: 3,
													dotData: const FlDotData(show: false),
													belowBarData: BarAreaData(show: true, color: Theme.of(context).colorScheme.primary.withOpacity(0.15)),
													spots: [
														for (int i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i].points.toDouble())
													],
												),
											],
										),
									),
								);
							},
						),
						const SizedBox(height: 8),
						Align(
							alignment: Alignment.center,
							child: Text('${_formatDay(_startDate)} - ${_formatDay(_endDate)}', style: Theme.of(context).textTheme.bodySmall),
						),
					],
				),
			),
		);
	}
}


