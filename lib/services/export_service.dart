import 'dart:io';

import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/habit.dart';
import '../models/student.dart';

class ExportService {
  static Future<pw.Font> _arabicFont() async {
    // Cairo supports Arabic and is fetched from Google Fonts at runtime.
    return PdfGoogleFonts.cairoRegular();
  }

  static Future<pw.Font> _arabicFontBold() async {
    return PdfGoogleFonts.cairoBold();
  }

  // ── Totals (monthly / range) ────────────────────────────────────────────────

  static Future<void> exportTotalsPdf({
    required Map<int, int> totals,
    required List<Student> students,
    required String title,
    required String suggestedFileName,
  }) async {
    final font = await _arabicFont();
    final fontBold = await _arabicFontBold();
    final base = pw.TextStyle(font: font, fontSize: 12);
    final bold = pw.TextStyle(font: fontBold, fontSize: 12, fontWeight: pw.FontWeight.bold);

    final entries = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(title, style: bold.copyWith(fontSize: 16), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              // RTL: last index = rightmost on page.
              // Array: [النقاط, الطالب, #] → page (right→left): # | الطالب | النقاط
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(0.5),
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                  children: [
                    _cell('النقاط', bold, align: pw.TextAlign.center),
                    _cell('الطالب', bold, align: pw.TextAlign.right),
                    _cell('#', bold, align: pw.TextAlign.center),
                  ],
                ),
                // Rows
                for (var i = 0; i < entries.length; i++)
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: i.isEven ? PdfColors.grey50 : PdfColors.white,
                    ),
                    children: [
                      _cell('${entries[i].value}', base, align: pw.TextAlign.center),
                      _cell(_studentName(students, entries[i].key), base, align: pw.TextAlign.right),
                      _cell('${i + 1}', base, align: pw.TextAlign.center),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    await _save(pdf, suggestedFileName);
  }

  // ── Daily breakdown (student × habit matrix) ────────────────────────────────

  static Future<void> exportDayBreakdownPdf({
    required List<Student> students,
    required List<Habit> habits,
    required Map<int, Map<int, int>> points,
    required String dateLabel,
    required String suggestedFileName,
  }) async {
    final font = await _arabicFont();
    final fontBold = await _arabicFontBold();
    final base = pw.TextStyle(font: font, fontSize: 9);
    final bold = pw.TextStyle(font: fontBold, fontSize: 9, fontWeight: pw.FontWeight.bold);

    // Use landscape for wide tables.
    final format = habits.length > 5 ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;

    // RTL: last index = rightmost on page. Order: [المجموع, habits..., الطالب]
    // Page renders right-to-left: الطالب | habit… | المجموع
    final colWidths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(1.2),                                          // المجموع (left)
      for (var i = 0; i < habits.length; i++) i + 1: const pw.FlexColumnWidth(1),
      habits.length + 1: const pw.FlexColumnWidth(2.5),                          // الطالب (right)
    };

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: format,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text('جدول نقاط: $dateLabel', style: bold.copyWith(fontSize: 14), textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: colWidths,
              // RTL: last index = rightmost on page.
              // Array order: [المجموع, habit1…habitN, الطالب]
              // Page (right→left): الطالب | habits | المجموع
              tableWidth: pw.TableWidth.max,
              children: [
                // Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                  children: [
                    _cell('المجموع', bold, align: pw.TextAlign.center),
                    for (final h in habits) _cell(h.name, bold, align: pw.TextAlign.center),
                    _cell('الطالب', bold, align: pw.TextAlign.right),
                  ],
                ),
                // Student rows
                for (var i = 0; i < students.length; i++)
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: i.isEven ? PdfColors.grey50 : PdfColors.white,
                    ),
                    children: [
                      _cell(
                        '${(points[students[i].id]?.values ?? []).fold<int>(0, (a, b) => a + b)}',
                        bold,
                        align: pw.TextAlign.center,
                      ),
                      for (final h in habits)
                        _cell(
                          '${points[students[i].id]?[h.id] ?? 0}',
                          base,
                          align: pw.TextAlign.center,
                          color: _pointColor(points[students[i].id]?[h.id] ?? 0),
                        ),
                      _cell(students[i].name, base, align: pw.TextAlign.right),
                    ],
                  ),
                // Totals row
                if (students.isNotEmpty)
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                    children: [
                      _cell(
                        '${students.fold<int>(0, (sum, s) => sum + (points[s.id]?.values.fold<int>(0, (a, b) => a + b) ?? 0))}',
                        bold,
                        align: pw.TextAlign.center,
                      ),
                      for (final h in habits)
                        _cell(
                          '${students.fold<int>(0, (sum, s) => sum + (points[s.id]?[h.id] ?? 0))}',
                          bold,
                          align: pw.TextAlign.center,
                        ),
                      _cell('الإجمالي', bold, align: pw.TextAlign.right),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    await _save(pdf, suggestedFileName);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static pw.Widget _cell(
    String text,
    pw.TextStyle style, {
    pw.TextAlign align = pw.TextAlign.center,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: pw.Text(
        text,
        style: color != null ? style.copyWith(color: color) : style,
        textAlign: align,
      ),
    );
  }

  static PdfColor? _pointColor(int v) {
    if (v > 0) return PdfColors.green800;
    if (v < 0) return PdfColors.red800;
    return null;
  }

  static String _studentName(List<Student> students, int id) {
    try {
      return students.firstWhere((s) => s.id == id).name;
    } catch (_) {
      return '—';
    }
  }

  static Future<void> _save(pw.Document pdf, String fileName) async {
    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);

    await FlutterFileDialog.saveFile(
      params: SaveFileDialogParams(
        sourceFilePath: file.path,
        fileName: fileName,
      ),
    );
  }
}
