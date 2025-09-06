import 'package:flutter_bloc/flutter_bloc.dart';

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

	void increment(int studentId, int habitId) {
		final updated = _cloneCounts(state.countsByStudentHabit);
		final studentMap = updated.putIfAbsent(studentId, () => {});
		studentMap[habitId] = (studentMap[habitId] ?? 0) + 1;
		emit(state.copyWith(countsByStudentHabit: updated));
	}

	void decrement(int studentId, int habitId) {
		final updated = _cloneCounts(state.countsByStudentHabit);
		final studentMap = updated.putIfAbsent(studentId, () => {});
		studentMap[habitId] = (studentMap[habitId] ?? 0) - 1;
		emit(state.copyWith(countsByStudentHabit: updated));
	}

	Future<void> saveAll() async {
		// Replace the entire day's entries with the current state
		await _repo.replaceDayEntries(state.date, state.countsByStudentHabit);
	}

	Map<int, Map<int, int>> _cloneCounts(Map<int, Map<int, int>> src) {
		final copy = <int, Map<int, int>>{};
		src.forEach((studentId, habits) {
			copy[studentId] = Map<int, int>.from(habits);
		});
		return copy;
	}
}


