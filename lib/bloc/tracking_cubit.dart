import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/lesson.dart';
import '../repositories/lesson_repository.dart';
import '../repositories/tracking_repository.dart';

class TrackingState {
	final DateTime date;
	final Map<int, Map<int, int>> countsByStudentHabit;
	final Lesson? lesson;
	final bool loading;
	final String? error;

	TrackingState({
		required this.date,
		required this.countsByStudentHabit,
		this.lesson,
		this.loading = false,
		this.error,
	});

	TrackingState copyWith({
		DateTime? date,
		Map<int, Map<int, int>>? countsByStudentHabit,
		Lesson? lesson,
		bool? loading,
		String? error,
	}) {
		return TrackingState(
			date: date ?? this.date,
			countsByStudentHabit: countsByStudentHabit ?? this.countsByStudentHabit,
			lesson: lesson ?? this.lesson,
			loading: loading ?? this.loading,
			error: error,
		);
	}
}

class TrackingCubit extends Cubit<TrackingState> {
	final TrackingRepository _repo;
	final LessonRepository _lessonRepo;

	StreamSubscription<TrackingPointsDelta>? _externalSub;

	TrackingCubit(this._repo, {LessonRepository? lessonRepo})
		: _lessonRepo = lessonRepo ?? LessonRepository(),
		  super(TrackingState(date: DateTime.now(), countsByStudentHabit: {}, loading: true)) {
		load(DateTime.now());
		_externalSub = TrackingRepository.externalChanges.listen((delta) {
			final s = state.date;
			if (s.year != delta.date.year || s.month != delta.date.month || s.day != delta.date.day) return;
			final updated = _cloneCounts(state.countsByStudentHabit);
			final studentMap = updated.putIfAbsent(delta.studentId, () => {});
			studentMap[delta.habitId] = (studentMap[delta.habitId] ?? 0) + delta.points;
			emit(state.copyWith(countsByStudentHabit: updated));
		});
	}

	@override
	Future<void> close() {
		_externalSub?.cancel();
		return super.close();
	}

	Future<void> load(DateTime date) async {
		emit(state.copyWith(loading: true, date: date));
		try {
			final breakdown = await _repo.getDayBreakdown(date);
			final lesson = await _lessonRepo.ensureForDate(date);
			emit(state.copyWith(
				countsByStudentHabit: breakdown,
				lesson: lesson,
				loading: false,
				error: null,
			));
		} catch (e) {
			emit(state.copyWith(loading: false, error: e.toString()));
		}
	}

	void increment(int studentId, int habitId, int points) {
		final updated = _cloneCounts(state.countsByStudentHabit);
		final studentMap = updated.putIfAbsent(studentId, () => {});
		studentMap[habitId] = (studentMap[habitId] ?? 0) + points;
		emit(state.copyWith(countsByStudentHabit: updated));
	}

	void decrement(int studentId, int habitId, int points) {
		final updated = _cloneCounts(state.countsByStudentHabit);
		final studentMap = updated.putIfAbsent(studentId, () => {});
		studentMap[habitId] = (studentMap[habitId] ?? 0) - points;
		emit(state.copyWith(countsByStudentHabit: updated));
	}

	Future<void> saveAll() async {
		// Replace the entire day's entries with the current state
		await _repo.replaceDayEntries(state.date, state.countsByStudentHabit);
	}

	Future<void> setLessonSubject(String subject) async {
		final lesson = state.lesson;
		if (lesson?.id == null) return;
		await _lessonRepo.updateSubject(lesson!.id!, subject);
		emit(state.copyWith(
			lesson: Lesson(
				id: lesson.id,
				date: lesson.date,
				subject: subject,
				remoteId: lesson.remoteId,
			),
		));
	}

	void setHabitValue(int studentId, int habitId, int value) {
		final updated = _cloneCounts(state.countsByStudentHabit);
		final studentMap = updated.putIfAbsent(studentId, () => {});
		studentMap[habitId] = value;
		emit(state.copyWith(countsByStudentHabit: updated));
	}

	Map<int, Map<int, int>> _cloneCounts(Map<int, Map<int, int>> src) {
		final copy = <int, Map<int, int>>{};
		src.forEach((studentId, habits) {
			copy[studentId] = Map<int, int>.from(habits);
		});
		return copy;
	}
}
