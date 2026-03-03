import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/students_cubit.dart';
import '../models/student.dart';
import '../repositories/student_repository.dart';
import '../repositories/memorization_repository.dart';
import '../models/memorized_section.dart';
import '../data/surah_names.dart';
import '../data/juz_data.dart';

import 'widgets/app_drawer.dart';

class MemorizationScreen extends StatelessWidget {
	const MemorizationScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Directionality(
            textDirection: TextDirection.rtl,
            child: BlocProvider(
                create: (_) => StudentsCubit(StudentRepository()),
                child: Scaffold(
                    appBar: AppBar(title: const Text('حفظ القرآن')),
                    drawer: const AppDrawer(),
                    body: BlocBuilder<StudentsCubit, StudentsState>(
                        builder: (context, state) {
                            if (state.loading) return const Center(child: CircularProgressIndicator());
                            if (state.students.isEmpty) {
                                return const Center(child: Text('لا يوجد طلاب'));
                            }
                            return ListView.separated(
                                itemCount: state.students.length,
                                separatorBuilder: (_, __) => const Divider(height: 0),
                                itemBuilder: (context, index) {
                                    final s = state.students[index];
                                    return ListTile(
                                        title: Text(s.name),
                                        onTap: () => _showSurahsOverview(context, s),
                                        trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                                IconButton(
                                                    tooltip: 'سجل الحفظ',
                                                    icon: const Icon(Icons.history),
                                                    onPressed: () => _showHistory(context, s),
                                                ),
                                                IconButton(
                                                    tooltip: 'إضافة حفظ',
                                                    icon: const Icon(Icons.add),
                                                    onPressed: () => _addMemorizedSection(context, s),
                                                ),
                                            ],
                                        ),
                                    );
                                },
                            );
                        },
                    ),
                ),
            ),
        );
    }
}

Future<void> _showHistory(BuildContext context, Student student) async {
    final repo = MemorizationRepository();
    final sections = await repo.listForStudent(student.id!);
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) {
            List<MemorizedSection> local = List.of(sections);
            return Directionality(
                textDirection: TextDirection.rtl,
                child: StatefulBuilder(
                    builder: (ctx, setState) {
                        return SafeArea(
                            child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                        Row(children: [
                                            Expanded(child: Text('سجل الحفظ - ${student.name}', style: Theme.of(ctx).textTheme.titleLarge)),
                                            IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                                        ]),
                                        const SizedBox(height: 8),
                                        if (local.isEmpty)
                                            Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 24),
                                                child: Center(child: Text('لا يوجد سجل حفظ لهذا الطالب')),
                                            )
                                        else
                                            DefaultTabController(
                                                length: 3,
                                                child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                        const TabBar(
                                                            tabs: [
                                                                Tab(text: 'حفظ'),
                                                                Tab(text: 'مراجعة'),
                                                                Tab(text: 'تثبيت'),
                                                            ],
                                                        ),
                                                        const SizedBox(height: 8),
                                                        SizedBox(
                                                            height: 300, // Fixed height for TabBarView
                                                            child: TabBarView(
                                                                children: [
                                                                    _MemTabList(
                                                                        items: local.where((m) => (m.label ?? 'حفظ') == 'حفظ').toList(),
                                                                        repo: repo,
                                                                        onDeleted: (id) {
                                                                            setState(() {
                                                                                final idx = local.indexWhere((x) => x.id == id);
                                                                                if (idx != -1) local.removeAt(idx);
                                                                            });
                                                                        },
                                                                    ),
                                                                    _MemTabList(
                                                                        items: local.where((m) => (m.label ?? 'حفظ') == 'مراجعة').toList(),
                                                                        repo: repo,
                                                                        onDeleted: (id) {
                                                                            setState(() {
                                                                                final idx = local.indexWhere((x) => x.id == id);
                                                                                if (idx != -1) local.removeAt(idx);
                                                                            });
                                                                        },
                                                                    ),
                                                                    _MemTabList(
                                                                        items: local.where((m) => (m.label ?? 'حفظ') == 'تثبيت').toList(),
                                                                        repo: repo,
                                                                        onDeleted: (id) {
                                                                            setState(() {
                                                                                final idx = local.indexWhere((x) => x.id == id);
                                                                                if (idx != -1) local.removeAt(idx);
                                                                            });
                                                                        },
                                                                    ),
                                                                ],
                                                            ),
                                                        ),
                                                    ],
                                                ),
                                            ),
                                    ],
                                ),
                            ),
                        );
                    },
                ),
            );
        },
    );
}

/// Merges overlapping/adjacent ayah ranges. E.g. [2-3], [3-5], [8-10] -> [2-5], [8-10].
List<({int from, int to})> _mergeRanges(List<({int from, int to})> ranges) {
    if (ranges.isEmpty) return [];
    final sorted = List<({int from, int to})>.from(ranges)..sort((a, b) => a.from.compareTo(b.from));
    final merged = <({int from, int to})>[sorted.first];
    for (int i = 1; i < sorted.length; i++) {
        final cur = sorted[i];
        final last = merged.last;
        if (cur.from <= last.to + 1) {
            merged[merged.length - 1] = (from: last.from, to: cur.to > last.to ? cur.to : last.to);
        } else {
            merged.add(cur);
        }
    }
    return merged;
}

Future<void> _showSurahsOverview(BuildContext context, Student student) async {
    final repo = MemorizationRepository();
    final sections = await repo.listForStudent(student.id!);
    // Group by surah, merge ranges, then split by juz
    final Map<int, List<({int from, int to})>> bySurah = {};
    for (final m in sections) {
        bySurah.putIfAbsent(m.surahIndex, () => []).add((from: m.ayahFrom, to: m.ayahTo));
    }
    final consolidated = <int, List<({int from, int to})>>{};
    for (final e in bySurah.entries) {
        consolidated[e.key] = _mergeRanges(e.value);
    }
    // Group by juz: juz -> [(surahIndex, ranges)]
    final Map<int, Map<int, List<({int from, int to})>>> byJuz = {};
    for (final e in consolidated.entries) {
        for (final r in e.value) {
            for (final seg in splitRangeByJuz(e.key, r.from, r.to)) {
                byJuz.putIfAbsent(seg.juz, () => {});
                final juzSurahs = byJuz[seg.juz]!;
                juzSurahs.putIfAbsent(e.key, () => []).add((from: seg.from, to: seg.to));
            }
        }
    }
    // Merge overlapping ranges within each surah per juz
    for (final juzSurahs in byJuz.values) {
        for (final surah in juzSurahs.keys.toList()) {
            juzSurahs[surah] = _mergeRanges(juzSurahs[surah]!);
        }
    }
    final juzIndices = byJuz.keys.toList()..sort();

    if (!context.mounted) return;
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) {
            return Directionality(
                textDirection: TextDirection.rtl,
                child: SafeArea(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                                Row(children: [
                                    Expanded(
                                        child: Text(
                                            'السور المحفوظة - ${student.name}',
                                            style: Theme.of(ctx).textTheme.titleLarge,
                                        ),
                                    ),
                                    IconButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        icon: const Icon(Icons.close),
                                    ),
                                ]),
                                const SizedBox(height: 8),
                                if (juzIndices.isEmpty)
                                    const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 24),
                                        child: Center(child: Text('لا توجد سور محفوظة')),
                                    )
                                else
                                    ConstrainedBox(
                                        constraints: const BoxConstraints(maxHeight: 500),
                                        child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: juzIndices.length,
                                            itemBuilder: (_, i) {
                                                final juz = juzIndices[i];
                                                final surahs = byJuz[juz]!;
                                                final surahKeys = surahs.keys.toList()..sort();
                                                return ExpansionTile(
                                                    title: Text('الجزء $juz'),
                                                    children: surahKeys.map((idx) {
                                                        final ranges = surahs[idx]!;
                                                        final rangeStr = ranges
                                                            .map((r) => r.from == r.to ? '${r.from}' : '${r.from} - ${r.to}')
                                                            .join(' ، ');
                                                        return ListTile(
                                                            dense: true,
                                                            leading: CircleAvatar(child: Text('$idx')),
                                                            title: Text(surahNameByIndex(idx)),
                                                            subtitle: Text('الآيات: $rangeStr'),
                                                        );
                                                    }).toList(),
                                                );
                                            },
                                        ),
                                    ),
                            ],
                        ),
                    ),
                ),
            );
        },
    );
}

Future<void> _addMemorizedSection(BuildContext context, Student student) async {
    final result = await _promptMemorization(context);
    if (result == null) return;
    final repo = MemorizationRepository();
    String toIsoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    await repo.insert(MemorizedSection(
        studentId: student.id!,
        surahIndex: result.surahIndex,
        ayahFrom: result.ayahFrom,
        ayahTo: result.ayahTo,
        createdAt: DateTime.now().toIso8601String(),
        memorizedOn: toIsoDate(result.date),
        label: result.label,
    ));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة الحفظ')));
}

class _MemResult {
    final int surahIndex;
    final int ayahFrom;
    final int ayahTo;
    final DateTime date;
    final String? label; // حفظ / مراجعة / تثبيت
    _MemResult(this.surahIndex, this.ayahFrom, this.ayahTo, this.date, this.label);
}

Future<_MemResult?> _promptMemorization(BuildContext context) async {
    int surahIndex = 1;
    final fromController = TextEditingController();
    final toController = TextEditingController();
    DateTime date = DateTime.now();
    String? label;

    String? _validate() {
        final f = int.tryParse(fromController.text.trim());
        final t = int.tryParse(toController.text.trim());
        if (f == null || t == null) return 'الرجاء إدخال أرقام صحيحة';
        if (f < 1 || t < 1) return 'الأرقام يجب أن تكون 1 أو أكبر';
        if (f > t) return 'بداية المقطع يجب أن تكون قبل النهاية';
        final maxAyah = maxAyahsOfSurah(surahIndex);
        if (maxAyah > 0 && (t > maxAyah || f > maxAyah)) {
            return 'آخر آية في ${surahNameByIndex(surahIndex)} هي ${maxAyah}';
        }
        return null;
    }

    return showDialog<_MemResult>(
        context: context,
        builder: (ctx) {
            return Directionality(
                textDirection: TextDirection.rtl,
                child: StatefulBuilder(
                    builder: (ctx, setState) {
                        String dateStr() => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                        return AlertDialog(
                            title: const Text('إضافة حفظ جديد'),
                            content: SingleChildScrollView(
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        InkWell(
                                            onTap: () async {
                                                final picked = await showDatePicker(
                                                    context: context,
                                                    firstDate: DateTime(2000, 1, 1),
                                                    lastDate: DateTime.now(),
                                                    initialDate: date,
                                                );
                                                if (picked != null) setState(() => date = picked);
                                            },
                                            child: InputDecorator(
                                                decoration: const InputDecoration(labelText: 'تاريخ الحفظ'),
                                                child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                        Text(dateStr(), textDirection: TextDirection.ltr, textAlign: TextAlign.left),
                                                        const Icon(Icons.calendar_today),
                                                    ],
                                                ),
                                            ),
                                        ),
                                        const SizedBox(height: 8),
                                        InkWell(
                                            onTap: () async {
                                                final picked = await _pickSurahIndex(context, surahIndex);
                                                if (picked != null) setState(() => surahIndex = picked);
                                            },
                                            child: InputDecorator(
                                                decoration: const InputDecoration(labelText: 'السورة'),
                                                child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                        Expanded(child: Text('$surahIndex - ${surahNameByIndex(surahIndex)}', overflow: TextOverflow.ellipsis)),
                                                        const Icon(Icons.search),
                                                    ],
                                                ),
                                            ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                            controller: fromController,
                                            decoration: const InputDecoration(labelText: 'من الآية'),
                                            keyboardType: TextInputType.number,
                                            textDirection: TextDirection.ltr,
                                            textAlign: TextAlign.left,
                                        ),
                                        TextField(
                                            controller: toController,
                                            decoration: const InputDecoration(labelText: 'إلى الآية'),
                                            keyboardType: TextInputType.number,
                                            textDirection: TextDirection.ltr,
                                            textAlign: TextAlign.left,
                                        ),
                                        const SizedBox(height: 8),
                                        OutlinedButton.icon(
                                            onPressed: () {
                                                final maxAyah = maxAyahsOfSurah(surahIndex);
                                                if (maxAyah > 0) {
                                                    setState(() {
                                                        fromController.text = '1';
                                                        toController.text = maxAyah.toString();
                                                    });
                                                }
                                            },
                                            icon: const Icon(Icons.auto_fix_high),
                                            label: const Text('السورة كاملة'),
                                        ),
                                        const SizedBox(height: 8),
                                        InputDecorator(
                                            decoration: const InputDecoration(labelText: 'النوع'),
                                            child: Wrap(
                                                spacing: 8,
                                                children: [
                                                    ChoiceChip(
                                                        label: const Text('حفظ'),
                                                        selected: (label ?? 'حفظ') == 'حفظ',
                                                        onSelected: (_) => setState(() => label = 'حفظ'),
                                                    ),
                                                    ChoiceChip(
                                                        label: const Text('مراجعة'),
                                                        selected: label == 'مراجعة',
                                                        onSelected: (_) => setState(() => label = 'مراجعة'),
                                                    ),
                                                    ChoiceChip(
                                                        label: const Text('تثبيت'),
                                                        selected: label == 'تثبيت',
                                                        onSelected: (_) => setState(() => label = 'تثبيت'),
                                                    ),
                                                ],
                                            ),
                                        ),
                                    ],
                                ),
                            ),
                            actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                                TextButton(
                                    onPressed: () {
                                        final err = _validate();
                                        if (err != null) {
                                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(err)));
                                            return;
                                        }
                                        Navigator.pop(ctx, _MemResult(
                                            surahIndex,
                                            int.parse(fromController.text.trim()),
                                            int.parse(toController.text.trim()),
									DateTime(date.year, date.month, date.day),
                                            label ?? 'حفظ',
                                        ));
                                    },
                                    child: const Text('حفظ'),
                                ),
                            ],
                        );
                    },
                ),
            );
        },
    );
}

Future<int?> _pickSurahIndex(BuildContext context, int initial) async {
    final controller = TextEditingController();
    int? result;
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) {
            String query = '';
            return Directionality(
                textDirection: TextDirection.rtl,
                child: StatefulBuilder(
                    builder: (ctx, setState) {
                        final items = <Map<String, dynamic>>[
                            for (int i = 1; i <= kSurahNames.length; i++) {'i': i, 'name': surahNameByIndex(i)}
                        ].where((e) {
                            if (query.trim().isEmpty) return true;
                            final q = query.trim();
                            return e['name'].toString().contains(q) || e['i'].toString().contains(q);
                        }).toList();
                        return SafeArea(
                            child: Padding(
                                padding: EdgeInsets.only(
                                    bottom: MediaQuery.of(ctx).viewInsets.bottom,
                                    left: 16, right: 16, top: 12,
                                ),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        Container(
                                            width: 40,
                                            height: 4,
                                            margin: const EdgeInsets.only(bottom: 12),
                                            decoration: BoxDecoration(color: Theme.of(ctx).dividerColor, borderRadius: BorderRadius.circular(2)),
                                        ),
                                        TextField(
                                            controller: controller,
                                            autofocus: true,
                                            decoration: const InputDecoration(labelText: 'ابحث باسم السورة أو رقمها'),
                                            onChanged: (v) => setState(() => query = v),
                                        ),
                                        const SizedBox(height: 8),
                                        Flexible(
                                            child: ListView.builder(
                                                shrinkWrap: true,
                                                itemCount: items.length,
                                                itemBuilder: (_, idx) {
                                                    final e = items[idx];
                                                    final i = e['i'] as int;
                                                    final name = e['name'] as String;
                                                    final selected = i == initial;
                                                    return ListTile(
                                                        leading: CircleAvatar(child: Text('$i')),
                                                        title: Text(name),
                                                        trailing: selected ? const Icon(Icons.check) : null,
                                                        onTap: () {
                                                            result = i;
                                                            Navigator.pop(ctx);
                                                        },
                                                    );
                                                },
                                            ),
                                        ),
                                    ],
                                ),
                            ),
                        );
                    },
                ),
            );
        },
    );
    return result ?? initial;
}


class _MemTabList extends StatelessWidget {
    final List<MemorizedSection> items;
    final MemorizationRepository repo;
    final void Function(int id) onDeleted;
    const _MemTabList({required this.items, required this.repo, required this.onDeleted});

    @override
    Widget build(BuildContext context) {
        if (items.isEmpty) {
            return const Center(child: Text('لا توجد سجلات'));
        }
        return ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (_, i) {
                final m = items[i];
                final dateText = (m.memorizedOn ?? (m.createdAt.length >= 10 ? m.createdAt.substring(0, 10) : m.createdAt));
                return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                        leading: CircleAvatar(child: Text('${m.surahIndex}')),
                        title: Text(surahNameByIndex(m.surahIndex)),
                        subtitle: Text('من الآية ${m.ayahFrom} إلى الآية ${m.ayahTo} • التاريخ: $dateText'),
                        trailing: IconButton(
                            tooltip: 'حذف',
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                                final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (dCtx) => AlertDialog(
                                        title: const Text('تأكيد الحذف'),
                                        content: const Text('هل تريد حذف هذا السجل؟'),
                                        actions: [
                                            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('إلغاء')),
                                            TextButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('حذف')),
                                        ],
                                    ),
                                );
                                if (confirm != true) return;
                                try {
                                    await repo.delete(m.id!);
                                    onDeleted(m.id!);
                                    // ignore: use_build_context_synchronously
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحذف')));
                                } catch (_) {
                                    // ignore: use_build_context_synchronously
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر الحذف')));
                                }
                            },
                        ),
                    ),
                );
            },
        );
    }
}


