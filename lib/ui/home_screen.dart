import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/students_cubit.dart';
import '../repositories/student_repository.dart';
import '../services/backup_service.dart';
import 'habits_screen.dart';
import 'logs_screen.dart';
import 'memorization_screen.dart';
import 'students_screen.dart';
import 'tracking_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Tracking Points (index 2) is the default and sits in the middle.
  int _currentIndex = 2;

  late final List<_NavTab> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      _NavTab(
        label: 'الطلاب',
        icon: Icons.groups_outlined,
        activeIcon: Icons.groups,
        screen: BlocProvider(
          create: (_) => StudentsCubit(StudentRepository()),
          child: const StudentsScreen(),
        ),
      ),
      _NavTab(
        label: 'العادات',
        icon: Icons.task_alt_outlined,
        activeIcon: Icons.task_alt,
        screen: const HabitsScreen(),
      ),
      _NavTab(
        // Center (floating crescent) — no icon-row entry, uses the crescent.
        label: 'تتبع النقاط',
        icon: Icons.auto_awesome_outlined,
        activeIcon: Icons.auto_awesome,
        screen: const TrackingScreen(),
      ),
      _NavTab(
        label: 'السجل',
        icon: Icons.history_outlined,
        activeIcon: Icons.history,
        screen: const LogsScreen(),
      ),
      _NavTab(
        label: 'حفظ القرآن',
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book,
        screen: const MemorizationScreen(),
      ),
    ];
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
        body: IndexedStack(
          index: _currentIndex,
          children: _tabs.map((t) => t.screen).toList(),
        ),
        bottomNavigationBar: _CrescentBottomNav(
          tabs: _tabs,
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
        ),
      ),
    );
  }
}

// ────────────────────────── nav model ──────────────────────────

class _NavTab {
  const _NavTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.screen,
  });
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget screen;
}

// ────────────────────────── crescent bottom nav ──────────────────────────

class _CrescentBottomNav extends StatelessWidget {
  const _CrescentBottomNav({
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
  });

  final List<_NavTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const double _barHeight = 35;
  static const double _crescentSize = 60;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final selectedColor = primary;
    final unselectedColor = Colors.grey;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    Widget cell(int i) {
      final tab = tabs[i];
      final active = currentIndex == i;
      return Expanded(
        child: InkResponse(
          onTap: () => onTap(i),
          radius: 36,
          highlightShape: BoxShape.circle,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                active ? tab.activeIcon : tab.icon,
                size: 24,
                color: active ? selectedColor : unselectedColor,
              ),
              const SizedBox(height: 2),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: active ? selectedColor : unselectedColor,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.only(top: 12),
        height: _barHeight + 40,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // The bar: 4 side tabs with a spacer in the middle for the crescent.
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  cell(0),
                  cell(1),
                  const SizedBox(width: _crescentSize + 8),
                  cell(3),
                  cell(4),
                ],
              ),
            ),
            // Floating crescent center (index 2 — Tracking Points).
            Positioned(
              bottom: _barHeight / 2 - 4,
              child: _AnimatedCrescentButton(
                size: _crescentSize,
                selected: currentIndex == 2,
                primary: primary,
                onTap: () => onTap(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────── animated crescent button ──────────────────────────

class _AnimatedCrescentButton extends StatefulWidget {
  const _AnimatedCrescentButton({
    required this.size,
    required this.selected,
    required this.primary,
    required this.onTap,
  });

  final double size;
  final bool selected;
  final Color primary;
  final VoidCallback onTap;

  @override
  State<_AnimatedCrescentButton> createState() =>
      _AnimatedCrescentButtonState();
}

class _AnimatedCrescentButtonState extends State<_AnimatedCrescentButton>
    with TickerProviderStateMixin {
  late final AnimationController _selectCtrl;
  late final AnimationController _idleCtrl;

  @override
  void initState() {
    super.initState();
    _selectCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      value: widget.selected ? 1.0 : 0.0,
    );
    _idleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant _AnimatedCrescentButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      if (widget.selected) {
        _selectCtrl.forward(from: 0);
      } else {
        _selectCtrl.reverse(from: 1);
      }
    }
  }

  @override
  void dispose() {
    _selectCtrl.dispose();
    _idleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([_selectCtrl, _idleCtrl]),
          builder: (context, _) {
            final sel = _selectCtrl.value;
            final selEase = Curves.easeOutCubic.transform(sel);
            final selBounce = Curves.elasticOut.transform(sel);
            final idle = _idleCtrl.value;

            final breathing = 1.0 + 0.035 * math.sin(idle * 2 * math.pi) * sel;
            final appearScale = 0.88 + 0.12 * selBounce;

            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Twinkling stars dancing around the disc when selected.
                ..._buildSparkles(sel, idle),
                Transform.scale(
                  scale: appearScale * breathing,
                  child: _buildDisc(selEase, idle),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ────────── the moon "disc" (the rounded button container) ──────────

  Widget _buildDisc(double sel, double idle) {
    final primary = widget.primary;
    final bgTop = Color.lerp(Colors.white, primary, sel)!;
    final bgBottom =
        Color.lerp(Colors.grey.shade100, primary.withValues(alpha: 0.82), sel)!;
    final borderColor =
        Color.lerp(Colors.grey.shade300, primary.withValues(alpha: 0.35), sel)!;
    final glow = Color.lerp(Colors.black26, primary, sel)!;

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bgTop, bgBottom],
        ),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.25 + 0.2 * sel),
            blurRadius: 10 + 10 * sel,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Center(child: _buildCrescentAndStar(sel, idle)),
    );
  }

  // ────────── crescent + emerging twinkling star ──────────

  Widget _buildCrescentAndStar(double sel, double idle) {
    final primary = widget.primary;

    // The crescent rocks gently when idle and "rises" to a more upright
    // classical hilal pose when selected.
    const closedAngle = -math.pi / 5;      // ~-36°  (resting, slightly tilted)
    const openAngle = -math.pi / 2.6;      // ~-69°  (rising hilal)
    final pose = closedAngle + (openAngle - closedAngle) * sel;
    final idleRock = (1 - sel) * 0.04 * math.sin(idle * 2 * math.pi);

    // Crescent color softens from grey to white as the moon "wakes".
    final crescentColor = Color.lerp(Colors.grey.shade500, Colors.white, sel)!;

    // The star fades/scales in once the crescent has begun to rise.
    final rawStarT = ((sel - 0.30) / 0.70).clamp(0.0, 1.0);
    final starT = Curves.easeOutBack.transform(rawStarT).clamp(0.0, 1.0);
    // Continuous gentle twinkle on the inner star.
    final twinkle = 0.7 + 0.3 * math.sin(idle * 4 * math.pi);

    // A faint sweep of light skims across the crescent during the rise.
    final sweepT = ((sel - 0.10) / 0.80).clamp(0.0, 1.0);
    final sweepOp = (math.sin(sweepT * math.pi) * 0.35).clamp(0.0, 1.0);

    const innerSize = 38.0;

    return SizedBox(
      width: innerSize,
      height: innerSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // The crescent moon itself.
          Transform.rotate(
            angle: pose + idleRock,
            child: CustomPaint(
              size: const Size(innerSize, innerSize),
              painter: _CrescentMoonPainter(color: crescentColor),
            ),
          ),
          // Faint shimmering sweep across the crescent during the rise.
          if (sweepOp > 0.01)
            Positioned.fill(
              child: IgnorePointer(
                child: Transform.rotate(
                  angle: pose + idleRock,
                  child: Opacity(
                    opacity: sweepOp,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.7),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                          stops: const [0.35, 0.5, 0.65],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Twinkling inner star that appears in the crescent's cradle when active.
          if (starT > 0.01)
            Positioned(
              top: innerSize * 0.18,
              right: innerSize * 0.18,
              child: IgnorePointer(
                child: Opacity(
                  opacity: (starT * twinkle).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.55 + 0.45 * starT,
                    child: Icon(
                      Icons.star_rounded,
                      size: 12,
                      color: const Color(0xFFFFE9A8),
                      shadows: [
                        Shadow(
                          color: primary.withValues(alpha: 0.55 * twinkle),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ────────── orbital sparkles (stars dancing around the disc) ──────────

  List<Widget> _buildSparkles(double sel, double idle) {
    if (sel <= 0.01) return const [];
    const count = 5;
    final center = widget.size / 2;
    final baseRadius = widget.size * 0.58;

    return List<Widget>.generate(count, (i) {
      final phase = idle * 2 * math.pi + i * (2 * math.pi / count);
      final radius = baseRadius + 3 * math.sin(phase * 2);
      final dx = math.cos(phase) * radius;
      final dy = math.sin(phase) * radius;
      final twinkle = 0.5 + 0.5 * math.sin(phase * 2 + i);
      final opacity = (sel * (0.35 + 0.65 * twinkle)).clamp(0.0, 1.0);
      final dotSize = 4.0 + 2.5 * twinkle;

      return Positioned(
        left: center + dx - dotSize / 2,
        top: center + dy - dotSize / 2,
        child: IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.primary,
                boxShadow: [
                  BoxShadow(
                    color: widget.primary.withValues(alpha: 0.6),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

// ────────────────────────── crescent painter ──────────────────────────

/// Paints a hilāl as the difference of two offset circles, sized to fit the
/// supplied [size]. The crescent in its untransformed orientation opens to the
/// upper-right; the parent rotates it for the rising/resting poses.
class _CrescentMoonPainter extends CustomPainter {
  _CrescentMoonPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2 * 0.82;
    final center = Offset(size.width / 2, size.height / 2);

    final outer = Path()..addOval(Rect.fromCircle(center: center, radius: r));
    final inner = Path()
      ..addOval(Rect.fromCircle(
        center: Offset(center.dx + r * 0.42, center.dy - r * 0.06),
        radius: r * 0.88,
      ));
    final crescent = Path.combine(PathOperation.difference, outer, inner);

    canvas.drawPath(crescent, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CrescentMoonPainter old) => old.color != color;
}
