import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/habit.dart';
import '../repositories/habit_repository.dart';

class HabitsState {
	final List<Habit> habits;
	final bool loading;
	final String? error;

	HabitsState({required this.habits, this.loading = false, this.error});

	HabitsState copyWith({List<Habit>? habits, bool? loading, String? error}) {
		return HabitsState(
			habits: habits ?? this.habits,
			loading: loading ?? this.loading,
			error: error,
		);
	}
}

class HabitsCubit extends Cubit<HabitsState> {
	final HabitRepository _repo;
	HabitsCubit(this._repo) : super(HabitsState(habits: [], loading: true)) {
		load();
	}

	Future<void> load() async {
		try {
			final list = await _repo.getAll();
			emit(state.copyWith(habits: list, loading: false, error: null));
		} catch (e) {
			emit(state.copyWith(loading: false, error: e.toString()));
		}
	}

	Future<void> addHabit(String name, int points, {int? decreasePoints, bool allowNegative = false, bool oncePerDay = false}) async {
		await _repo.insert(Habit(name: name, points: points, decreasePoints: decreasePoints ?? points, allowNegative: allowNegative, oncePerDay: oncePerDay));
		await load();
	}

	Future<void> updateHabit(Habit habit) async {
		await _repo.update(habit);
		await load();
	}

	Future<void> deleteHabit(int id) async {
		await _repo.delete(id);
		await load();
	}
}


