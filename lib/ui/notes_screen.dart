import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show DateFormat ;

import '../bloc/notes_cubit.dart';
import '../models/note.dart';
import '../models/student.dart';
import '../repositories/notes_repository.dart';

import 'widgets/app_drawer.dart';

class NotesScreen extends StatelessWidget {
	final Student student;

	const NotesScreen({super.key, required this.student});

	@override
	Widget build(BuildContext context) {
		return Directionality(
			textDirection: TextDirection.rtl,
			child: BlocProvider(
				create: (_) => NotesCubit(NotesRepository(), student.id!),
				child: Builder(
					builder: (ctx) => Scaffold(
					appBar: AppBar(title: Text('دفتر ملاحظات - ${student.name}')),
					drawer: const AppDrawer(),
					body: BlocBuilder<NotesCubit, NotesState>(
						builder: (context, state) {
							if (state.loading && state.notes.isEmpty) {
								return const Center(child: CircularProgressIndicator());
							}
							if (state.error != null) {
								return Center(
									child: Padding(
										padding: const EdgeInsets.all(16),
										child: Text('خطأ: ${state.error}', textAlign: TextAlign.center),
									),
								);
							}
							if (state.notes.isEmpty) {
								return Center(
									child: Column(
										mainAxisSize: MainAxisSize.min,
										children: [
											Icon(Icons.note_add_outlined, size: 64, color: Colors.grey.shade400),
											const SizedBox(height: 16),
											Text('لا توجد ملاحظات بعد', style: Theme.of(context).textTheme.titleMedium),
											const SizedBox(height: 8),
											Text('اضغط + لإضافة ملاحظة جديدة', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
										],
									),
								);
							}
							return ListView.builder(
								padding: const EdgeInsets.all(16),
								itemCount: state.notes.length,
								itemBuilder: (context, index) {
									final note = state.notes[index];
									return _NoteCard(
										note: note,
										onTap: () => _openNoteEditor(ctx, note, isNew: false),
										onDelete: () => _confirmDelete(ctx, note),
									);
								},
							);
						},
					),
					floatingActionButton: FloatingActionButton(
						onPressed: () => _openNoteEditor(ctx, null, isNew: true),
						child: const Icon(Icons.add),
					),
				),
				),
			),
		);
	}

	Future<void> _openNoteEditor(BuildContext context, Note? note, {required bool isNew}) async {
		final cubit = context.read<NotesCubit>();
		final titleController = TextEditingController(text: note?.title ?? '');
		final textController = TextEditingController(text: note?.noteText ?? '');
		final result = await showDialog<bool>(
			context: context,
			builder: (ctx) {
				return Directionality(
					textDirection: TextDirection.rtl,
					child: AlertDialog(
						title: Text(isNew ? 'ملاحظة جديدة' : 'تعديل الملاحظة'),
						content: SingleChildScrollView(
							child: Column(
								mainAxisSize: MainAxisSize.min,
								crossAxisAlignment: CrossAxisAlignment.stretch,
								children: [
									TextField(
										controller: titleController,
										decoration: const InputDecoration(labelText: 'العنوان'),
										textDirection: TextDirection.rtl,
									),
									const SizedBox(height: 12),
									TextField(
										controller: textController,
										decoration: const InputDecoration(labelText: 'النص'),
										textDirection: TextDirection.rtl,
										maxLines: 6,
									),
									if (!isNew && note != null) ...[
										const SizedBox(height: 16),
										_buildDateRow('كُتبت في تاريخ', note.createdAt),
										const SizedBox(height: 4),
										_buildDateRow('عُدِّلت في تاريخ', note.updatedAt),
									],
								],
							),
						),
						actions: [
							TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
							FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
						],
					),
				);
			},
		);
		if (result == true && context.mounted) {
			try {
				if (isNew) {
					await cubit.addNote(titleController.text, textController.text);
				} else if (note != null) {
					await cubit.updateNote(note, titleController.text, textController.text);
				}
				if (context.mounted) {
					ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ')));
				}
			} catch (e) {
				if (context.mounted) {
					ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
				}
			}
		}
	}

	Widget _buildDateRow(String label, String isoDate) {
		final dt = DateTime.tryParse(isoDate);
		final formatted = dt != null ? DateFormat('d/M/yyyy h:mm a', 'ar').format(dt) : isoDate;
		return Row(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
				const SizedBox(width: 8),
				Expanded(child: Text(formatted, style: const TextStyle(fontSize: 12), textDirection: TextDirection.ltr)),
			],
		);
	}

	Future<void> _confirmDelete(BuildContext context, Note note) async {
		final cubit = context.read<NotesCubit>();
		final ok = await showDialog<bool>(
			context: context,
			builder: (ctx) => Directionality(
				textDirection: TextDirection.rtl,
				child: AlertDialog(
					title: const Text('حذف الملاحظة'),
					content: Text('هل تريد حذف "${note.title}"؟'),
					actions: [
						TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
						TextButton(
							onPressed: () => Navigator.pop(ctx, true),
							style: TextButton.styleFrom(foregroundColor: Colors.red),
							child: const Text('حذف'),
						),
					],
				),
			),
		);
		if (ok == true && context.mounted) {
			await cubit.deleteNote(note.id!);
		}
	}
}

class _NoteCard extends StatelessWidget {
	final Note note;
	final VoidCallback onTap;
	final VoidCallback onDelete;

	const _NoteCard({required this.note, required this.onTap, required this.onDelete});

	String _formatDate(String iso) {
		final dt = DateTime.tryParse(iso);
		return dt != null ? DateFormat('d/M/yyyy h:mm', 'ar').format(dt) : iso;
	}

	@override
	Widget build(BuildContext context) {
		return Card(
			margin: const EdgeInsets.only(bottom: 12),
			child: InkWell(
				onTap: onTap,
				borderRadius: BorderRadius.circular(12),
				child: Padding(
					padding: const EdgeInsets.all(16),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Row(
								children: [
									Expanded(
										child: Text(
											note.title,
											style: Theme.of(context).textTheme.titleMedium,
											maxLines: 1,
											overflow: TextOverflow.ellipsis,
										),
									),
									IconButton(
										icon: const Icon(Icons.delete_outline),
										onPressed: onDelete,
										color: Colors.red.shade700,
									),
								],
							),
							if (note.noteText.isNotEmpty) ...[
								const SizedBox(height: 8),
								Text(
									note.noteText,
									style: Theme.of(context).textTheme.bodyMedium,
									maxLines: 3,
									overflow: TextOverflow.ellipsis,
								),
							],
							const SizedBox(height: 12),
							Text(
								'كُتبت في تاريخ ${_formatDate(note.createdAt)}',
								style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
								textDirection: TextDirection.ltr,
							),
							const SizedBox(height: 2),
							Text(
								'عُدِّلت في تاريخ ${_formatDate(note.updatedAt)}',
								style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
								textDirection: TextDirection.ltr,
							),
						],
					),
				),
			),
		);
	}
}
