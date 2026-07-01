import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../models/student.dart';
import '../repositories/habit_repository.dart';
import '../repositories/student_repository.dart';
import '../repositories/tracking_repository.dart';
import '../services/app_mode.dart';
import 'widgets/app_drawer.dart';
import 'widgets/sync_indicator.dart' show SyncIndicator;

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  static const double _nameColWidth = 104;
  static const double _dayColWidth = 52;
  static const double _rowHeight = 48;
  static const double _headerHeight = 52;

  bool _loading = true;
  String? _message; // shown instead of the table (no habit / no data)
  List<Student> _students = const [];
  List<String> _dates = const []; // distinct tracked dates, newest first
  Map<String, Set<int>> _attendance = const {}; // date -> present student ids

  // Frozen name column + scrollable day grid, kept in sync.
  final ScrollController _bodyHCtrl = ScrollController();
  final ScrollController _headerHCtrl = ScrollController();
  final ScrollController _bodyVCtrl = ScrollController();
  final ScrollController _nameVCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _bodyHCtrl.addListener(() {
      if (_headerHCtrl.hasClients &&
          _headerHCtrl.offset != _bodyHCtrl.offset) {
        _headerHCtrl.jumpTo(_bodyHCtrl.offset);
      }
    });
    _bodyVCtrl.addListener(() {
      if (_nameVCtrl.hasClients && _nameVCtrl.offset != _bodyVCtrl.offset) {
        _nameVCtrl.jumpTo(_bodyVCtrl.offset);
      }
    });
    _load();
  }

  @override
  void dispose() {
    _bodyHCtrl.dispose();
    _headerHCtrl.dispose();
    _bodyVCtrl.dispose();
    _nameVCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final habits = await HabitRepository().getAll();
      final Habit? attHabit = await AppMode.resolveAttendanceHabit(habits);
      if (attHabit == null || attHabit.id == null) {
        setState(() {
          _loading = false;
          _message =
              'لم يتم تعيين عادة الحضور. عيّن عادة باسم "حضور" أو حدّدها من شاشة تتبع النقاط.';
        });
        return;
      }
      final students = await StudentRepository().getAll();
      final dates = await TrackingRepository().getDistinctDates();
      final attendance =
          await TrackingRepository().getAttendanceByDate(attHabit.id!);
      if (!mounted) return;
      setState(() {
        _students = students;
        _dates = dates; // newest first
        _attendance = attendance;
        _loading = false;
        _message = students.isEmpty
            ? 'لا يوجد طلاب'
            : dates.isEmpty
                ? 'لا يوجد سجل حضور بعد'
                : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'تعذّر تحميل الحضور: $e';
      });
    }
  }

  static const _weekdaysShort = {
    DateTime.saturday: 'سبت',
    DateTime.sunday: 'أحد',
    DateTime.monday: 'إثنين',
    DateTime.tuesday: 'ثلاثاء',
    DateTime.wednesday: 'أربعاء',
    DateTime.thursday: 'خميس',
    DateTime.friday: 'جمعة',
  };

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الحضور'),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
            const SyncIndicator(),
          ],
        ),
        drawer: const AppDrawer(),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _message != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_message!, textAlign: TextAlign.center),
                      ),
                    )
                  : _buildTable(),
        ),
      ),
    );
  }

  Widget _buildTable() {
    final scheme = Theme.of(context).colorScheme;
    final dates = _dates; // newest first → newest sits next to the names (RTL)
    final gridWidth = dates.length * _dayColWidth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: frozen student column + scrollable day headers.
        Row(
          children: [
            _headerCell(
              const Text('الطالب'),
              width: _nameColWidth,
              bg: scheme.primaryContainer,
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _headerHCtrl,
                physics: const NeverScrollableScrollPhysics(),
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final d in dates)
                      _headerCell(_dateHeader(d),
                          width: _dayColWidth, bg: scheme.primaryContainer),
                  ],
                ),
              ),
            ),
          ],
        ),
        // Body: frozen name column (vertical-synced) + scrollable grid.
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                controller: _nameVCtrl,
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  children: [
                    for (int i = 0; i < _students.length; i++)
                      _bodyCell(
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              _students[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        width: _nameColWidth,
                        bg: _zebra(i, scheme),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _bodyVCtrl,
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    controller: _bodyHCtrl,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: gridWidth,
                      child: Column(
                        children: [
                          for (int i = 0; i < _students.length; i++)
                            Row(
                              children: [
                                for (final d in dates)
                                  _bodyCell(
                                    _attendanceMark(
                                        _attendance[d]?.contains(_students[i].id) ?? false),
                                    width: _dayColWidth,
                                    bg: _zebra(i, scheme),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _zebra(int i, ColorScheme scheme) => i.isEven
      ? scheme.surface
      : scheme.surfaceContainerHighest.withValues(alpha: 0.35);

  Widget _dateHeader(String isoDate) {
    final d = DateTime.parse(isoDate);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _weekdaysShort[d.weekday] ?? '',
          style: const TextStyle(fontSize: 10),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${d.month}/${d.day}',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          textDirection: TextDirection.ltr,
        ),
      ],
    );
  }

  Widget _attendanceMark(bool present) {
    final scheme = Theme.of(context).colorScheme;
    return present
        ? Icon(Icons.check_circle, color: scheme.primary, size: 20)
        : Icon(Icons.remove, color: Colors.grey.shade400, size: 20);
  }

  Widget _headerCell(Widget child, {required double width, required Color bg}) {
    return Container(
      width: width,
      height: _headerHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade400),
        ),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        child: child,
      ),
    );
  }

  Widget _bodyCell(Widget child, {required double width, required Color bg}) {
    return Container(
      width: width,
      height: _rowHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: child,
    );
  }
}
