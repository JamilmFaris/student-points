import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bloc/students_cubit.dart';
import '../models/student.dart';
import '../models/sabr_enums.dart';
import '../models/hadith_hifz_section.dart';
import '../repositories/student_repository.dart';
import '../repositories/memorization_repository.dart';
import '../repositories/hadith_hifz_repository.dart';
import '../repositories/habit_repository.dart';
import '../repositories/tracking_repository.dart';
import '../repositories/sabr_repository.dart';
import '../services/app_mode.dart';
import '../models/memorized_section.dart';
import '../data/surah_names.dart';
import '../data/juz_data.dart';

import 'widgets/app_drawer.dart';
import 'widgets/sync_indicator.dart' show SyncIndicator;

const int kHadithCount = 42;

const _kThunderTipKey = 'memorization_thunder_tip_seen';

class MemorizationScreen extends StatefulWidget {
	const MemorizationScreen({super.key});

	@override
	State<MemorizationScreen> createState() => _MemorizationScreenState();
}

class _MemorizationScreenState extends State<MemorizationScreen> {
	final GlobalKey _thunderIconKey = GlobalKey();

	@override
	void initState() {
		super.initState();
		WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowThunderTip());
	}

	Future<void> _maybeShowThunderTip() async {
		final prefs = await SharedPreferences.getInstance();
		if (prefs.getBool(_kThunderTipKey) == true) return;
		if (!mounted) return;
		// Wait for students to load and layout to complete
		await Future.delayed(const Duration(milliseconds: 600));
		if (!mounted) return;
		await prefs.setBool(_kThunderTipKey, true);

		Rect? iconRect;
		final ctx = _thunderIconKey.currentContext;
		if (ctx != null) {
			final box = ctx.findRenderObject() as RenderBox?;
			if (box != null && box.hasSize) {
				iconRect = box.localToGlobal(Offset.zero) & box.size;
			}
		}

		if (!mounted) return;
		showDialog<void>(
			context: context,
			barrierDismissible: false,
			barrierColor: Colors.transparent,
			builder: (ctx) => _ThunderTipOverlay(
				iconRect: iconRect,
				onDismiss: () => Navigator.of(ctx).pop(),
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		return Directionality(
            textDirection: TextDirection.rtl,
            child: BlocProvider(
                create: (_) => StudentsCubit(StudentRepository()),
                child: Scaffold(
                    appBar: AppBar(
                      title: Center(child: const Text('الحفظ والسبر')),
                      actions: const [SyncIndicator()],
                    ),
					          drawer: const AppDrawer(),
                    floatingActionButton: Builder(
                        builder: (ctx) => FloatingActionButton.extended(
                            onPressed: () {
                                final students = ctx.read<StudentsCubit>().state.students;
                                _showSabrSheet(ctx, students);
                            },
                            icon: const Icon(Icons.quiz_outlined),
                            label: const Text('سبر'),
                        ),
                    ),
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
                                    final isFirst = index == 0;
                                    return ListTile(
                                        title: Text(s.name),
                                        onTap: () => _showHifzOverview(context, s),
                                        trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                                IconButton(
                                                    tooltip: 'سجل الحفظ',
                                                    icon: const Icon(Icons.history),
                                                    onPressed: () => _showHistory(context, s),
                                                ),
                                                IconButton(
                                                    tooltip: 'إضافة حفظ قرآن',
                                                    icon: Image.asset('assets/icons/quran-add.png', width: 40, height: 40),
                                                    onPressed: () => _addMemorizedSection(context, s),
                                                ),
                                                IconButton(
                                                    tooltip: 'إضافة حفظ حديث',
                                                    icon: Image.asset('assets/icons/hadith-add.png', width: 40, height: 40),
                                                    onPressed: () => _addHadithHifzSection(context, s),
                                                ),
                                                IconButton(
                                                    key: isFirst ? _thunderIconKey : null,
                                                    tooltip: 'إضافة عدة سور أو أجزاء بنقرة واحدة',
                                                    icon: const Icon(Icons.flash_on),
                                                    onPressed: () => _addMultipleMemorizedSections(context, s),
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

class _ThunderTipOverlay extends StatelessWidget {
	final Rect? iconRect;
	final VoidCallback onDismiss;

	const _ThunderTipOverlay({this.iconRect, required this.onDismiss});

	@override
	Widget build(BuildContext context) {
		return Directionality(
			textDirection: TextDirection.rtl,
			child: Material(
				color: Colors.transparent,
				child: Stack(
					fit: StackFit.expand,
					children: [
						CustomPaint(
							painter: _SpotlightPainter(iconRect),
						),
						Center(
							child: Padding(
								padding: const EdgeInsets.symmetric(horizontal: 32),
								child: Column(
									mainAxisSize: MainAxisSize.min,
									children: [
										Icon(Icons.flash_on, size: 64, color: Theme.of(context).colorScheme.primary),
										const SizedBox(height: 24),
										Row(
										  children: [
										    Text(
										    	' باستخدام أيقونة البرق',
										    	textAlign: TextAlign.center,
										    	style: Theme.of(context).textTheme.headlineMedium?.copyWith(
										    		fontWeight: FontWeight.bold,
										    		height: 1.4,color: Colors.white,
										    	),
										    ),
                                            const SizedBox(width: 4),
                                            Icon(Icons.flash_on, color: Colors.white, size: 32),
										  ],
										),
                                        Text(
										    	'إضافة عدة سور أو أجزاء بنقرة واحدةيمكنك ',
										    	textAlign: TextAlign.center,
										    	style: Theme.of(context).textTheme.headlineMedium?.copyWith(
										    		fontWeight: FontWeight.bold,
										    		height: 1.4,color: Colors.white,
										    	),
										    ),
										const SizedBox(height: 16),
										Text(
											'انظر لزر البرق بجانب كل طالب',
											textAlign: TextAlign.center,
											style: Theme.of(context).textTheme.titleMedium?.copyWith(
												color: Colors.white,
											),
										),
										const SizedBox(height: 32),
										FilledButton.icon(
											onPressed: onDismiss,
											icon: const Icon(Icons.check),
											label: const Text('فهمت'),
										),
									],
								),
							),
						),
						if (iconRect != null)
							Positioned(
								left: iconRect!.left - 12,
								top: iconRect!.top - 12,
								child: IgnorePointer(
									child: Container(
										width: iconRect!.width + 24,
										height: iconRect!.height + 24,
										decoration: BoxDecoration(
											border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3),
											borderRadius: BorderRadius.circular(12),
											boxShadow: [
												BoxShadow(
													color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
													blurRadius: 12,
													spreadRadius: 2,
												),
											],
										),
									),
								),
							),
					],
				),
			),
		);
	}
}

class _SpotlightPainter extends CustomPainter {
	final Rect? holeRect;

	_SpotlightPainter(this.holeRect);

	@override
	void paint(Canvas canvas, Size size) {
		final overlayPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
		Path holePath;
		if (holeRect != null) {
			holePath = Path()
				..addRRect(RRect.fromRectAndRadius(holeRect!.inflate(16), const Radius.circular(12)));
		} else {
			holePath = Path(); // no hole
		}
		final path = Path.combine(PathOperation.difference, overlayPath, holePath);
		canvas.drawPath(path, Paint()..color = Colors.black54);
	}

	@override
	bool shouldRepaint(covariant _SpotlightPainter old) => old.holeRect != holeRect;
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

// ── Hadith number helpers ─────────────────────────────────────────────────────

List<({int from, int to})> _mergeHadithNumbers(List<int> numbers) {
    if (numbers.isEmpty) return [];
    final deduped = numbers.toSet().toList()..sort();
    final ranges = <({int from, int to})>[];
    int start = deduped[0];
    int end = deduped[0];
    for (int i = 1; i < deduped.length; i++) {
        if (deduped[i] == end + 1) {
            end = deduped[i];
        } else {
            ranges.add((from: start, to: end));
            start = deduped[i];
            end = deduped[i];
        }
    }
    ranges.add((from: start, to: end));
    return ranges;
}

// ── Combined hifz overview (Quran + Hadith tabs) ──────────────────────────────

Future<void> _showHifzOverview(BuildContext context, Student student) async {
    final quranRepo = MemorizationRepository();
    final hadithRepo = HadithHifzRepository();
    final sections = await quranRepo.listForStudent(student.id!);
    final hadithSections = await hadithRepo.listForStudent(student.id!);

    // — Quran: same processing as before —
    final Map<int, List<({int from, int to})>> bySurah = {};
    for (final m in sections) {
        bySurah.putIfAbsent(m.surahIndex, () => []).add((from: m.ayahFrom, to: m.ayahTo));
    }
    final consolidated = <int, List<({int from, int to})>>{};
    for (final e in bySurah.entries) {
        consolidated[e.key] = _mergeRanges(e.value);
    }
    final Map<int, Map<int, List<({int from, int to})>>> byJuz = {};
    for (final e in consolidated.entries) {
        for (final r in e.value) {
            for (final seg in splitRangeByJuz(e.key, r.from, r.to)) {
                byJuz.putIfAbsent(seg.juz, () => {});
                byJuz[seg.juz]!.putIfAbsent(e.key, () => []).add((from: seg.from, to: seg.to));
            }
        }
    }
    for (final juzSurahs in byJuz.values) {
        for (final surah in juzSurahs.keys.toList()) {
            juzSurahs[surah] = _mergeRanges(juzSurahs[surah]!);
        }
    }
    final juzIndices = byJuz.keys.toList()..sort();

    // — Hadith: collect all numbers, merge into ranges —
    final allHadithNumbers = <int>[];
    for (final h in hadithSections) {
        allHadithNumbers.addAll(h.hadithNumbers);
    }
    final hadithRanges = _mergeHadithNumbers(allHadithNumbers);

    if (!context.mounted) return;
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) {
            return Directionality(
                textDirection: TextDirection.rtl,
                child: DefaultTabController(
                    length: 2,
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
                                                'الحفظ - ${student.name}',
                                                style: Theme.of(ctx).textTheme.titleLarge,
                                            ),
                                        ),
                                        IconButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            icon: const Icon(Icons.close),
                                        ),
                                    ]),
                                    const TabBar(
                                        tabs: [
                                            Tab(text: 'السور المحفوظة'),
                                            Tab(text: 'الأحاديث المحفوظة'),
                                        ],
                                    ),
                                    const SizedBox(height: 8),
                                    ConstrainedBox(
                                        constraints: const BoxConstraints(maxHeight: 480),
                                        child: TabBarView(
                                            children: [
                                                // — Quran tab —
                                                juzIndices.isEmpty
                                                    ? const Center(child: Padding(
                                                        padding: EdgeInsets.symmetric(vertical: 24),
                                                        child: Text('لا توجد سور محفوظة'),
                                                    ))
                                                    : ListView.builder(
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
                                                // — Hadith tab —
                                                hadithRanges.isEmpty
                                                    ? const Center(child: Padding(
                                                        padding: EdgeInsets.symmetric(vertical: 24),
                                                        child: Text('لا توجد أحاديث محفوظة'),
                                                    ))
                                                    : ListView(
                                                        shrinkWrap: true,
                                                        children: [
                                                            const SizedBox(height: 8),
                                                            Wrap(
                                                                spacing: 8,
                                                                runSpacing: 8,
                                                                children: hadithRanges.map((r) {
                                                                    final label = r.from == r.to
                                                                        ? 'حديث ${r.from}'
                                                                        : 'حديث ${r.from} - ${r.to}';
                                                                    return Chip(label: Text(label));
                                                                }).toList(),
                                                            ),
                                                            const SizedBox(height: 8),
                                                            Text(
                                                                'إجمالي الأحاديث المحفوظة: ${allHadithNumbers.toSet().length}',
                                                                style: Theme.of(ctx).textTheme.bodySmall,
                                                            ),
                                                        ],
                                                    ),
                                            ],
                                        ),
                                    ),
                                ],
                            ),
                        ),
                    ),
                ),
            );
        },
    );
}

// ── Add hadith hifz ───────────────────────────────────────────────────────────

Future<void> _addHadithHifzSection(BuildContext context, Student student) async {
    final selected = <int>{};
    DateTime date = DateTime.now();
    String? label = 'حفظ';
    final notesController = TextEditingController();
    int fromHadith = 1;
    int toHadith = 1;

    String toIsoDate(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) {
            return Directionality(
                textDirection: TextDirection.rtl,
                child: StatefulBuilder(
                    builder: (ctx, setState) {
                        String dateStr() => toIsoDate(date);
                        return SafeArea(
                            child: SingleChildScrollView(
                                padding: EdgeInsets.only(
                                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                                    left: 16, right: 16, top: 16,
                                ),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                        Row(children: [
                                            Expanded(child: Text('إضافة حفظ حديث - ${student.name}', style: Theme.of(ctx).textTheme.titleLarge)),
                                            IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                                        ]),
                                        const SizedBox(height: 12),
                                        InkWell(
                                            onTap: () async {
                                                final picked = await showDatePicker(
                                                    context: ctx,
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
                                                        Text(dateStr(), textDirection: TextDirection.ltr),
                                                        const Icon(Icons.calendar_today),
                                                    ],
                                                ),
                                            ),
                                        ),
                                        const SizedBox(height: 8),
                                        InputDecorator(
                                            decoration: const InputDecoration(labelText: 'النوع'),
                                            child: Wrap(
                                                spacing: 8,
                                                children: [
                                                    ChoiceChip(label: const Text('حفظ'), selected: (label ?? 'حفظ') == 'حفظ', onSelected: (_) => setState(() => label = 'حفظ')),
                                                    ChoiceChip(label: const Text('مراجعة'), selected: label == 'مراجعة', onSelected: (_) => setState(() => label = 'مراجعة')),
                                                    ChoiceChip(label: const Text('تثبيت'), selected: label == 'تثبيت', onSelected: (_) => setState(() => label = 'تثبيت')),
                                                ],
                                            ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                            controller: notesController,
                                            decoration: const InputDecoration(labelText: 'ملاحظات'),
                                            maxLines: 2,
                                        ),
                                        const SizedBox(height: 12),
                                        DefaultTabController(
                                            length: 2,
                                            child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                    const TabBar(tabs: [Tab(text: 'فردي'), Tab(text: 'نطاق')]),
                                                    const SizedBox(height: 8),
                                                    SizedBox(
                                                        height: 260,
                                                        child: TabBarView(
                                                            children: [
                                                                // — Individual selection grid —
                                                                GridView.builder(
                                                                    shrinkWrap: true,
                                                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                                                        crossAxisCount: 7,
                                                                        mainAxisSpacing: 4,
                                                                        crossAxisSpacing: 4,
                                                                        childAspectRatio: 1,
                                                                    ),
                                                                    itemCount: kHadithCount,
                                                                    itemBuilder: (_, i) {
                                                                        final n = i + 1;
                                                                        final isSel = selected.contains(n);
                                                                        return GestureDetector(
                                                                            onTap: () => setState(() {
                                                                                if (isSel) { selected.remove(n); } else { selected.add(n); }
                                                                            }),
                                                                            child: Container(
                                                                                decoration: BoxDecoration(
                                                                                    color: isSel
                                                                                        ? Theme.of(ctx).colorScheme.primary
                                                                                        : Theme.of(ctx).colorScheme.surfaceContainerHighest,
                                                                                    borderRadius: BorderRadius.circular(6),
                                                                                ),
                                                                                alignment: Alignment.center,
                                                                                child: Text(
                                                                                    '$n',
                                                                                    style: TextStyle(
                                                                                        fontWeight: FontWeight.bold,
                                                                                        color: isSel
                                                                                            ? Theme.of(ctx).colorScheme.onPrimary
                                                                                            : Theme.of(ctx).colorScheme.onSurface,
                                                                                    ),
                                                                                ),
                                                                            ),
                                                                        );
                                                                    },
                                                                ),
                                                                // — Range selection —
                                                                Column(
                                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                                    children: [
                                                                        Row(
                                                                            children: [
                                                                                Expanded(
                                                                                    child: _NumberWheelPicker(
                                                                                        initialValue: fromHadith,
                                                                                        max: kHadithCount,
                                                                                        visibleItems: 3,
                                                                                        label: 'من الحديث',
                                                                                        onChanged: (v) => fromHadith = v,
                                                                                    ),
                                                                                ),
                                                                                const SizedBox(width: 16),
                                                                                Expanded(
                                                                                    child: _NumberWheelPicker(
                                                                                        initialValue: toHadith,
                                                                                        max: kHadithCount,
                                                                                        visibleItems: 3,
                                                                                        label: 'إلى الحديث',
                                                                                        onChanged: (v) => toHadith = v,
                                                                                    ),
                                                                                ),
                                                                            ],
                                                                        ),
                                                                        const SizedBox(height: 16),
                                                                        OutlinedButton.icon(
                                                                            onPressed: () {
                                                                                final lo = fromHadith < toHadith ? fromHadith : toHadith;
                                                                                final hi = fromHadith > toHadith ? fromHadith : toHadith;
                                                                                setState(() {
                                                                                    for (int n = lo; n <= hi; n++) { selected.add(n); }
                                                                                });
                                                                            },
                                                                            icon: const Icon(Icons.check_circle_outline),
                                                                            label: const Text('تحديد النطاق'),
                                                                        ),
                                                                    ],
                                                                ),
                                                            ],
                                                        ),
                                                    ),
                                                ],
                                            ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                                Text(
                                                    'المحدد: ${selected.length} حديث',
                                                    style: Theme.of(ctx).textTheme.bodySmall,
                                                ),
                                                FilledButton.icon(
                                                    icon: const Icon(Icons.add),
                                                    label: const Text('إضافة المحدد'),
                                                    onPressed: selected.isEmpty ? null : () => Navigator.pop(ctx, true),
                                                ),
                                            ],
                                        ),
                                    ],
                                ),
                            ),
                        );
                    },
                ),
            );
        },
    ).whenComplete(() => notesController.dispose());

    if (confirmed != true || selected.isEmpty) return;

    final repo = HadithHifzRepository();
    final sortedNumbers = selected.toList()..sort();
    final memorizedOn = toIsoDate(date);
    await repo.insert(HadithHifzSection(
        studentId: student.id!,
        hadithNumbers: sortedNumbers,
        notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
        label: label ?? 'حفظ',
        date: '${memorizedOn}T12:00:00',
        createdAt: DateTime.now().toIso8601String(),
    ));

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تمت إضافة ${sortedNumbers.length} حديث')),
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
        notes: result.notes,
    ));

    String message = 'تمت إضافة الحفظ';
    if (result.points != null && result.points! > 0) {
        final habits = await HabitRepository().getAll();
        final memHabit = await AppMode.resolveMemorizationHabit(habits);
        if (memHabit != null && memHabit.id != null) {
            await TrackingRepository().addPointsForHabit(
                date: DateTime.now(),
                studentId: student.id!,
                habitId: memHabit.id!,
                points: result.points!,
            );
            message = 'تمت إضافة الحفظ ورُصدت ${result.points} نقطة في "${memHabit.name}"';
        } else {
            message =
                'تمت إضافة الحفظ، لكن لم تُرصد النقاط: أضف عادة من شاشة العادات ثم عيّنها كـ"العادة الخاصة بحفظ القرآن" في الإعدادات.';
        }
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
}

class _MemResult {
    final int surahIndex;
    final int ayahFrom;
    final int ayahTo;
    final DateTime date;
    final String? label;
    final String? notes;
    final int? points;
    _MemResult(this.surahIndex, this.ayahFrom, this.ayahTo, this.date, this.label, this.notes, this.points);
}

Future<_MemResult?> _promptMemorization(BuildContext context) async {
    int surahIndex = 1;
    final fromController = TextEditingController();
    final toController = TextEditingController();
    final notesController = TextEditingController();
    final pointsController = TextEditingController();
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
            return 'آخر آية في ${surahNameByIndex(surahIndex)} هي $maxAyah';
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
                                                        Text(dateStr(), textDirection: TextDirection.ltr),
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
                                        ),
                                        TextField(
                                            controller: toController,
                                            decoration: const InputDecoration(labelText: 'إلى الآية'),
                                            keyboardType: TextInputType.number,
                                            textDirection: TextDirection.ltr,
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
                                                    ChoiceChip(label: const Text('حفظ'), selected: (label ?? 'حفظ') == 'حفظ', onSelected: (_) => setState(() => label = 'حفظ')),
                                                    ChoiceChip(label: const Text('مراجعة'), selected: label == 'مراجعة', onSelected: (_) => setState(() => label = 'مراجعة')),
                                                    ChoiceChip(label: const Text('تثبيت'), selected: label == 'تثبيت', onSelected: (_) => setState(() => label = 'تثبيت')),
                                                ],
                                            ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                            controller: notesController,
                                            decoration: const InputDecoration(labelText: 'ملاحظات'),
                                            maxLines: 2,
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                            controller: pointsController,
                                            decoration: const InputDecoration(
                                                labelText: 'النقاط (اختياري)',
                                                helperText: 'تُضاف إلى تتبّع عادة حفظ القرآن لذلك اليوم',
                                            ),
                                            keyboardType: TextInputType.number,
                                            textDirection: TextDirection.ltr,
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
                                        final notesText = notesController.text.trim();
                                        final pointsText = pointsController.text.trim();
                                        final pointsValue = pointsText.isEmpty ? null : int.tryParse(pointsText);
                                        if (pointsText.isNotEmpty && pointsValue == null) {
                                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('الرجاء إدخال نقاط صحيحة')));
                                            return;
                                        }
                                        Navigator.pop(ctx, _MemResult(
                                            surahIndex,
                                            int.parse(fromController.text.trim()),
                                            int.parse(toController.text.trim()),
                                            DateTime(date.year, date.month, date.day),
                                            label ?? 'حفظ',
                                            notesText.isEmpty ? null : notesText,
                                            pointsValue,
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
                                        TextField(
                                            controller: controller,
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

Future<void> _addMultipleMemorizedSections(BuildContext context, Student student) async {
    final selectedSurahs = <int>{};
    final selectedJuzs = <int>{};
    DateTime date = DateTime.now();
    String? label = 'حفظ';
    final searchController = TextEditingController();
    final notesController = TextEditingController();

    final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) {
            return Directionality(
                textDirection: TextDirection.rtl,
                child: StatefulBuilder(
                    builder: (ctx, setState) {
                        final query = searchController.text.trim();
                        final surahItems = <Map<String, dynamic>>[
                            for (int i = 1; i <= kSurahNames.length; i++)
                                {'i': i, 'name': surahNameByIndex(i)}
                        ].where((e) {
                            if (query.isEmpty) return true;
                            return e['name'].toString().contains(query) || e['i'].toString().contains(query);
                        }).toList();

                        String dateStr() =>
                            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

                        final totalCount = selectedSurahs.length + selectedJuzs.length;
                        final canAdd = totalCount > 0;

                        return SafeArea(
                            child: Padding(
                                padding: EdgeInsets.only(
                                    bottom: MediaQuery.of(ctx).viewInsets.bottom,
                                    left: 16, right: 16, top: 12,
                                ),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                        Row(children: [
                                            Expanded(child: Text('إضافة حفظ - ${student.name}', style: Theme.of(ctx).textTheme.titleLarge)),
                                            IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                                        ]),
                                        const SizedBox(height: 12),
                                        InkWell(
                                            onTap: () async {
                                                final picked = await showDatePicker(
                                                    context: ctx,
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
                                                        Text(dateStr(), textDirection: TextDirection.ltr),
                                                        const Icon(Icons.calendar_today),
                                                    ],
                                                ),
                                            ),
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
                                        const SizedBox(height: 8),
                                        TextField(
                                            controller: notesController,
                                            decoration: const InputDecoration(labelText: 'ملاحظات'),
                                            maxLines: 2,
                                        ),
                                        const SizedBox(height: 12),
                                        DefaultTabController(
                                            length: 2,
                                            child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                    const TabBar(
                                                        tabs: [Tab(text: 'سور'), Tab(text: 'أجزاء')],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    SizedBox(
                                                        height: 280,
                                                        child: TabBarView(
                                                            children: [
                                                                Column(
                                                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                                                    mainAxisSize: MainAxisSize.min,
                                                                    children: [
                                                                        TextField(
                                                                            controller: searchController,
                                                                            decoration: const InputDecoration(
                                                                                labelText: 'ابحث باسم السورة أو رقمها',
                                                                                prefixIcon: Icon(Icons.search),
                                                                            ),
                                                                            onChanged: (_) => setState(() {}),
                                                                        ),
                                                                        const SizedBox(height: 4),
                                                                        Expanded(
                                                                            child: ListView.builder(
                                                                                shrinkWrap: true,
                                                                                itemCount: surahItems.length,
                                                                                itemBuilder: (_, idx) {
                                                                                    final i = surahItems[idx]['i'] as int;
                                                                                    final name = surahItems[idx]['name'] as String;
                                                                                    final isSelected = selectedSurahs.contains(i);
                                                                                    return CheckboxListTile(
                                                                                        title: Text('$i - $name'),
                                                                                        value: isSelected,
                                                                                        onChanged: (_) {
                                                                                            setState(() {
                                                                                                if (isSelected)
                                                                                                    selectedSurahs.remove(i);
                                                                                                else
                                                                                                    selectedSurahs.add(i);
                                                                                            });
                                                                                        },
                                                                                    );
                                                                                },
                                                                            ),
                                                                        ),
                                                                    ],
                                                                ),
                                                                ListView.builder(
                                                                    shrinkWrap: true,
                                                                    itemCount: 30,
                                                                    itemBuilder: (_, idx) {
                                                                        final juz = idx + 1;
                                                                        final isSelected = selectedJuzs.contains(juz);
                                                                        return CheckboxListTile(
                                                                            title: Text('الجزء $juz'),
                                                                            value: isSelected,
                                                                            onChanged: (_) {
                                                                                setState(() {
                                                                                    if (isSelected)
                                                                                        selectedJuzs.remove(juz);
                                                                                    else
                                                                                        selectedJuzs.add(juz);
                                                                                });
                                                                            },
                                                                        );
                                                                    },
                                                                ),
                                                            ],
                                                        ),
                                                    ),
                                                ],
                                            ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                                Text(
                                                    '${selectedSurahs.length} سورة ، ${selectedJuzs.length} جزء',
                                                    style: Theme.of(ctx).textTheme.bodySmall,
                                                ),
                                                FilledButton.icon(
                                                    icon: const Icon(Icons.add),
                                                    label: const Text('إضافة المحدد'),
                                                    onPressed: canAdd ? () => Navigator.pop(ctx, true) : null,
                                                ),
                                            ],
                                        ),
                                        const SizedBox(height: 16),
                                    ],
                                ),
                            ),
                        );
                    },
                ),
            );
        },
    ).whenComplete(() {
        searchController.dispose();
    });

    final notesText = notesController.text.trim();
    final notesValue = notesText.isEmpty ? null : notesText;
    notesController.dispose();

    if (result != true || (selectedSurahs.isEmpty && selectedJuzs.isEmpty)) return;

    final repo = MemorizationRepository();
    final lbl = label ?? 'حفظ';
    String toIsoDate(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final memorizedOn = toIsoDate(date);
    int added = 0;

    for (final surahIndex in selectedSurahs.toList()..sort()) {
        final maxAyah = maxAyahsOfSurah(surahIndex);
        if (maxAyah > 0) {
            await repo.insert(MemorizedSection(
                studentId: student.id!,
                surahIndex: surahIndex,
                ayahFrom: 1,
                ayahTo: maxAyah,
                createdAt: DateTime.now().toIso8601String(),
                memorizedOn: memorizedOn,
                label: lbl,
                notes: notesValue,
            ));
            added++;
        }
    }

    for (final juz in selectedJuzs.toList()..sort()) {
        for (final r in rangesForJuz(juz, maxAyahsOfSurah)) {
            await repo.insert(MemorizedSection(
                studentId: student.id!,
                surahIndex: r.surah,
                ayahFrom: r.from,
                ayahTo: r.to,
                createdAt: DateTime.now().toIso8601String(),
                memorizedOn: memorizedOn,
                label: lbl,
                notes: notesValue,
            ));
            added++;
        }
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تمت إضافة $added مقطع')),
    );
}

// ── Sabr ─────────────────────────────────────────────────────────────────────

class _SabrResult {
    final Student student;
    final SabrMainType type;
    final HadithType? hadithType;
    final List<int> range; // [from, to] for quran; empty for hadith
    const _SabrResult({
        required this.student,
        required this.type,
        this.hadithType,
        required this.range,
    });
}

Future<void> _showSabrSheet(BuildContext context, List<Student> students) async {
    if (students.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا يوجد طلاب')),
        );
        return;
    }

    Student selectedStudent = students.first;
    SabrMainType selectedType = SabrMainType.awqaf;
    HadithType selectedHadithType = HadithType.arbaeen;
    int fromJuz = 1;
    int toJuz = 1;
    int singleJuz = 1;

    final result = await showModalBottomSheet<_SabrResult>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) {
            return Directionality(
                textDirection: TextDirection.rtl,
                child: StatefulBuilder(
                    builder: (ctx, setState) {
                        final bool isRange = selectedType == SabrMainType.awqaf ||
                            selectedType == SabrMainType.mahadTarakumi;

                        return SafeArea(
                            child: SingleChildScrollView(
                                padding: EdgeInsets.only(
                                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                                    left: 16, right: 16, top: 16,
                                ),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                        Row(children: [
                                            Expanded(child: Text('إضافة سبر', style: Theme.of(ctx).textTheme.titleLarge)),
                                            IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                                        ]),
                                        const SizedBox(height: 12),
                                        DropdownButtonFormField<Student>(
                                            initialValue: selectedStudent,
                                            decoration: const InputDecoration(labelText: 'الطالب', border: OutlineInputBorder()),
                                            items: students.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                                            onChanged: (s) { if (s != null) setState(() => selectedStudent = s); },
                                        ),
                                        const SizedBox(height: 16),
                                        Text('نوع السبر', style: Theme.of(ctx).textTheme.labelLarge),
                                        const SizedBox(height: 8),
                                        Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            children: SabrMainType.values.map((t) => ChoiceChip(
                                                label: Text(t.label),
                                                selected: selectedType == t,
                                                onSelected: (_) => setState(() => selectedType = t),
                                            )).toList(),
                                        ),
                                        const SizedBox(height: 20),
                                        if (selectedType == SabrMainType.hadith) ...[
                                            DropdownButtonFormField<HadithType>(
                                                initialValue: selectedHadithType,
                                                decoration: const InputDecoration(labelText: 'نوع الحديث', border: OutlineInputBorder()),
                                                items: HadithType.values.map((h) => DropdownMenuItem(value: h, child: Text(h.label))).toList(),
                                                onChanged: (h) { if (h != null) setState(() => selectedHadithType = h); },
                                            ),
                                        ] else if (selectedType == SabrMainType.mahad) ...[
                                            Center(
                                                child: _NumberWheelPicker(
                                                    initialValue: singleJuz,
                                                    label: 'الجزء',
                                                    onChanged: (v) => singleJuz = v,
                                                ),
                                            ),
                                        ] else ...[
                                            Row(
                                                children: [
                                                    Expanded(
                                                        child: _NumberWheelPicker(
                                                            initialValue: fromJuz,
                                                            label: 'من الجزء',
                                                            onChanged: (v) => fromJuz = v,
                                                        ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                        child: _NumberWheelPicker(
                                                            initialValue: toJuz,
                                                            label: 'إلى الجزء',
                                                            onChanged: (v) => toJuz = v,
                                                        ),
                                                    ),
                                                ],
                                            ),
                                        ],
                                        const SizedBox(height: 20),
                                        FilledButton(
                                            onPressed: () async {
                                                if (isRange && fromJuz > toJuz) {
                                                    await showDialog<void>(
                                                        context: ctx,
                                                        builder: (dCtx) => AlertDialog(
                                                            title: const Text('نطاق غير صحيح'),
                                                            content: const Text('يجب أن يكون الجزء الأول أصغر من أو يساوي الجزء الثاني.'),
                                                            actions: [TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('حسناً'))],
                                                        ),
                                                    );
                                                    return;
                                                }

                                                final range = selectedType == SabrMainType.hadith
                                                    ? <int>[]
                                                    : selectedType == SabrMainType.mahad
                                                        ? [singleJuz, singleJuz]
                                                        : [fromJuz, toJuz];

                                                final repo = SabrRepository();
                                                String? validationError;
                                                if (selectedType == SabrMainType.hadith) {
                                                    validationError = await repo.validateHadithSabr(
                                                        localStudentId: selectedStudent.id!,
                                                        hadithType: selectedHadithType,
                                                    );
                                                } else if (selectedType == SabrMainType.mahad ||
                                                           selectedType == SabrMainType.mahadTarakumi ||
                                                           selectedType == SabrMainType.awqaf) {
                                                    validationError = await repo.validateQuranSabr(
                                                        localStudentId: selectedStudent.id!,
                                                        sabrType: selectedType,
                                                        range: range,
                                                    );
                                                }

                                                if (!ctx.mounted) return;
                                                if (validationError != null) {
                                                    await showDialog<void>(
                                                        context: ctx,
                                                        builder: (dCtx) => AlertDialog(
                                                            title: const Text('لا يمكن الإضافة'),
                                                            content: Text(validationError!),
                                                            actions: [TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('حسناً'))],
                                                        ),
                                                    );
                                                    return;
                                                }

                                                if (!ctx.mounted) return;
                                                Navigator.pop(ctx, _SabrResult(
                                                    student: selectedStudent,
                                                    type: selectedType,
                                                    hadithType: selectedType == SabrMainType.hadith ? selectedHadithType : null,
                                                    range: range,
                                                ));
                                            },
                                            child: const Text('إضافة السبر'),
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

    if (result == null) return;

    final repo = SabrRepository();
    try {
        if (result.type == SabrMainType.hadith) {
            await repo.createHadithSabr(
                localStudentId: result.student.id!,
                hadithType: result.hadithType!,
            );
        } else {
            await repo.createQuranSabr(
                localStudentId: result.student.id!,
                sabrType: result.type,
                range: result.range,
            );
        }
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تمت إضافة السبر بنجاح')),
        );
    } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل إضافة السبر: $e')),
        );
    }
}

// ── Number Wheel Picker ───────────────────────────────────────────────────────

class _NumberWheelPicker extends StatefulWidget {
    final int initialValue;
    final int max;
    final int visibleItems;
    final ValueChanged<int> onChanged;
    final String? label;

    const _NumberWheelPicker({
        required this.initialValue,
        this.max = 30,
        this.visibleItems = 5,
        required this.onChanged,
        this.label,
    });

    @override
    State<_NumberWheelPicker> createState() => _NumberWheelPickerState();
}

class _NumberWheelPickerState extends State<_NumberWheelPicker> {
    late final FixedExtentScrollController _ctrl;
    late int _selected;

    static const _itemExtent = 44.0;

    @override
    void initState() {
        super.initState();
        _selected = widget.initialValue.clamp(1, widget.max);
        _ctrl = FixedExtentScrollController(initialItem: _selected - 1);
    }

    @override
    void dispose() {
        _ctrl.dispose();
        super.dispose();
    }

    @override
    Widget build(BuildContext context) {
        final theme = Theme.of(context);
        final totalHeight = _itemExtent * widget.visibleItems;
        final highlightTop = (totalHeight - _itemExtent) / 2;

        return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                if (widget.label != null) ...[
                    Text(
                        widget.label!,
                        style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                        ),
                    ),
                    const SizedBox(height: 6),
                ],
                SizedBox(
                    height: totalHeight,
                    child: Stack(
                        children: [
                            // Selection highlight bar
                            Positioned(
                                left: 0, right: 0,
                                top: highlightTop,
                                height: _itemExtent,
                                child: Container(
                                    decoration: BoxDecoration(
                                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: theme.colorScheme.primary.withValues(alpha: 0.25),
                                        ),
                                    ),
                                ),
                            ),
                            // Wheel
                            ListWheelScrollView.useDelegate(
                                controller: _ctrl,
                                itemExtent: _itemExtent,
                                diameterRatio: 1.6,
                                physics: const FixedExtentScrollPhysics(),
                                onSelectedItemChanged: (index) {
                                    setState(() => _selected = index + 1);
                                    widget.onChanged(index + 1);
                                },
                                childDelegate: ListWheelChildBuilderDelegate(
                                    childCount: widget.max,
                                    builder: (_, index) {
                                        final isSelected = index + 1 == _selected;
                                        return Center(
                                            child: AnimatedDefaultTextStyle(
                                                duration: const Duration(milliseconds: 120),
                                                style: TextStyle(
                                                    fontSize: isSelected ? 22 : 16,
                                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                    color: isSelected
                                                        ? theme.colorScheme.primary
                                                        : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                                ),
                                                child: Text('${index + 1}'),
                                            ),
                                        );
                                    },
                                ),
                            ),
                            // Top fade
                            Positioned(
                                top: 0, left: 0, right: 0,
                                height: highlightTop,
                                child: IgnorePointer(
                                    child: Container(
                                        decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                    theme.colorScheme.surface,
                                                    theme.colorScheme.surface.withValues(alpha: 0),
                                                ],
                                            ),
                                        ),
                                    ),
                                ),
                            ),
                            // Bottom fade
                            Positioned(
                                bottom: 0, left: 0, right: 0,
                                height: highlightTop,
                                child: IgnorePointer(
                                    child: Container(
                                        decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                                colors: [
                                                    theme.colorScheme.surface,
                                                    theme.colorScheme.surface.withValues(alpha: 0),
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
}

// ── Memorization tab list ─────────────────────────────────────────────────────

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
                final notes = (m.notes ?? '').trim();
                return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                        leading: CircleAvatar(child: Text('${m.surahIndex}')),
                        title: Text(surahNameByIndex(m.surahIndex)),
                        subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text('من الآية ${m.ayahFrom} إلى الآية ${m.ayahTo} • التاريخ: $dateText'),
                                if (notes.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                        notes,
                                        style: const TextStyle(fontStyle: FontStyle.italic),
                                    ),
                                ],
                            ],
                        ),
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


