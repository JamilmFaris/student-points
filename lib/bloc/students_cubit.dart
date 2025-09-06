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
	StudentsCubit(this._repo) : super(StudentsState(students: [], loading: true)) {
		load();
	}

	Future<void> load() async {
		try {
			final list = await _repo.getAll();
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
}


