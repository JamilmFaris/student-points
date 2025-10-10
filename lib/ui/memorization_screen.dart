import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/students_cubit.dart';
import '../models/student.dart';
import '../repositories/student_repository.dart';
import '../repositories/memorization_repository.dart';
import '../models/memorized_section.dart';
import '../data/surah_names.dart';

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
                                        onTap: () => _showHistory(context, s),
                                        trailing: IconButton(
                                            tooltip: 'إضافة حفظ',
                                            icon: const Icon(Icons.add),
                                            onPressed: () => _addMemorizedSection(context, s),
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
                                            Flexible(
                                                child: ListView.builder(
                                                    shrinkWrap: true,
                                                    itemCount: local.length,
                                                    itemBuilder: (_, i) {
                                                        final m = local[i];
                                                        return Card(
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                            margin: const EdgeInsets.symmetric(vertical: 6),
                                                            child: ListTile(
                                                                leading: CircleAvatar(child: Text('${m.surahIndex}')),
                                                                title: Text(surahNameByIndex(m.surahIndex)),
                                                                subtitle: Text('التاريخ: ${((m.memorizedOn ?? (m.createdAt.length >= 10 ? m.createdAt.substring(0, 10) : m.createdAt)))} • من الآية ${m.ayahFrom} إلى الآية ${m.ayahTo}'),
                                                                trailing: IconButton(
                                                                    tooltip: 'حذف',
                                                                    icon: const Icon(Icons.delete),
                                                                    onPressed: () async {
                                                                        final confirm = await showDialog<bool>(
                                                                            context: ctx,
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
                                                                            setState(() => local.removeAt(i));
                                                                            // ignore: use_build_context_synchronously
                                                                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('تم الحذف')));
                                                                        } catch (_) {
                                                                            // ignore: use_build_context_synchronously
                                                                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('تعذر الحذف')));
                                                                        }
                                                                    },
                                                                ),
                                                            ),
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
    ));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة الحفظ')));
}

class _MemResult {
    final int surahIndex;
    final int ayahFrom;
    final int ayahTo;
    final DateTime date;
    _MemResult(this.surahIndex, this.ayahFrom, this.ayahTo, this.date);
}

Future<_MemResult?> _promptMemorization(BuildContext context) async {
    int surahIndex = 1;
    final fromController = TextEditingController();
    final toController = TextEditingController();
    DateTime date = DateTime.now();

    String? _validate() {
        final f = int.tryParse(fromController.text.trim());
        final t = int.tryParse(toController.text.trim());
        if (f == null || t == null) return 'الرجاء إدخال أرقام صحيحة';
        if (f < 1 || t < 1) return 'الأرقام يجب أن تكون 1 أو أكبر';
        if (f > t) return 'بداية المقطع يجب أن تكون قبل النهاية';
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


