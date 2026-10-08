import 'dart:ui' show Color;

enum EntryType { income, expense }

enum IncomePeriod { daily, weekly, monthly }

class Currency {
  const Currency(this.code, this.symbol, this.name, {this.locale = 'en_US'});

  final String code;
  final String symbol;
  final String name;
  final String locale;
}

const List<Currency> kCurrencies = [
  Currency('INR', '₹', 'Indian Rupee', locale: 'en_IN'),
  Currency('USD', r'$', 'US Dollar'),
  Currency('EUR', '€', 'Euro'),
  Currency('GBP', '£', 'British Pound'),
  Currency('JPY', '¥', 'Japanese Yen'),
  Currency('CNY', 'CN¥', 'Chinese Yuan'),
  Currency('AUD', r'A$', 'Australian Dollar'),
  Currency('CAD', r'C$', 'Canadian Dollar'),
  Currency('CHF', 'CHF', 'Swiss Franc'),
  Currency('AED', 'AED', 'UAE Dirham'),
  Currency('SAR', 'SAR', 'Saudi Riyal'),
  Currency('SGD', r'S$', 'Singapore Dollar'),
  Currency('HKD', r'HK$', 'Hong Kong Dollar'),
  Currency('NZD', r'NZ$', 'New Zealand Dollar'),
  Currency('KRW', '₩', 'South Korean Won'),
  Currency('RUB', '₽', 'Russian Ruble'),
  Currency('BRL', r'R$', 'Brazilian Real'),
  Currency('MXN', r'MX$', 'Mexican Peso'),
  Currency('ZAR', 'R', 'South African Rand'),
  Currency('TRY', '₺', 'Turkish Lira'),
  Currency('SEK', 'kr', 'Swedish Krona'),
  Currency('NOK', 'kr', 'Norwegian Krone'),
  Currency('PKR', 'Rs', 'Pakistani Rupee'),
  Currency('BDT', '৳', 'Bangladeshi Taka'),
  Currency('NPR', 'Rs', 'Nepalese Rupee'),
  Currency('LKR', 'Rs', 'Sri Lankan Rupee'),
];

Currency currencyByCode(String code) =>
    kCurrencies.firstWhere((c) => c.code == code, orElse: () => kCurrencies.first);

/// Colors a category can have (ARGB). Also used for the pie chart.
const List<int> kCategoryPalette = [
  0xFFE57373, // red
  0xFFF06292, // pink
  0xFFBA68C8, // purple
  0xFF7986CB, // indigo
  0xFF64B5F6, // blue
  0xFF4DD0E1, // cyan
  0xFF4DB6AC, // teal
  0xFF81C784, // green
  0xFFDCE775, // lime
  0xFFFFD54F, // amber
  0xFFFFB74D, // orange
  0xFFA1887F, // brown
  0xFF90A4AE, // blue grey
];

/// Every type always has this category. It cannot be deleted, and entries of
/// a deleted category are moved here.
const String kOtherCategory = 'Other';

/// Categories created on first launch: (name, color).
const List<(String, int)> kDefaultExpenseCategories = [
  ('Food', 0xFFFFB74D),
  ('Rent', 0xFF7986CB),
  ('Travel', 0xFF64B5F6),
  ('Shopping', 0xFFF06292),
  ('Bills', 0xFFE57373),
  ('Health', 0xFF4DB6AC),
  ('Entertainment', 0xFFBA68C8),
  ('Education', 0xFF4DD0E1),
  (kOtherCategory, 0xFF90A4AE),
];

const List<(String, int)> kDefaultIncomeCategories = [
  ('Salary', 0xFF81C784),
  ('Business', 0xFF4DB6AC),
  ('Gift', 0xFFFFD54F),
  (kOtherCategory, 0xFF90A4AE),
];

class EntryCategory {
  const EntryCategory({
    this.id,
    required this.name,
    required this.type,
    required this.colorValue,
  });

  final int? id;
  final String name;
  final EntryType type;
  final int colorValue;

  Color get color => Color(colorValue);

  bool get isOther => name == kOtherCategory;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'type': type.name,
        'color': colorValue,
      };

  static EntryCategory fromMap(Map<String, Object?> m) => EntryCategory(
        id: m['id'] as int?,
        name: m['name'] as String,
        type: EntryType.values.byName(m['type'] as String),
        colorValue: m['color'] as int,
      );
}

/// One income or expense. Amounts are stored in minor units (cents/paise)
/// so there are no floating point rounding errors.
class Entry {
  Entry({
    this.id,
    required this.type,
    required this.amountMinor,
    required this.category,
    required this.date,
    this.note = '',
    this.period,
  });

  final int? id;
  final EntryType type;
  final int amountMinor;
  final String category;
  final DateTime date;
  final String note;

  /// Only used for income: daily, weekly or monthly salary.
  final IncomePeriod? period;

  bool get isIncome => type == EntryType.income;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'type': type.name,
        'amount_minor': amountMinor,
        'category': category,
        'date': DateTime(date.year, date.month, date.day).millisecondsSinceEpoch,
        'note': note,
        'period': period?.name,
      };

  static Entry fromMap(Map<String, Object?> m) => Entry(
        id: m['id'] as int?,
        type: EntryType.values.byName(m['type'] as String),
        amountMinor: m['amount_minor'] as int,
        category: m['category'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        note: (m['note'] as String?) ?? '',
        period: m['period'] == null
            ? null
            : IncomePeriod.values.byName(m['period'] as String),
      );
}
