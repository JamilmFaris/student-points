import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/daily_entry.dart';
import '../repositories/tracking_repository.dart';

class TrackingState {
	final DateTime date;
	final Map<int, Map<int, int>> countsByStudentHabit;
	final bool loading;
	final String? error;

	TrackingState({required this.date, required this.countsByStudentHabit, this.loading = false, this.error});

	TrackingState copyWith({DateTime? date, Map<int, Map<int, int>>? countsByStudentHabit, bool? loading, String? error}) {
		return TrackingState(
			date: date ?? this.date,
			countsByStudentHabit: countsByStudentHabit ?? this.countsByStudentHabit,
			loading: loading ?? this.loading,
			error: error,
		);
	}
}

class TrackingCubit extends Cubit<TrackingState> {
	final TrackingRepository _repo;
	TrackingCubit(this._repo)
		: super(TrackingState(date: DateTime.now(), countsByStudentHabit: {}, loading: true)) {
		load(DateTime.now());
	}

	Future<void> load(DateTime date) async {
		emit(state.copyWith(loading: true, date: date));
		try {
			final breakdown = await _repo.getDayBreakdown(date);
			emit(state.copyWith(countsByStudentHabit: breakdown, loading: false, error: null));
		} catch (e) {
			emit(state.copyWith(loading: false, error: e.toString()));
		}
	}

	Future<void> increment(int studentId, int habitId) async {
		await _repo.incrementHabitCount(date: state.date, studentId: studentId, habitId: habitId);
		await load(state.date);
	}

	Future<void> saveAll() async {
		final entries = <DailyEntry>[];
		state.countsByStudentHabit.forEach((studentId, habits) {
			habits.forEach((habitId, count) {
				entries.add(DailyEntry(date: state.date, studentId: studentId, habitId: habitId, count: count));
			});
		});
		await _repo.saveEntries(entries);
	}
}


