import 'dart:typed_data';
import 'dart:ui' show Locale;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'app_state.dart';
import 'l10n/l10n.dart';

/// Builds a PDF report of a period and saves it where the user chooses.
/// Made entirely on the phone, nothing is uploaded.
class ReportPdf {
  static const _brand = PdfColor.fromInt(0xFF1F7A63);
  static const _incomeColor = PdfColor.fromInt(0xFF23864D);
  static const _expenseColor = PdfColor.fromInt(0xFFC23A3A);
  static const _muted = PdfColor.fromInt(0xFF5A6661);
  static const _headerFill = PdfColor.fromInt(0xFFE8F0EC);

  /// Languages the bundled PDF font can write correctly. Other app
  /// languages (their scripts need text shaping or very large fonts) get an
  /// English report.
  static const _pdfLanguages = {'en', 'es', 'fr', 'pt', 'id', 'ru', 'hy'};

  static String languageFor(String appLanguage) =>
      _pdfLanguages.contains(appLanguage) ? appLanguage : 'en';

  /// Returns false if the user cancelled the save dialog.
  static Future<bool> saveReport({
    required AppState state,
    required DateTime start,
    required DateTime end,
    required String periodLabel,
  }) async {
    final l = lookupAppLocalizations(Locale(languageFor(state.languageCode)));
    final bytes = await build(
      state: state,
      start: start,
      end: end,
      periodLabel: periodLabel,
    );
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${start.year}-${two(start.month)}-${two(start.day)}';
    final path = await FilePicker.platform.saveFile(
      dialogTitle: l.savePdfTitle,
      fileName: 'pockettally-report-$stamp.pdf',
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
    final lang = languageFor(state.languageCode);
    final l = lookupAppLocalizations(Locale(lang));
    String cat(String name) => categoryLabel(l, name);
    // Month names in the report's language (safe to call more than once).
    await initializeDateFormatting(lang);

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
    String m(int minor) =>
        state.formatMoney(minor, symbol: state.currency.code);

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
    final dateFmt = DateFormat.yMMMd(lang);

    pw.Widget section(String title) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 18, bottom: 6),
          child: pw.Text(title,
              style: const pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold, color: _brand)),
        );

    final doc = pw.Document(
      title: '${l.pdfTitle} - $periodLabel',
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
            pw.Text(
                l.pdfPage(
                    ctx.pageNumber.toString(), ctx.pagesCount.toString()),
                style: small),
          ],
        ),
        build: (ctx) => [
          pw.Text(l.pdfTitle,
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
              l.pdfCreated(
                  DateFormat.yMMMd(lang).add_Hm().format(DateTime.now())),
              style: small),

          section(l.pdfSummary),
          pw.TableHelper.fromTextArray(
            data: [
              [l.income, m(income)],
              [l.expenses, m(expense)],
              [l.balance, m(balance)],
              if (isWholeMonth && budget > 0) ...[
                [l.monthlyBudget, m(budget)],
                [
                  expense > budget ? l.pdfOverBudgetBy : l.pdfLeftInBudget,
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
            section(l.pdfExpensesByCategory),
            pw.TableHelper.fromTextArray(
              headers: [l.category, l.share, l.amount],
              data: [
                for (final r in categoryRows)
                  [
                    cat(r.key),
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

          section(l.pdfAllEntries(entries.length.toString())),
          if (entries.isEmpty)
            pw.Text(l.pdfNoEntries, style: cellStyle)
          else
            pw.TableHelper.fromTextArray(
              headers: [l.date, l.category, l.note, l.amount],
              data: [
                for (final e in entries)
                  [
                    dateFmt.format(e.date),
                    e.isIncome && e.period != null
                        ? '${cat(e.category)} (${periodName(l, e.period!)})'
                        : cat(e.category),
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
          pw.Text(l.pdfFooter, style: small),
        ],
      ),
    );

    return doc.save();
  }
}