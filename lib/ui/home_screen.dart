import 'package:flutter/material.dart';

import '../services/backup_service.dart';
import 'widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
	const HomeScreen({super.key});

	@override
	State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
	@override
	void initState() {
		super.initState();
		WidgetsBinding.instance.addPostFrameCallback((_) => _initBackup(context));
	}

	Future<void> _initBackup(BuildContext context) async {
		if (!context.mounted) return;
		final hasAsked = await BackupService.hasAskedBackupPath();
		if (!hasAsked) {
			await BackupService.setAskedBackupPath();
			final choice = await showDialog<String>(
				context: context,
				barrierDismissible: false,
				builder: (ctx) => Directionality(
					textDirection: TextDirection.rtl,
					child: AlertDialog(
						title: const Text('النسخ الاحتياطي التلقائي'),
						content: const Text(
							'يرغب التطبيق في حفظ نسخة احتياطية تلقائية كل أسبوع.\n\nأين تريد حفظ ملف النسخ الاحتياطي؟',
						),
						actions: [
							TextButton(
								onPressed: () => Navigator.pop(ctx, 'default'),
								child: const Text('استخدام المجلد الافتراضي'),
							),
							FilledButton(
								onPressed: () => Navigator.pop(ctx, 'pick'),
								child: const Text('اختر مجلد'),
							),
						],
					),
				),
			);
			if (choice == 'pick') {
				final path = await BackupService.pickBackupDirectory();
				if (path != null) {
					await BackupService.setAutoBackupPath(path);
					if (context.mounted) {
						ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديد مجلد النسخ الاحتياطي')));
					}
				} else {
					final defaultPath = await BackupService.getDefaultBackupPath();
					await BackupService.setAutoBackupPath(defaultPath);
					if (context.mounted) {
						ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
							content: Text('لم يتم اختيار مجلد. سيتم استخدام المجلد الافتراضي. يمكنك تغييره من الإعدادات.'),
						));
					}
				}
			} else {
				final defaultPath = await BackupService.getDefaultBackupPath();
				await BackupService.setAutoBackupPath(defaultPath);
				if (context.mounted) {
					ScaffoldMessenger.of(context).showSnackBar(SnackBar(
						content: Text('يتم حفظ النسخ الاحتياطي في: $defaultPath'),
						duration: const Duration(seconds: 4),
					));
				}
			}
		}
		final didBackup = await BackupService.performAutoBackupIfNeeded();
		if (didBackup && context.mounted) {
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء نسخة احتياطية تلقائية')));
		}
	}

	@override
	Widget build(BuildContext context) {
		return Directionality(
			textDirection: TextDirection.rtl,
			child: Scaffold(
				appBar: AppBar(title: Center(child: const Text('السلام عليكم ورحمة الله'))),
				drawer: const AppDrawer(),
				body: SafeArea(
					child: LayoutBuilder(
						builder: (context, constraints) {
							final isWide = constraints.maxWidth >= 600;
							final crossAxisCount = isWide ? 3 : 2;
							return Padding(
								padding: const EdgeInsets.all(16),
								child: GridView.count(
									crossAxisCount: crossAxisCount,
									mainAxisSpacing: 16,
									crossAxisSpacing: 16,
									children: [
										_ActionCard(
											label: 'الطلاب',
											icon: Icons.people,
											onTap: () => Navigator.pushNamed(context, '/students'),
										),
										_ActionCard(
											label: 'العادات',
											icon: Icons.fact_check,
											onTap: () => Navigator.pushNamed(context, '/habits'),
										),
										_ActionCard(
											label: 'تتبع النقاط لليوم',
											icon: Icons.today,
											onTap: () => Navigator.pushNamed(context, '/tracking'),
										),
										_ActionCard(
											label: 'سجل النقاط',
											icon: Icons.history,
											onTap: () => Navigator.pushNamed(context, '/logs'),
										),
							_ActionCard(
								label: 'حفظ القرآن',
								icon: Icons.menu_book,
								onTap: () => Navigator.pushNamed(context, '/quran'),
							),
									],
								),
							);
						},
					),
				),
			),
		);
	}
}

class _ActionCard extends StatelessWidget {
	final String label;
	final IconData icon;
	final VoidCallback onTap;

	const _ActionCard({required this.label, required this.icon, required this.onTap});

	@override
	Widget build(BuildContext context) {
		final color = Theme.of(context).colorScheme;
		return Card(
			shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
			elevation: 2,
			child: InkWell(
				borderRadius: BorderRadius.circular(16),
				onTap: onTap,
				child: Padding(
					padding: const EdgeInsets.all(20),
					child: Column(
						mainAxisAlignment: MainAxisAlignment.center,
						children: [
							Icon(icon, size: 36, color: color.primary),
							const SizedBox(height: 12),
							Text(
								label,
								textAlign: TextAlign.center,
								style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
							),
						],
					),
				),
			),
		);
	}
}


