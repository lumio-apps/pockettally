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

const List<String> kExpenseCategories = [
  'Food',
  'Rent',
  'Travel',
  'Shopping',
  'Bills',
  'Health',
  'Entertainment',
  'Education',
  'Other',
];

const List<String> kIncomeCategories = [
  'Salary',
  'Business',
  'Gift',
  'Other',
];

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

  Entry copyWith({int? id}) => Entry(
        id: id ?? this.id,
        type: type,
        amountMinor: amountMinor,
        category: category,
        date: date,
        note: note,
        period: period,
      );

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
