import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'app_state.dart';
import 'models.dart';

/// Builds a PDF report of a period and saves it where the user chooses.
/// Made entirely on the phone, nothing is uploaded.
class ReportPdf {
  static const _brand = PdfColor.fromInt(0xFF1F7A63);
  static const _incomeColor = PdfColor.fromInt(0xFF23864D);
  static const _expenseColor = PdfColor.fromInt(0xFFC23A3A);
  static const _muted = PdfColor.fromInt(0xFF5A6661);
  static const _headerFill = PdfColor.fromInt(0xFFE8F0EC);

  /// Returns false if the user cancelled the save dialog.
  static Future<bool> saveReport({
    required AppState state,
    required DateTime start,
    required DateTime end,
    required String periodLabel,
  }) async {
    final bytes = await build(
      state: state,
      start: start,
      end: end,
      periodLabel: periodLabel,
    );
    final safeLabel = periodLabel
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save PDF report',
      fileName: 'pockettally-report-$safeLabel.pdf',
      bytes: bytes,
    );
    return path != null;
  }

  static Future<Uint8List> build({
    required AppState state,
    required DateTime start,
    required DateTime end,
    required String periodLabel,
  }) async {
    // A bundled font, so the PDF can show text in many languages.
    final base =
        pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
    final bold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));

    final entries = state.entriesBetween(start, end)
      ..sort((a, b) {
        final c = a.date.compareTo(b.date);
        return c != 0 ? c : (a.id ?? 0).compareTo(b.id ?? 0);
      });

    // The currency code (INR, AMD…) instead of the symbol, because a few
    // symbols are missing from most fonts.
    final money = NumberFormat.currency(
      locale: state.currency.locale,
      symbol: '${state.currency.code} ',
      decimalDigits: 2,
    );
    String m(int minor) => money.format(minor / 100);

    final income = AppState.sumIncome(entries);
    final expense = AppState.sumExpense(entries);
    final balance = income - expense;

    final byCategory = <String, int>{};
    for (final e in entries.where((e) => !e.isIncome)) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amountMinor;
    }
    final categoryRows = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final isWholeMonth = start.day == 1 &&
        end == DateTime(start.year, start.month + 1, 1);
    final budget = state.monthlyBudgetMinor;

    const small = pw.TextStyle(fontSize: 9, color: _muted);
    const headerStyle =
        pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10);
    const cellStyle = pw.TextStyle(fontSize: 10);
    final dateFmt = DateFormat('d MMM y');

    pw.Widget section(String title) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 18, bottom: 6),
          child: pw.Text(title,
              style: const pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold, color: _brand)),
        );

    final doc = pw.Document(
      title: 'PocketTally report - $periodLabel',
      author: 'PocketTally',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        theme: pw.ThemeData.withFont(base: base, bold: bold),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('PocketTally · $periodLabel', style: small),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: small),
          ],
        ),
        build: (ctx) => [
          pw.Text('PocketTally report',
              style: const pw.TextStyle(
                  fontSize: 22, fontWeight: pw.FontWeight.bold, color: _brand)),
          pw.SizedBox(height: 4),
          pw.Text(
            state.userName.isEmpty
                ? periodLabel
                : '$periodLabel · ${state.userName}',
            style: const pw.TextStyle(fontSize: 13),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
              'Created ${DateFormat('d MMM y, HH:mm').format(DateTime.now())}',
              style: small),

          section('Summary'),
          pw.TableHelper.fromTextArray(
            data: [
              ['Income', m(income)],
              ['Expenses', m(expense)],
              ['Balance', m(balance)],
              if (isWholeMonth && budget > 0) ...[
                ['Monthly budget', m(budget)],
                [
                  expense > budget ? 'Over budget by' : 'Left in budget',
                  m((budget - expense).abs()),
                ],
              ],
            ],
            cellStyle: cellStyle,
            cellAlignments: {1: pw.Alignment.centerRight},
            border: null,
            oddRowDecoration: const pw.BoxDecoration(color: _headerFill),
          ),

          if (categoryRows.isNotEmpty) ...[
            section('Expenses by category'),
            pw.TableHelper.fromTextArray(
              headers: ['Category', 'Share', 'Amount'],
              data: [
                for (final r in categoryRows)
                  [
                    r.key,
                    '${(r.value / expense * 100).toStringAsFixed(1)}%',
                    m(r.value),
                  ],
              ],
              headerStyle: headerStyle,
              headerDecoration: const pw.BoxDecoration(color: _headerFill),
              cellStyle: cellStyle,
              cellAlignments: {
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
              },
            ),
          ],

          section('All entries (${entries.length})'),
          if (entries.isEmpty)
            pw.Text('No entries in this period.', style: cellStyle)
          else
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Category', 'Note', 'Amount'],
              data: [
                for (final e in entries)
                  [
                    dateFmt.format(e.date),
                    e.isIncome && e.period != null
                        ? '${e.category} (${_periodName(e.period!)})'
                        : e.category,
                    e.note.isEmpty ? '-' : e.note,
                    '${e.isIncome ? '+' : '-'} ${m(e.amountMinor)}',
                  ],
              ],
              headerStyle: headerStyle,
              headerDecoration: const pw.BoxDecoration(color: _headerFill),
              cellStyle: cellStyle,
              columnWidths: {
                0: const pw.FixedColumnWidth(70),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(3),
                3: const pw.FixedColumnWidth(95),
              },
              cellAlignments: {3: pw.Alignment.centerRight},
              textStyleBuilder: (index, data, rowNum) {
                if (index != 3 || rowNum == 0) return cellStyle;
                final text = data.toString();
                return cellStyle.copyWith(
                    color: text.startsWith('+') ? _incomeColor : _expenseColor);
              },
            ),
          pw.SizedBox(height: 18),
          pw.Text('Made with PocketTally. All data stays on your phone.',
              style: small),
        ],
      ),
    );

    return doc.save();
  }

  static String _periodName(IncomePeriod p) {
    switch (p) {
      case IncomePeriod.daily:
        return 'daily';
      case IncomePeriod.weekly:
        return 'weekly';
      case IncomePeriod.monthly:
        return 'monthly';
    }
  }
}