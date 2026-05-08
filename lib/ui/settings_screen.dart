import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../repositories/habit_repository.dart';
import '../services/app_mode.dart';
import '../services/backup_service.dart';
import 'widgets/app_drawer.dart';

class SettingsScreen extends StatefulWidget {
	const SettingsScreen({super.key});

	@override
	State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
	String _backupPath = '';
	List<Habit> _habits = const [];
	Habit? _resolvedAttendanceHabit;
	bool _attendanceFromName = false; // true if a حضور habit dictates the choice

	@override
	void initState() {
		super.initState();
		_loadBackupPath();
		_loadAttendance();
	}

	Future<void> _loadBackupPath() async {
		final path = await BackupService.getAutoBackupPath();
		if (mounted) setState(() => _backupPath = path);
	}

	Future<void> _loadAttendance() async {
		final habits = await HabitRepository().getAll();
		final resolved = await AppMode.resolveAttendanceHabit(habits);
		final byName = habits.any(
			(h) => h.name.trim() == AppMode.defaultAttendanceHabitName,
		);
		if (!mounted) return;
		setState(() {
			_habits = habits;
			_resolvedAttendanceHabit = resolved;
			_attendanceFromName = byName;
		});
	}

	Future<void> _pickAttendanceHabit() async {
		final picked = await showDialog<Habit>(
			context: context,
			builder: (ctx) => Directionality(
				textDirection: TextDirection.rtl,
				child: AlertDialog(
					title: const Text('اختر العادة الخاصة بالحضور'),
					content: SizedBox(
						width: double.maxFinite,
						child: ListView.builder(
							shrinkWrap: true,
							itemCount: _habits.length,
							itemBuilder: (_, i) => ListTile(
								title: Text(_habits[i].name),
								onTap: () => Navigator.pop(ctx, _habits[i]),
							),
						),
					),
					actions: [
						TextButton(
							onPressed: () => Navigator.pop(ctx),
							child: const Text('إلغاء'),
						),
					],
				),
			),
		);
		if (picked == null) return;
		await AppMode.setAttendanceHabitOverride(picked.id);
		await _loadAttendance();
	}

	@override
	Widget build(BuildContext context) {
		return Directionality(
			textDirection: TextDirection.rtl,
			child: Scaffold(
				appBar: AppBar(title: const Text('الإعدادات')),
				drawer: const AppDrawer(),
				body: ListView(
					padding: const EdgeInsets.all(16),
					children: [
						Card(
							shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
							child: Padding(
								padding: const EdgeInsets.all(16),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										const Text('العادة الخاصة بالحضور', style: TextStyle(fontWeight: FontWeight.w700)),
										const SizedBox(height: 8),
										const Text(
											'تُحدِّد هذه العادة الحضور — كل طالب يحصل على نقاط موجبة عليها يُعدّ حاضراً لذلك اليوم.',
											style: TextStyle(fontSize: 13),
										),
										const SizedBox(height: 12),
										Text(
											_resolvedAttendanceHabit == null
												? 'لم يتم التعيين'
												: 'الحالية: ${_resolvedAttendanceHabit!.name}'
													+ (_attendanceFromName ? '  (مأخوذة من اسم العادة)' : ''),
											style: const TextStyle(fontSize: 13),
										),
										const SizedBox(height: 12),
										Wrap(
											spacing: 8,
											runSpacing: 8,
											children: [
												OutlinedButton.icon(
													icon: const Icon(Icons.edit),
													label: const Text('تغيير'),
													onPressed: _habits.isEmpty || _attendanceFromName
														? null
														: _pickAttendanceHabit,
												),
												if (!_attendanceFromName && _resolvedAttendanceHabit != null)
													TextButton.icon(
														icon: const Icon(Icons.clear),
														label: const Text('إلغاء التعيين'),
														onPressed: () async {
															await AppMode.setAttendanceHabitOverride(null);
															await _loadAttendance();
														},
													),
											],
										),
										if (_attendanceFromName) ...[
											const SizedBox(height: 6),
											const Text(
												'لا يمكن تغييرها هنا لأن لديك عادة باسم "حضور" — أعد تسميتها أولاً.',
												style: TextStyle(fontSize: 12, color: Colors.black54),
											),
										],
									],
								),
							),
						),
						const SizedBox(height: 12),
						Card(
							shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
							child: Padding(
								padding: const EdgeInsets.all(16),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										const Text('النسخ الاحتياطي التلقائي', style: TextStyle(fontWeight: FontWeight.w700)),
										const SizedBox(height: 8),
										const Text('يتم إنشاء نسخة احتياطية تلقائياً كل أسبوع عند فتح التطبيق. تُستبدل النسخة السابقة بالجديدة.'),
										const SizedBox(height: 12),
										Text('المسار الحالي:', style: Theme.of(context).textTheme.bodySmall),
										const SizedBox(height: 4),
										SelectableText(_backupPath.isEmpty ? 'جاري التحميل...' : _backupPath, style: const TextStyle(fontSize: 12)),
										const SizedBox(height: 12),
										Wrap(
											spacing: 8,
											runSpacing: 8,
											children: [
												OutlinedButton.icon(
													icon: const Icon(Icons.folder_open),
													label: const Text('تغيير المجلد'),
													onPressed: () async {
														final path = await BackupService.pickBackupDirectory();
														if (path != null) {
															await BackupService.setAutoBackupPath(path);
															if (mounted) {
																setState(() => _backupPath = path);
																ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث مسار النسخ الاحتياطي')));
															}
														}
													},
												),
												OutlinedButton.icon(
													icon: const Icon(Icons.restore),
													label: const Text('المجلد الافتراضي'),
													onPressed: () async {
														final path = await BackupService.getDefaultBackupPath();
														await BackupService.setAutoBackupPath(path);
														if (mounted) {
															setState(() => _backupPath = path);
															ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم استخدام المجلد الافتراضي')));
														}
													},
												),
											],
										),
									],
								),
							),
						),
						const SizedBox(height: 12),
						Card(
							shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
							child: Padding(
								padding: const EdgeInsets.all(16),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: const [
										Text('النسخ الاحتياطي والاستعادة', style: TextStyle(fontWeight: FontWeight.w700)),
										SizedBox(height: 8),
										Text('يمكنك حفظ نسخة احتياطية أو استعادة البيانات من ملف بامتداد.mosque.'),
									],
								),
							),
						),
						const SizedBox(height: 12),
						Card(
							shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
							child: Column(
								children: [
									ListTile(
										leading: const Icon(Icons.file_upload),
										title: const Text('تصدير قاعدة البيانات (.mosque)'),
										subtitle: const Text('حفظ نسخة من بياناتك في ملف يمكن نقله أو مشاركته'),
										onTap: () async {
											try {
												await BackupService.exportDatabase();
												if (context.mounted) {
													ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التصدير بنجاح')));
												}
											} catch (e) {
												if (context.mounted) {
													ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل التصدير: $e')));
												}
											}
										},
									),
									const Divider(height: 0),
									ListTile(
										leading: Icon(Icons.file_download, color: Colors.red.shade700),
										title: const Text('استيراد قاعدة بيانات (.mosque)'),
										subtitle: const Text('سيتم استبدال بياناتك الحالية بالمحتوى من الملف المحدد'),
										onTap: () async {
											final ok = await showDialog<bool>(
												context: context,
												builder: (_) => AlertDialog(
													title: const Text('استبدال البيانات الحالية؟'),
													content: const Text('سيتم استبدال قاعدة البيانات الحالية. هل تريد المتابعة؟'),
													actions: [
														TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
														FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('استيراد')),
													],
												),
											);
											if (ok != true) return;
											try {
												await BackupService.importDatabase();
												if (context.mounted) {
													ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الاستيراد بنجاح')));
												}
											} catch (e) {
												if (context.mounted) {
													ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الاستيراد: $e')));
												}
											}
										},
									),
								],
							),
						),
					],
				),
			),
		);
	}
}

