import 'models.dart';
import 'utils/amount_parser.dart' show kMaxAmountMinor;

/// Entries as CSV, for Excel, LibreOffice or Google Sheets.
///
/// Columns: date, type, category, amount, note, tags, period
///   2026-10-03,expense,Food,12.50,Lunch,trip;work,
///   2026-10-01,income,Salary,3000.00,,,monthly
///
/// Amounts always use a dot and two decimals, whatever the app's number
/// format, so spreadsheets read them the same everywhere.
class CsvIo {
  static const header = ['date', 'type', 'category', 'amount', 'note', 'tags', 'period'];

  static String export(List<Entry> entries) {
    final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));
    final lines = <String>[header.join(',')];
    for (final e in sorted) {
      lines.add([
        _date(e.date),
        e.type.name,
        e.category,
        _amount(e.amountMinor),
        e.note,
        e.tags.join(';'),
        e.period?.name ?? '',
      ].map(_cell).join(','));
    }
    // CRLF line ends and a final newline, as spreadsheet apps expect.
    return '${lines.join('\r\n')}\r\n';
  }

  /// Reads entries from CSV text. The first row must be the header (column
  /// order may differ, extra columns are ignored). Rows that cannot be read
  /// are counted in [CsvResult.skipped].
  static CsvResult parse(String text) {
    final rows = _rows(text.startsWith('﻿') ? text.substring(1) : text)
        .where((r) => r.any((c) => c.trim().isNotEmpty))
        .toList();
    if (rows.isEmpty) throw const FormatException('empty');
    final head = rows.first.map((h) => h.trim().toLowerCase()).toList();
    int col(String name) => head.indexOf(name);
    final iDate = col('date'), iType = col('type'), iCat = col('category');
    final iAmount = col('amount'), iNote = col('note'), iTags = col('tags');
    final iPeriod = col('period');
    if (iDate < 0 || iType < 0 || iAmount < 0) {
      throw const FormatException('header');
    }

    String cell(List<String> r, int i) {
      if (i < 0 || i >= r.length) return '';
      final v = r[i].trim();
      // Undo the formula guard added by [export].
      return v.length > 1 && v[0] == "'" && '=+-@'.contains(v[1])
          ? v.substring(1)
          : v;
    }

    final entries = <Entry>[];
    var skipped = 0;
    for (final r in rows.skip(1)) {
      final date = DateTime.tryParse(cell(r, iDate));
      final typeText = cell(r, iType).toLowerCase();
      final type = typeText == 'income'
          ? EntryType.income
          : typeText == 'expense'
              ? EntryType.expense
              : null;
      final amount = _parseAmount(cell(r, iAmount));
      if (date == null || type == null || amount == null || amount == 0) {
        skipped++;
        continue;
      }
      final category = cell(r, iCat).isEmpty ? kOtherCategory : cell(r, iCat);
      final periodText = cell(r, iPeriod).toLowerCase();
      final period = type == EntryType.income
          ? IncomePeriod.values.where((p) => p.name == periodText).firstOrNull
          : null;
      entries.add(Entry(
        type: type,
        // A negative amount in a spreadsheet still means the same entry.
        amountMinor: amount.abs(),
        category: category,
        date: DateTime(date.year, date.month, date.day),
        note: cell(r, iNote),
        tags: parseTags(cell(r, iTags).replaceAll(';', ',')),
        period: period,
      ));
    }
    return CsvResult(entries, skipped);
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _amount(int minor) {
    final abs = minor.abs();
    final text = '${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
    return minor < 0 ? '-$text' : text;
  }

  /// "12.50", "12,50", "1,234.50", "1234" -> minor units.
  static int? _parseAmount(String s) {
    var t = s.replaceAll(RegExp(r"[\s '$€£¥₹]"), '');
    if (t.isEmpty) return null;
    if (t.contains(',') && t.contains('.')) {
      // The last separator is the decimal point.
      t = t.lastIndexOf(',') > t.lastIndexOf('.')
          ? t.replaceAll('.', '').replaceAll(',', '.')
          : t.replaceAll(',', '');
    } else if (t.contains(',')) {
      t = t.replaceAll(',', '.');
    }
    final v = double.tryParse(t);
    // "NaN", "Infinity" and absurd sizes: skip the row, never fail the file.
    if (v == null || !v.isFinite || v.abs() * 100 > kMaxAmountMinor) {
      return null;
    }
    return (v * 100).round();
  }

  static String _cell(String v) {
    if (v.contains(RegExp(r'[",\r\n]')) || v.startsWith(' ') || v.endsWith(' ')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    // Keep spreadsheets from running text as a formula.
    if (v.isNotEmpty && '=+-@'.contains(v[0]) && double.tryParse(v) == null) {
      return "'$v";
    }
    return v;
  }

  /// Splits CSV text into rows of cells (RFC 4180 quoting).
  static List<List<String>> _rows(String text) {
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var quoted = false;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (quoted) {
        if (c == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            quoted = false;
          }
        } else {
          cell.write(c);
        }
      } else if (c == '"') {
        quoted = true;
      } else if (c == ',') {
        row.add(cell.toString());
        cell.clear();
      } else if (c == '\n' || c == '\r') {
        if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        row.add(cell.toString());
        cell.clear();
        rows.add(row);
        row = <String>[];
      } else {
        cell.write(c);
      }
    }
    if (cell.isNotEmpty || row.isNotEmpty) {
      row.add(cell.toString());
      rows.add(row);
    }
    return rows;
  }
}

class CsvResult {
  const CsvResult(this.entries, this.skipped);

  final List<Entry> entries;

  /// Rows that were not valid entries.
  final int skipped;
}
