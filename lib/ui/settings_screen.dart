import 'package:flutter/material.dart';

import '../services/backup_service.dart';
import 'widgets/app_drawer.dart';

class SettingsScreen extends StatefulWidget {
	const SettingsScreen({super.key});

	@override
	State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
	String _backupPath = '';

	@override
	void initState() {
		super.initState();
		_loadBackupPath();
	}

	Future<void> _loadBackupPath() async {
		final path = await BackupService.getAutoBackupPath();
		if (mounted) setState(() => _backupPath = path);
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

