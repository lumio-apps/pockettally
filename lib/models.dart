import 'dart:ui' show Color;

import 'utils/money_format.dart';

enum EntryType { income, expense }

enum IncomePeriod { daily, weekly, monthly }

class Currency {
  const Currency(
    this.code,
    this.symbol,
    this.name, {
    this.locale = 'en_US',
    this.decimals = 2,
    this.numberStyle = NumberStyle.commaDot,
  });

  final String code;
  final String symbol;
  final String name;
  final String locale;

  /// Decimal places normally used (0 for JPY and KRW).
  final int decimals;

  /// Number format used when the setting is "Automatic".
  final NumberStyle numberStyle;
}

const List<Currency> kCurrencies = [
  Currency('INR', '₹', 'Indian Rupee',
      locale: 'en_IN', numberStyle: NumberStyle.indian),
  Currency('USD', r'$', 'US Dollar'),
  Currency('EUR', '€', 'Euro', numberStyle: NumberStyle.dotComma),
  Currency('GBP', '£', 'British Pound'),
  Currency('JPY', '¥', 'Japanese Yen', decimals: 0),
  Currency('CNY', 'CN¥', 'Chinese Yuan'),
  Currency('AUD', r'A$', 'Australian Dollar'),
  Currency('CAD', r'C$', 'Canadian Dollar'),
  Currency('CHF', 'CHF', 'Swiss Franc', numberStyle: NumberStyle.apostropheDot),
  Currency('AED', 'AED', 'UAE Dirham'),
  Currency('AMD', '֏', 'Armenian Dram', numberStyle: NumberStyle.spaceComma),
  Currency('SAR', 'SAR', 'Saudi Riyal'),
  Currency('SGD', r'S$', 'Singapore Dollar'),
  Currency('HKD', r'HK$', 'Hong Kong Dollar'),
  Currency('NZD', r'NZ$', 'New Zealand Dollar'),
  Currency('KRW', '₩', 'South Korean Won', decimals: 0),
  Currency('RUB', '₽', 'Russian Ruble', numberStyle: NumberStyle.spaceComma),
  Currency('BRL', r'R$', 'Brazilian Real', numberStyle: NumberStyle.dotComma),
  Currency('MXN', r'MX$', 'Mexican Peso'),
  Currency('ZAR', 'R', 'South African Rand',
      numberStyle: NumberStyle.spaceComma),
  Currency('TRY', '₺', 'Turkish Lira', numberStyle: NumberStyle.dotComma),
  Currency('SEK', 'kr', 'Swedish Krona', numberStyle: NumberStyle.spaceComma),
  Currency('NOK', 'kr', 'Norwegian Krone', numberStyle: NumberStyle.spaceComma),
  Currency('PKR', 'Rs', 'Pakistani Rupee', numberStyle: NumberStyle.indian),
  Currency('BDT', '৳', 'Bangladeshi Taka', numberStyle: NumberStyle.indian),
  Currency('NPR', 'Rs', 'Nepalese Rupee', numberStyle: NumberStyle.indian),
  Currency('LKR', 'Rs', 'Sri Lankan Rupee'),
];

Currency currencyByCode(String code) =>
    kCurrencies.firstWhere((c) => c.code == code, orElse: () => kCurrencies.first);

/// Currency usually used in a country (ISO 3166 code), US dollar otherwise.
Currency currencyForCountry(String? country) {
  const euro = {
    'AT', 'BE', 'CY', 'DE', 'EE', 'ES', 'FI', 'FR', 'GR', 'HR', 'IE', 'IT',
    'LT', 'LU', 'LV', 'MT', 'NL', 'PT', 'SI', 'SK', //
  };
  const map = {
    'IN': 'INR', 'US': 'USD', 'GB': 'GBP', 'JP': 'JPY', 'CN': 'CNY',
    'AU': 'AUD', 'CA': 'CAD', 'CH': 'CHF', 'LI': 'CHF', 'AE': 'AED',
    'AM': 'AMD', 'SA': 'SAR', 'SG': 'SGD', 'HK': 'HKD', 'NZ': 'NZD',
    'KR': 'KRW', 'RU': 'RUB', 'BR': 'BRL', 'MX': 'MXN', 'ZA': 'ZAR',
    'TR': 'TRY', 'SE': 'SEK', 'NO': 'NOK', 'PK': 'PKR', 'BD': 'BDT',
    'NP': 'NPR', 'LK': 'LKR', //
  };
  final c = country?.toUpperCase();
  if (c == null) return currencyByCode('USD');
  if (euro.contains(c)) return currencyByCode('EUR');
  return currencyByCode(map[c] ?? 'USD');
}

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
    this.budgetMinor,
    this.position = 0,
    this.hidden = false,
    this.icon,
  });

  final int? id;
  final String name;
  final EntryType type;
  final int colorValue;

  /// Icon key (see category_icons.dart); null = picked from the name.
  final String? icon;

  /// Monthly spending limit in minor units (expense categories only).
  /// Null means no limit.
  final int? budgetMinor;

  /// Order chosen by the user. All 0 = alphabetical (never reordered).
  final int position;

  /// Hidden categories are not offered when adding an entry, but old
  /// entries keep them.
  final bool hidden;

  bool get hasBudget => (budgetMinor ?? 0) > 0;

  Color get color => Color(colorValue);

  bool get isOther => name == kOtherCategory;

  EntryCategory copyWith({
    String? name,
    int? colorValue,
    int? Function()? budgetMinor,
    int? position,
    bool? hidden,
    String? icon,
  }) =>
      EntryCategory(
        id: id,
        name: name ?? this.name,
        type: type,
        colorValue: colorValue ?? this.colorValue,
        budgetMinor: budgetMinor != null ? budgetMinor() : this.budgetMinor,
        position: position ?? this.position,
        hidden: hidden ?? this.hidden,
        icon: icon ?? this.icon,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'type': type.name,
        'color': colorValue,
        'budget': budgetMinor,
        'position': position,
        'hidden': hidden ? 1 : 0,
        'icon': icon,
      };

  static EntryCategory fromMap(Map<String, Object?> m) => EntryCategory(
        id: m['id'] as int?,
        name: m['name'] as String,
        type: EntryType.values.byName(m['type'] as String),
        colorValue: m['color'] as int,
        budgetMinor: m['budget'] as int?,
        position: (m['position'] as int?) ?? 0,
        hidden: (m['hidden'] as int?) == 1,
        icon: m['icon'] as String?,
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
    this.photo,
    this.tags = const [],
    this.minutes,
  });

  final int? id;
  final EntryType type;
  final int amountMinor;
  final String category;
  final DateTime date;
  final String note;

  /// Time of day in minutes after midnight (null for entries made before
  /// app 1.0.0, recurring entries and imports without a time).
  final int? minutes;

  /// Free labels like "trip" or "office", lower case, without "#".
  final List<String> tags;

  /// File name of the bill photo in the app's private folder, if any.
  final String? photo;

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
        'photo': photo,
        'tags': tags.join(','),
        'time': minutes,
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
        photo: m['photo'] as String?,
        tags: parseTags((m['tags'] as String?) ?? ''),
        minutes: m['time'] as int?,
      );
}

/// "Trip, #office  food" -> ["trip", "office", "food"] (unique, in order).
List<String> parseTags(String text) {
  final seen = <String>{};
  for (final raw in text.split(RegExp(r'[,\s]+'))) {
    final t = raw.trim().replaceAll('#', '').toLowerCase();
    if (t.isNotEmpty) seen.add(t);
  }
  return seen.toList();
}

/// How often a recurring entry repeats.
enum RepeatEvery { daily, weekly, monthly, yearly }

/// The date after [from] for a rule repeating [every]. Monthly and yearly
/// rules keep their [anchorDay] (31 Jan -> 28 Feb -> 31 Mar).
DateTime nextRepeatDate(DateTime from, RepeatEvery every, int anchorDay) {
  int clampDay(int year, int month) {
    final last = DateTime(year, month + 1, 0).day;
    return anchorDay > last ? last : anchorDay;
  }

  switch (every) {
    case RepeatEvery.daily:
      return DateTime(from.year, from.month, from.day + 1);
    case RepeatEvery.weekly:
      return DateTime(from.year, from.month, from.day + 7);
    case RepeatEvery.monthly:
      final y = from.month == 12 ? from.year + 1 : from.year;
      final m = from.month == 12 ? 1 : from.month + 1;
      return DateTime(y, m, clampDay(y, m));
    case RepeatEvery.yearly:
      return DateTime(from.year + 1, from.month, clampDay(from.year + 1, from.month));
  }
}

/// An entry that is added again and again, e.g. salary every month.
class RecurringRule {
  const RecurringRule({
    this.id,
    required this.type,
    required this.amountMinor,
    required this.category,
    this.note = '',
    this.period,
    this.tags = const [],
    required this.every,
    required this.anchorDay,
    required this.nextDate,
    this.paused = false,
  });

  /// A rule for [e]: the first repeat comes one step after its date.
  factory RecurringRule.fromEntry(Entry e, RepeatEvery every) => RecurringRule(
        type: e.type,
        amountMinor: e.amountMinor,
        category: e.category,
        note: e.note,
        period: e.period,
        tags: e.tags,
        every: every,
        anchorDay: e.date.day,
        nextDate: nextRepeatDate(e.date, every, e.date.day),
      );

  final int? id;
  final EntryType type;
  final int amountMinor;
  final String category;
  final String note;
  final IncomePeriod? period;
  final List<String> tags;
  final RepeatEvery every;

  /// Day of the month the rule started on (for monthly/yearly).
  final int anchorDay;

  /// When the next entry is due.
  final DateTime nextDate;
  final bool paused;

  Entry entryOn(DateTime date) => Entry(
        type: type,
        amountMinor: amountMinor,
        category: category,
        date: date,
        note: note,
        period: period,
        tags: tags,
      );

  RecurringRule copyWith({DateTime? nextDate, bool? paused}) => RecurringRule(
        id: id,
        type: type,
        amountMinor: amountMinor,
        category: category,
        note: note,
        period: period,
        tags: tags,
        every: every,
        anchorDay: anchorDay,
        nextDate: nextDate ?? this.nextDate,
        paused: paused ?? this.paused,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'type': type.name,
        'amount_minor': amountMinor,
        'category': category,
        'note': note,
        'period': period?.name,
        'tags': tags.join(','),
        'every': every.name,
        'anchor_day': anchorDay,
        'next_date': DateTime(nextDate.year, nextDate.month, nextDate.day)
            .millisecondsSinceEpoch,
        'paused': paused ? 1 : 0,
      };

  static RecurringRule fromMap(Map<String, Object?> m) => RecurringRule(
        id: m['id'] as int?,
        type: EntryType.values.byName(m['type'] as String),
        amountMinor: m['amount_minor'] as int,
        category: m['category'] as String,
        note: (m['note'] as String?) ?? '',
        period: m['period'] == null
            ? null
            : IncomePeriod.values.byName(m['period'] as String),
        tags: parseTags((m['tags'] as String?) ?? ''),
        every: RepeatEvery.values.byName(m['every'] as String),
        anchorDay: m['anchor_day'] as int,
        nextDate: DateTime.fromMillisecondsSinceEpoch(m['next_date'] as int),
        paused: (m['paused'] as int?) == 1,
      );
}

/// A saved entry that can be added again with one tap ("Coffee 3.50").
class Favorite {
  const Favorite({
    this.id,
    required this.type,
    required this.amountMinor,
    required this.category,
    this.note = '',
    this.period,
  });

  final int? id;
  final EntryType type;
  final int amountMinor;
  final String category;
  final String note;
  final IncomePeriod? period;

  Entry entryOn(DateTime date, {int? minutes}) => Entry(
        type: type,
        amountMinor: amountMinor,
        category: category,
        date: date,
        note: note,
        period: period,
        minutes: minutes,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'type': type.name,
        'amount_minor': amountMinor,
        'category': category,
        'note': note,
        'period': period?.name,
      };

  static Favorite fromMap(Map<String, Object?> m) => Favorite(
        id: m['id'] as int?,
        type: EntryType.values.byName(m['type'] as String),
        amountMinor: m['amount_minor'] as int,
        category: m['category'] as String,
        note: (m['note'] as String?) ?? '',
        period: m['period'] == null
            ? null
            : IncomePeriod.values.byName(m['period'] as String),
      );
}

enum DebtType { lent, borrowed }

/// Money lent to someone or borrowed from someone.
class Debt {
  const Debt({
    this.id,
    required this.person,
    required this.type,
    required this.amountMinor,
    this.paidMinor = 0,
    required this.date,
    this.note = '',
    this.remindAt,
  });

  final int? id;
  final String person;
  final DebtType type;
  final int amountMinor;

  /// How much of it has been paid back so far.
  final int paidMinor;
  final DateTime date;
  final String note;

  /// When to show a "time to ask / pay back" notification (date and time),
  /// or null for none.
  final DateTime? remindAt;

  int get remainingMinor => amountMinor - paidMinor > 0 ? amountMinor - paidMinor : 0;
  bool get isSettled => paidMinor >= amountMinor;

  /// True when a reminder is set for a time still to come and the money is
  /// still open.
  bool hasUpcomingReminder(DateTime now) =>
      !isSettled && remindAt != null && remindAt!.isAfter(now);

  Debt copyWith({
    String? person,
    DebtType? type,
    int? amountMinor,
    int? paidMinor,
    DateTime? date,
    String? note,
    DateTime? Function()? remindAt,
  }) =>
      Debt(
        id: id,
        person: person ?? this.person,
        type: type ?? this.type,
        amountMinor: amountMinor ?? this.amountMinor,
        paidMinor: paidMinor ?? this.paidMinor,
        date: date ?? this.date,
        note: note ?? this.note,
        remindAt: remindAt != null ? remindAt() : this.remindAt,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'person': person,
        'type': type.name,
        'amount_minor': amountMinor,
        'paid_minor': paidMinor,
        'date': DateTime(date.year, date.month, date.day).millisecondsSinceEpoch,
        'note': note,
        'remind_at': remindAt?.millisecondsSinceEpoch,
      };

  static Debt fromMap(Map<String, Object?> m) => Debt(
        id: m['id'] as int?,
        person: m['person'] as String,
        type: DebtType.values.byName(m['type'] as String),
        amountMinor: m['amount_minor'] as int,
        paidMinor: (m['paid_minor'] as int?) ?? 0,
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        note: (m['note'] as String?) ?? '',
        remindAt: m['remind_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['remind_at'] as int),
      );
}

/// A savings goal, e.g. "New phone" with a target of 20,000.
class SavingsGoal {
  const SavingsGoal({
    this.id,
    required this.name,
    required this.targetMinor,
    this.savedMinor = 0,
    required this.colorValue,
  });

  final int? id;
  final String name;
  final int targetMinor;
  final int savedMinor;
  final int colorValue;

  Color get color => Color(colorValue);
  double get progress =>
      targetMinor <= 0 ? 0 : (savedMinor / targetMinor).clamp(0.0, 1.0);
  bool get isReached => savedMinor >= targetMinor;

  SavingsGoal copyWith({
    String? name,
    int? targetMinor,
    int? savedMinor,
    int? colorValue,
  }) =>
      SavingsGoal(
        id: id,
        name: name ?? this.name,
        targetMinor: targetMinor ?? this.targetMinor,
        savedMinor: savedMinor ?? this.savedMinor,
        colorValue: colorValue ?? this.colorValue,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'target_minor': targetMinor,
        'saved_minor': savedMinor,
        'color': colorValue,
      };

  static SavingsGoal fromMap(Map<String, Object?> m) => SavingsGoal(
        id: m['id'] as int?,
        name: m['name'] as String,
        targetMinor: m['target_minor'] as int,
        savedMinor: (m['saved_minor'] as int?) ?? 0,
        colorValue: m['color'] as int,
      );
}
