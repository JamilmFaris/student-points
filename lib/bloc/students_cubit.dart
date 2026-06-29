import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/student.dart';
import '../repositories/student_repository.dart';

class StudentsState {
	final List<Student> students;
	final bool loading;
	final String? error;

	StudentsState({required this.students, this.loading = false, this.error});

	StudentsState copyWith({List<Student>? students, bool? loading, String? error}) {
		return StudentsState(
			students: students ?? this.students,
			loading: loading ?? this.loading,
			error: error,
		);
	}
}

class StudentsCubit extends Cubit<StudentsState> {
	final StudentRepository _repo;
	/// When true, archived (hidden) students are included — used by the logs so
	/// that historical points of deleted students still resolve to their names.
	final bool includeArchived;
	StreamSubscription<void>? _externalSub;

	StudentsCubit(this._repo, {this.includeArchived = false})
		: super(StudentsState(students: [], loading: true)) {
		load();
		_externalSub = StudentRepository.externalChanges.listen((_) {
			load();
		});
	}

	@override
	Future<void> close() {
		_externalSub?.cancel();
		return super.close();
	}

	Future<void> load() async {
		try {
			final list = includeArchived
				? await _repo.getAllIncludingArchived()
				: await _repo.getAll();
			emit(state.copyWith(students: list, loading: false, error: null));
		} catch (e) {
			emit(state.copyWith(loading: false, error: e.toString()));
		}
	}

	Future<void> addStudent(String name) async {
		await _repo.insert(Student(name: name));
		await load();
	}

	Future<void> updateStudent(Student student) async {
		await _repo.update(student);
		await load();
	}

	Future<void> deleteStudent(int id) async {
		await _repo.delete(id);
		await load();
	}

	Future<void> reorderStudents(int oldIndex, int newIndex) async {
		final current = List<Student>.from(state.students);
		if (newIndex > oldIndex) newIndex -= 1;
		final item = current.removeAt(oldIndex);
		current.insert(newIndex, item);
		emit(state.copyWith(students: current));
		await _repo.updateOrder(current);
	}
}


