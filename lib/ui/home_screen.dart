import 'package:flutter/material.dart';

import '../services/backup_service.dart';
import 'widgets/app_drawer.dart';
import 'widgets/sync_indicator.dart' show SyncIndicator;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const List<_HomeTile> _tiles = [
    _HomeTile(label: 'تتبع النقاط', icon: Icons.today, route: '/tracking'),
    _HomeTile(label: 'الحفظ والسبر', icon: Icons.menu_book, route: '/quran'),
    _HomeTile(label: 'سجل النقاط', icon: Icons.history, route: '/logs'),
    _HomeTile(label: 'الطلاب', icon: Icons.people, route: '/students'),
    _HomeTile(label: 'العادات', icon: Icons.fact_check, route: '/habits'),
  ];

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
      if (!context.mounted) return;
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
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('تم تحديد مجلد النسخ الاحتياطي')));
          }
        } else {
          final defaultPath = await BackupService.getDefaultBackupPath();
          await BackupService.setAutoBackupPath(defaultPath);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'لم يتم اختيار مجلد. سيتم استخدام المجلد الافتراضي. يمكنك تغييره من الإعدادات.'),
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
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء نسخة احتياطية تلقائية')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الرئيسية'),
          actions: const [SyncIndicator()],
        ),
        drawer: const AppDrawer(),
        body: SafeArea(
          child: GridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.05,
            children: [
              for (final tile in _tiles)
                _HomeCard(
                  tile: tile,
                  onTap: () => Navigator.pushNamed(context, tile.route),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTile {
  const _HomeTile({
    required this.label,
    required this.icon,
    required this.route,
  });
  final String label;
  final IconData icon;
  final String route;
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({required this.tile, required this.onTap});
  final _HomeTile tile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: scheme.primaryContainer,
                child: Icon(tile.icon, size: 34, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(height: 16),
              Text(
                tile.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
