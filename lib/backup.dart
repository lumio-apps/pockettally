import 'dart:convert';

import 'models.dart';

/// Everything needed to move PocketTally to another phone.
///
/// The backup is a plain JSON file that the user saves wherever they choose.
/// The app never uploads it anywhere.
class BackupData {
  BackupData({
    required this.userName,
    required this.currencyCode,
    required this.weekStartsOnSunday,
    required this.monthlyBudgetMinor,
    required this.categories,
    required this.entries,
    DateTime? exportedAt,
  }) : exportedAt = exportedAt ?? DateTime.now();

  static const String appId = 'PocketTally';
  static const int formatVersion = 1;

  final String userName;
  final String currencyCode;
  final bool weekStartsOnSunday;
  final int monthlyBudgetMinor;
  final List<EntryCategory> categories;
  final List<Entry> entries;
  final DateTime exportedAt;

  String toJsonString() => const JsonEncoder.withIndent(' ').convert({
        'app': appId,
        'format': formatVersion,
        'exportedAt': exportedAt.toIso8601String(),
        'settings': {
          'userName': userName,
          'currency': currencyCode,
          'weekStart': weekStartsOnSunday ? 'sunday' : 'monday',
          'monthlyBudget': monthlyBudgetMinor,
        },
        'categories': [
          for (final c in categories)
            {
              'name': c.name,
              'type': c.type.name,
              'color': c.colorValue,
              'budget': c.budgetMinor,
            },
        ],
        'entries': [
          for (final e in entries)
            {
              'type': e.type.name,
              'amountMinor': e.amountMinor,
              'category': e.category,
              'date': _dateString(e.date),
              'note': e.note,
              'period': e.period?.name,
            },
        ],
      });

  /// Parses a backup file. Throws [FormatException] with a readable message
  /// when the file is not a PocketTally backup.
  static BackupData fromJsonString(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const FormatException('This file is not a valid backup.');
    }
    if (decoded is! Map<String, dynamic> || decoded['app'] != appId) {
      throw const FormatException('This file is not a PocketTally backup.');
    }
    final format = decoded['format'];
    if (format is! int || format > formatVersion) {
      throw const FormatException(
          'This backup was made by a newer version. Please update the app first.');
    }

    try {
      final settings = (decoded['settings'] as Map<String, dynamic>?) ?? {};
      final categories = [
        for (final c in (decoded['categories'] as List<dynamic>? ?? []))
          EntryCategory(
            name: (c as Map<String, dynamic>)['name'] as String,
            type: EntryType.values.byName(c['type'] as String),
            colorValue: c['color'] as int,
            budgetMinor: c['budget'] as int?,
          ),
      ];
      final entries = [
        for (final e in (decoded['entries'] as List<dynamic>? ?? []))
          Entry(
            type: EntryType.values.byName((e as Map<String, dynamic>)['type'] as String),
            amountMinor: e['amountMinor'] as int,
            category: e['category'] as String,
            date: DateTime.parse(e['date'] as String),
            note: (e['note'] as String?) ?? '',
            period: e['period'] == null
                ? null
                : IncomePeriod.values.byName(e['period'] as String),
          ),
      ];
      return BackupData(
        userName: (settings['userName'] as String?) ?? '',
        currencyCode: (settings['currency'] as String?) ?? 'INR',
        weekStartsOnSunday: settings['weekStart'] == 'sunday',
        monthlyBudgetMinor: (settings['monthlyBudget'] as int?) ?? 0,
        categories: categories,
        entries: entries,
        exportedAt: DateTime.tryParse(decoded['exportedAt'] as String? ?? ''),
      );
    } catch (_) {
      throw const FormatException('This backup file is damaged.');
    }
  }

  static String _dateString(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
