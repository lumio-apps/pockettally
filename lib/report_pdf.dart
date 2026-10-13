import 'dart:typed_data';
import 'dart:ui' show Locale;

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'app_state.dart';
import 'l10n/l10n.dart';
import 'models.dart';
import 'pdf_text.dart';
import 'report_options.dart';
import 'utils/save_file.dart';

/// Builds a PDF report with what the user chose (period, entries,
/// categories, sections), in the app's language, and saves it where the
/// user chooses. Made entirely on the device, nothing is uploaded.
class ReportPdf {
  static const _brand = PdfColor.fromInt(0xFF1565FF);
  static const _incomeColor = PdfColor.fromInt(0xFF1E9E63);
  static const _expenseColor = PdfColor.fromInt(0xFFE5533D);
  static const _muted = PdfColor.fromInt(0xFF64748B);
  static const _fill = PdfColor.fromInt(0xFFF1F5FD);
  static const _headerFill = PdfColor.fromInt(0xFFE3ECFF);
  static const _line = PdfColor.fromInt(0xFFE2E8F0);

  /// Width of the text area of an A4 page with 36 pt margins.
  static const double _width = 595.28 - 72;

  /// Returns false if the user cancelled the save dialog.
  static Future<bool> saveReport({
    required AppState state,
    required ReportOptions options,
    required String periodLabel,
  }) async {
    final l = lookupAppLocalizations(Locale(state.languageCode));
    final bytes =
        await build(state: state, options: options, periodLabel: periodLabel);
    String day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final last = DateTime(options.end.year, options.end.month, options.end.day - 1);
    final name = day(options.start) == day(last)
        ? day(options.start)
        : '${day(options.start)}_${day(last)}';
    return saveBytesAs(
      dialogTitle: l.savePdfTitle,
      fileName: 'pockettally-report-$name.pdf',
      bytes: bytes,
    );
  }

  static Future<Uint8List> build({
    required AppState state,
    required ReportOptions options,
    required String periodLabel,
  }) async {
    final lang = state.languageCode;
    final l = lookupAppLocalizations(Locale(lang));
    final rtl = lang == 'ar' || lang == 'ur';
    final tx = PdfText(rtl: rtl);
    String cat(String name) => categoryLabel(l, name);
    // Month names in the report's language (safe to call more than once).
    await initializeDateFormatting(lang);

    // The PDF's own font for Latin, Cyrillic, Armenian…; other scripts are
    // drawn by PdfText.
    final base =
        pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
    final bold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));
    pw.MemoryImage? logo;
    try {
      final data = await rootBundle.load('assets/icon/logo_light.png');
      logo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      logo = null;
    }

    final entries = options.pick(state.entries);
    // The currency code (INR, AMD…) instead of the symbol, because a few
    // symbols are missing from most fonts.
    String m(int minor) =>
        state.formatMoney(minor, symbol: state.currency.code);

    final income = AppState.sumIncome(entries);
    final expense = AppState.sumExpense(entries);

    // ---- building blocks ----

    Future<pw.Widget> section(String title) async => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 20, bottom: 8),
          child: await tx.text(title, size: 13, bold: true, color: _brand),
        );

    pw.Widget money(int minor, {PdfColor? color, bool strong = false, String sign = ''}) =>
        pw.Text(
          '$sign${m(minor)}',
          textDirection: pw.TextDirection.ltr,
          textAlign: rtl ? pw.TextAlign.left : pw.TextAlign.right,
          style: pw.TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        );

    pw.Widget cell(pw.Widget child, {bool end = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          child: pw.Align(
            alignment: end != rtl
                ? pw.Alignment.centerRight
                : pw.Alignment.centerLeft,
            child: child,
          ),
        );

    /// A table with a colored header row and thin lines between rows.
    pw.Widget table(
      List<double> widths,
      List<pw.Widget> header,
      List<List<pw.Widget>> rows, {
      Set<int> endColumns = const {},
    }) {
      pw.TableRow row(List<pw.Widget> cells, {PdfColor? fill}) => pw.TableRow(
            decoration: fill == null ? null : pw.BoxDecoration(color: fill),
            children: [
              for (var i = 0; i < cells.length; i++)
                cell(cells[i], end: endColumns.contains(i)),
            ],
          );
      return pw.Table(
        columnWidths: {
          for (var i = 0; i < widths.length; i++)
            i: pw.FixedColumnWidth(widths[i]),
        },
        border: const pw.TableBorder(
          horizontalInside: pw.BorderSide(color: _line, width: 0.5),
        ),
        children: [
          row(header, fill: _headerFill),
          for (final r in rows) row(r),
        ],
      );
    }

    Future<pw.Widget> head(String text) => tx.text(text, bold: true, size: 9.5);

    // ---- title ----

    final typeLabel = switch (options.type) {
      ReportType.all => l.all,
      ReportType.expenses => l.expenses,
      ReportType.income => l.income,
    };
    final cats = options.categories;
    final filterLabel = [
      typeLabel,
      cats == null ? l.allCategories : (cats.map(cat).toList()..sort()).join(', '),
    ].join(' · ');

    final body = <pw.Widget>[
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logo != null) ...[
            pw.Image(logo, width: 40, height: 40),
            pw.SizedBox(width: 12),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: rtl
                  ? pw.CrossAxisAlignment.end
                  : pw.CrossAxisAlignment.start,
              children: [
                await tx.text(l.pdfTitle, size: 20, bold: true, color: _brand),
                pw.SizedBox(height: 2),
                await tx.text(
                  state.userName.isEmpty
                      ? periodLabel
                      : '$periodLabel · ${state.userName}',
                  size: 12,
                  maxWidth: _width - 60,
                ),
                await tx.text(filterLabel,
                    size: 9, color: _muted, maxWidth: _width - 60),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Container(height: 2, color: _brand),
      pw.SizedBox(height: 4),
      await tx.text(
          l.pdfCreated(DateFormat.yMMMd(lang).add_Hm().format(DateTime.now())),
          size: 8.5,
          color: _muted),
    ];

    // ---- summary ----

    if (options.has(ReportSection.summary)) {
      Future<pw.Widget> box(String label, int amount, PdfColor color) async =>
          pw.Expanded(
            child: pw.Container(
              margin: const pw.EdgeInsets.symmetric(horizontal: 3),
              padding: const pw.EdgeInsets.all(10),
              decoration: const pw.BoxDecoration(
                color: _fill,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: rtl
                    ? pw.CrossAxisAlignment.end
                    : pw.CrossAxisAlignment.start,
                children: [
                  await tx.text(label, size: 9, color: _muted),
                  pw.SizedBox(height: 3),
                  pw.Text(m(amount),
                      textDirection: pw.TextDirection.ltr,
                      style: pw.TextStyle(
                          fontSize: 11.5,
                          fontWeight: pw.FontWeight.bold,
                          color: color)),
                ],
              ),
            ),
          );
      body.add(await section(l.pdfSummary));
      body.add(pw.Row(children: [
        if (options.type != ReportType.expenses)
          await box(l.income, income, _incomeColor),
        if (options.type != ReportType.income)
          await box(l.expenses, expense, _expenseColor),
        if (options.type == ReportType.all)
          await box(l.balance, income - expense,
              income >= expense ? PdfColors.black : _expenseColor),
      ]));
    }

    // ---- by category ----

    final showIncomeCategories = options.type == ReportType.income;
    final byCategory = <String, int>{};
    for (final e in entries) {
      if (e.isIncome != showIncomeCategories) continue;
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amountMinor;
    }
    final categoryRows = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final categoryTotal = categoryRows.fold<int>(0, (s, r) => s + r.value);

    if (options.has(ReportSection.categories) && categoryRows.isNotEmpty) {
      body.add(await section(showIncomeCategories
          ? l.pdfIncomeByCategory
          : l.pdfExpensesByCategory));
      final biggest = categoryRows.first.value;
      for (final r in categoryRows) {
        final share = r.value / categoryTotal * 100;
        body.add(pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
            children: [
              pw.SizedBox(
                width: 120,
                child: await tx.text(cat(r.key), size: 10, maxWidth: 120),
              ),
              pw.Expanded(
                child: pw.Align(
                  alignment: rtl
                      ? pw.Alignment.centerRight
                      : pw.Alignment.centerLeft,
                  child: pw.Container(
                    width: 220 * r.value / biggest + 2,
                    height: 8,
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(
                          state.colorFor(r.key, showIncomeCategories
                                  ? EntryType.income
                                  : EntryType.expense)
                              .toARGB32()),
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                  ),
                ),
              ),
              pw.SizedBox(
                width: 46,
                child: pw.Text('${share.toStringAsFixed(share < 10 ? 1 : 0)}%',
                    textDirection: pw.TextDirection.ltr,
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(fontSize: 9, color: _muted)),
              ),
              pw.SizedBox(width: 100, child: money(r.value)),
            ],
          ),
        ));
      }
    }

    // ---- budget (one whole month, expenses) ----

    if (options.has(ReportSection.budget) &&
        options.isWholeMonth &&
        options.type != ReportType.income) {
      final rows = <List<pw.Widget>>[];
      Future<void> budgetRow(String name, int spent, int limit) async {
        final left = limit - spent;
        rows.add([
          await tx.text(name, maxWidth: _width - 3 * 111 - 12),
          money(spent),
          money(limit),
          money(left.abs(),
              color: left < 0 ? _expenseColor : _incomeColor,
              sign: left < 0 ? '-' : ''),
        ]);
      }

      final limit = state.monthlyLimitFor(options.start);
      if (limit > 0 && cats == null) {
        await budgetRow(
            l.monthlyBudget, state.expenseIn(options.start), limit);
      }
      for (final c in state.budgetedCategories) {
        if (cats != null && !cats.contains(c.name)) continue;
        await budgetRow(cat(c.name),
            state.expenseForCategory(c.name, options.start), c.budgetMinor!);
      }
      if (rows.isNotEmpty) {
        body.add(await section(l.navBudgets));
        body.add(table(
          [_width - 3 * 111, 111, 111, 111],
          [
            await head(l.category),
            await head(l.pdfSpent),
            await head(l.pdfLimit),
            await head(l.left),
          ],
          rows,
          endColumns: {1, 2, 3},
        ));
      }
    }

    // ---- month by month ----

    if (options.has(ReportSection.months) && options.spansMonths) {
      final rows = <List<pw.Widget>>[];
      var totalIn = 0;
      var totalOut = 0;
      for (final (s, e) in options.months) {
        final list = entries.where((x) => !x.date.isBefore(s) && x.date.isBefore(e));
        final inc = AppState.sumIncome(list);
        final exp = AppState.sumExpense(list);
        totalIn += inc;
        totalOut += exp;
        rows.add([
          await tx.text(DateFormat.yMMM(lang).format(s)),
          money(inc, color: _incomeColor),
          money(exp, color: _expenseColor),
          money(inc - exp, strong: true),
        ]);
      }
      rows.add([
        await tx.text(l.total, bold: true),
        money(totalIn, color: _incomeColor, strong: true),
        money(totalOut, color: _expenseColor, strong: true),
        money(totalIn - totalOut, strong: true),
      ]);
      body.add(await section(l.monthByMonth));
      body.add(table(
        [_width - 3 * 121, 121, 121, 121],
        [
          await head(l.month),
          await head(l.income),
          await head(l.expenses),
          await head(l.balance),
        ],
        rows,
        endColumns: {1, 2, 3},
      ));
    }

    // ---- all entries ----

    if (options.has(ReportSection.entries)) {
      body.add(await section(l.pdfAllEntries(entries.length.toString())));
      if (entries.isEmpty) {
        body.add(await tx.text(l.pdfNoEntries));
      } else {
        const widths = [66.0, 110.0, _width - 66 - 110 - 104, 104.0];
        final dateFmt = DateFormat.yMd(lang);
        final rows = <List<pw.Widget>>[];
        for (final e in entries) {
          final category = e.isIncome && e.period != null
              ? '${cat(e.category)} (${periodName(l, e.period!)})'
              : cat(e.category);
          final note = [
            if (e.note.isNotEmpty) e.note,
            if (e.tags.isNotEmpty) e.tags.map((t) => '#$t').join(' '),
          ].join('  ');
          rows.add([
            await tx.text(dateFmt.format(e.date),
                size: 9, maxWidth: widths[0] - 10),
            await tx.text(category, size: 9, maxWidth: widths[1] - 10),
            await tx.text(note.isEmpty ? '-' : note,
                size: 9, maxWidth: widths[2] - 10, color: _muted),
            money(e.amountMinor,
                sign: e.isIncome ? '+ ' : '- ',
                color: e.isIncome ? _incomeColor : _expenseColor),
          ]);
        }
        body.add(table(
          widths,
          [
            await head(l.date),
            await head(l.category),
            await head(l.note),
            await head(l.amount),
          ],
          rows,
          endColumns: {3},
        ));
      }
    }

    body.add(pw.SizedBox(height: 18));
    body.add(await tx.text(l.pdfFooter, size: 8.5, color: _muted, maxWidth: _width));

    final doc = pw.Document(
      title: '${l.pdfTitle} - $periodLabel',
      author: 'PocketTally',
    );
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        theme: pw.ThemeData.withFont(base: base, bold: bold),
        footer: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'PocketTally · ${ctx.pageNumber} / ${ctx.pagesCount}',
            textDirection: pw.TextDirection.ltr,
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ),
        build: (ctx) => body,
      ),
    );
    return doc.save();
  }
}
