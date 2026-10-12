import 'models.dart';

/// Splits [totalMinor] into [count] shares that add up to the total.
///
/// Shares are whole multiples of [unit] (100 when amounts are shown
/// without decimals). What does not divide evenly goes to the first shares,
/// so the user (always first) pays the odd cent.
List<int> splitEqually(int totalMinor, int count, {int unit = 1}) {
  if (count <= 0) return const [];
  final u = unit < 1 ? 1 : unit;
  final units = totalMinor ~/ u;
  final rest = totalMinor - units * u;
  final base = units ~/ count;
  final extra = units % count;
  final shares = [
    for (var i = 0; i < count; i++) (base + (i < extra ? 1 : 0)) * u,
  ];
  shares[0] += rest;
  return shares;
}

/// How a bill is shared between the user and other [people].
class SplitPlan {
  const SplitPlan({
    required this.people,
    this.equal = true,
    this.shares = const [],
    this.paidBy,
  });

  /// The other people (not the user), in the order they were added.
  final List<String> people;

  /// True: everyone pays the same. False: [shares] are used.
  final bool equal;

  /// Custom shares in minor units: the user's first, then one per person.
  final List<int> shares;

  /// Who paid the bill: null = the user, else one of [people].
  final String? paidBy;

  /// Number of people sharing, the user included.
  int get count => people.length + 1;

  /// Each share of a bill of [totalMinor], the user's first. Null when the
  /// custom shares do not add up to the total.
  List<int>? sharesFor(int totalMinor, {int unit = 1}) {
    if (people.isEmpty || totalMinor <= 0) return null;
    if (equal) return splitEqually(totalMinor, count, unit: unit);
    if (shares.length != count || shares.any((s) => s < 0)) return null;
    final sum = shares.fold<int>(0, (a, b) => a + b);
    return sum == totalMinor ? List<int>.of(shares) : null;
  }

  /// Together, what the other people pay ([shares] from [sharesFor]).
  static int othersTotal(List<int> shares) =>
      shares.skip(1).fold<int>(0, (a, b) => a + b);

  /// The Lend & Borrow records for this split ([shares] from [sharesFor]):
  /// when the user paid, everyone else owes the user their share; when
  /// someone else paid, the user owes that person the user's share.
  List<Debt> debtsFor(List<int> shares, DateTime date, String note) {
    final payer = paidBy;
    if (payer == null) {
      return [
        for (var i = 0; i < people.length; i++)
          if (shares[i + 1] > 0)
            Debt(
              person: people[i],
              type: DebtType.lent,
              amountMinor: shares[i + 1],
              date: date,
              note: note,
            ),
      ];
    }
    return [
      if (shares[0] > 0)
        Debt(
          person: payer,
          type: DebtType.borrowed,
          amountMinor: shares[0],
          date: date,
          note: note,
        ),
    ];
  }
}
