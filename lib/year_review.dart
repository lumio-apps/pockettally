import 'models.dart';

/// The numbers behind "Year in review" for one calendar year.
class YearReview {
  const YearReview({
    required this.year,
    required this.income,
    required this.expense,
    required this.entryCount,
    required this.biggestExpense,
    required this.topCategory,
    required this.topCategoryMinor,
    required this.bestSavingMonth,
    required this.bestSavingMinor,
    required this.costliestMonth,
    required this.costliestMinor,
    required this.avgDailyExpenseMinor,
    required this.noSpendDays,
  });

  final int year;
  final int income;
  final int expense;
  final int entryCount;

  /// The single largest expense, or null when there is none.
  final Entry? biggestExpense;

  /// The expense category with the most money, or null.
  final String? topCategory;
  final int topCategoryMinor;

  /// Month number 1-12 with the most saved (income minus expenses), or null.
  final int? bestSavingMonth;
  final int bestSavingMinor;

  /// Month number 1-12 with the highest expenses, or null.
  final int? costliestMonth;
  final int costliestMinor;
  final int avgDailyExpenseMinor;

  /// Days of the year so far on which nothing was spent.
  final int noSpendDays;

  int get saved => income - expense;
  bool get isEmpty => entryCount == 0;

  /// Share (0-100) of all spending that went to the top category.
  int get topCategoryPercent =>
      expense <= 0 ? 0 : (topCategoryMinor * 100 / expense).round();

  /// Years that have at least one entry, newest first.
  static List<int> yearsWithEntries(List<Entry> entries, DateTime now) {
    final years = {for (final e in entries) e.date.year}..add(now.year);
    return years.toList()..sort((a, b) => b.compareTo(a));
  }

  static YearReview compute(List<Entry> all, int year, DateTime now) {
    final list = all.where((e) => e.date.year == year).toList();
    var income = 0, expense = 0;
    Entry? biggest;
    final byCategory = <String, int>{};
    final incomeByMonth = List<int>.filled(13, 0);
    final expenseByMonth = List<int>.filled(13, 0);
    final spendDays = <int>{};
    for (final e in list) {
      if (e.isIncome) {
        income += e.amountMinor;
        incomeByMonth[e.date.month] += e.amountMinor;
      } else {
        expense += e.amountMinor;
        expenseByMonth[e.date.month] += e.amountMinor;
        byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amountMinor;
        spendDays.add(DateTime.utc(e.date.year, e.date.month, e.date.day)
            .difference(DateTime.utc(year, 1, 1))
            .inDays);
        if (biggest == null || e.amountMinor > biggest.amountMinor) {
          biggest = e;
        }
      }
    }

    String? topCategory;
    var topMinor = 0;
    byCategory.forEach((name, minor) {
      if (minor > topMinor) {
        topCategory = name;
        topMinor = minor;
      }
    });

    // Months of this year that have started (all 12 for a past year).
    final lastMonth = year < now.year ? 12 : (year == now.year ? now.month : 0);
    int? best, costliest;
    var bestMinor = 0, costliestMinor = 0;
    for (var m = 1; m <= lastMonth; m++) {
      if (incomeByMonth[m] == 0 && expenseByMonth[m] == 0) continue;
      final saved = incomeByMonth[m] - expenseByMonth[m];
      if (best == null || saved > bestMinor) {
        best = m;
        bestMinor = saved;
      }
      if (expenseByMonth[m] > 0 &&
          (costliest == null || expenseByMonth[m] > costliestMinor)) {
        costliest = m;
        costliestMinor = expenseByMonth[m];
      }
    }

    // Days counted: the whole year, or up to today for the current year.
    final daysInYear =
        DateTime.utc(year + 1, 1, 1).difference(DateTime.utc(year, 1, 1)).inDays;
    final days = year < now.year
        ? daysInYear
        : (year == now.year
            ? DateTime.utc(now.year, now.month, now.day)
                    .difference(DateTime.utc(year, 1, 1))
                    .inDays +
                1
            : 0);
    final noSpend = days <= 0
        ? 0
        : days - spendDays.where((d) => d >= 0 && d < days).length;

    return YearReview(
      year: year,
      income: income,
      expense: expense,
      entryCount: list.length,
      biggestExpense: biggest,
      topCategory: topCategory,
      topCategoryMinor: topMinor,
      bestSavingMonth: best,
      bestSavingMinor: bestMinor,
      costliestMonth: costliest,
      costliestMinor: costliestMinor,
      avgDailyExpenseMinor: days <= 0 ? 0 : (expense / days).round(),
      noSpendDays: noSpend,
    );
  }
}
