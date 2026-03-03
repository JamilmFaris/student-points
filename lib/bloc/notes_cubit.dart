import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/note.dart';
import '../repositories/notes_repository.dart';

class NotesState {
	final List<Note> notes;
	final bool loading;
	final String? error;

	NotesState({required this.notes, this.loading = false, this.error});

	NotesState copyWith({List<Note>? notes, bool? loading, String? error}) {
		return NotesState(
			notes: notes ?? this.notes,
			loading: loading ?? this.loading,
			error: error ?? this.error,
		);
	}
}

class NotesCubit extends Cubit<NotesState> {
	final NotesRepository _repo;
	final int _studentId;

	NotesCubit(this._repo, this._studentId) : super(NotesState(notes: [], loading: true)) {
		load();
	}

	Future<void> load() async {
		emit(state.copyWith(loading: true, error: null));
		try {
			final list = await _repo.listForStudent(_studentId);
			emit(NotesState(notes: list, loading: false, error: null));
		} catch (e) {
			emit(NotesState(notes: state.notes, loading: false, error: e.toString()));
		}
	}

	Future<void> addNote(String title, String noteText) async {
		final now = DateTime.now().toIso8601String();
		await _repo.insert(Note(
			studentId: _studentId,
			title: title.trim().isEmpty ? 'ملاحظة بدون عنوان' : title.trim(),
			noteText: noteText.trim(),
			createdAt: now,
			updatedAt: now,
		));
		await load();
	}

	Future<void> updateNote(Note note, String title, String noteText) async {
		await _repo.update(note.copyWith(
			title: title.trim().isEmpty ? 'ملاحظة بدون عنوان' : title.trim(),
			noteText: noteText.trim(),
		));
		await load();
	}

	Future<void> deleteNote(int id) async {
		await _repo.delete(id);
		await load();
	}
}

