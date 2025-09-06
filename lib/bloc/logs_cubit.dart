import 'package:flutter_bloc/flutter_bloc.dart';

import '../repositories/tracking_repository.dart';

class LogsState {
	final List<String> dates; // ISO yyyy-MM-dd
	final Map<int, int> dailyTotals; // studentId -> points for selectedDate
	final Map<int, int> monthlyTotals;
	final Map<int, int> yearlyTotals;
	final bool loading;
	final DateTime? selectedDate;
	final int? selectedMonth;
	final int? selectedYear;
	final String? error;

	LogsState({
		required this.dates,
		required this.dailyTotals,
		required this.monthlyTotals,
		required this.yearlyTotals,
		this.loading = false,
		this.selectedDate,
		this.selectedMonth,
		this.selectedYear,
		this.error,
	});

	LogsState copyWith({
		List<String>? dates,
		Map<int, int>? dailyTotals,
		Map<int, int>? monthlyTotals,
		Map<int, int>? yearlyTotals,
		bool? loading,
		DateTime? selectedDate,
		int? selectedMonth,
		int? selectedYear,
		String? error,
	}) {
		return LogsState(
			dates: dates ?? this.dates,
			dailyTotals: dailyTotals ?? this.dailyTotals,
			monthlyTotals: monthlyTotals ?? this.monthlyTotals,
			yearlyTotals: yearlyTotals ?? this.yearlyTotals,
			loading: loading ?? this.loading,
			selectedDate: selectedDate ?? this.selectedDate,
			selectedMonth: selectedMonth ?? this.selectedMonth,
			selectedYear: selectedYear ?? this.selectedYear,
			error: error,
		);
	}
}

class LogsCubit extends Cubit<LogsState> {
	final TrackingRepository _repo;
	LogsCubit(this._repo)
		: super(LogsState(dates: [], dailyTotals: {}, monthlyTotals: {}, yearlyTotals: {}, loading: true)) {
		refreshDates();
	}

	Future<void> refreshDates() async {
		try {
			final dates = await _repo.getDistinctDates();
			emit(state.copyWith(dates: dates, loading: false));
		} catch (e) {
			emit(state.copyWith(loading: false, error: e.toString()));
		}
	}

	Future<void> loadDaily(DateTime date) async {
		emit(state.copyWith(loading: true, selectedDate: date));
		try {
			final totals = await _repo.getDailyTotals(date);
			emit(state.copyWith(dailyTotals: totals, loading: false));
		} catch (e) {
			emit(state.copyWith(loading: false, error: e.toString()));
		}
	}

	Future<void> loadMonthly(int year, int month) async {
		emit(state.copyWith(loading: true, selectedYear: year, selectedMonth: month));
		try {
			final totals = await _repo.getMonthlyTotals(year, month);
			emit(state.copyWith(monthlyTotals: totals, loading: false));
		} catch (e) {
			emit(state.copyWith(loading: false, error: e.toString()));
		}
	}

	Future<void> loadYearly(int year) async {
		emit(state.copyWith(loading: true, selectedYear: year));
		try {
			final totals = await _repo.getYearlyTotals(year);
			emit(state.copyWith(yearlyTotals: totals, loading: false));
		} catch (e) {
			emit(state.copyWith(loading: false, error: e.toString()));
		}
	}

	Future<Map<int, int>> loadRange(DateTime start, DateTime end) async {
		return _repo.getTotalsInRange(start, end);
	}
}


