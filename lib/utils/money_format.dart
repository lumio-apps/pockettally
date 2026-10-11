import 'amount_parser.dart';

/// How numbers are grouped and which character is the decimal point.
enum NumberStyle {
  /// Picked from the currency (e.g. INR -> Indian, EUR -> 1.234,56).
  auto,

  /// 1,234,567.89
  commaDot,

  /// 1.234.567,89
  dotComma,

  /// 1 234 567,89
  spaceComma,

  /// 1'234'567.89
  apostropheDot,

  /// 12,34,567.89 (lakh / crore grouping)
  indian,
}

/// Formats and parses amounts for the chosen number style and decimals.
///
/// Amounts are always stored in hundredths (minor units with 2 decimals),
/// whatever the currency. With [decimals] = 0 they are shown and entered
/// as whole numbers, so switching the setting never changes stored data.
class MoneyFormatter {
  const MoneyFormatter({required this.style, required this.decimals});

  /// A resolved style ([NumberStyle.auto] is treated as 1,234.56).
  final NumberStyle style;

  /// 0 or 2 (anything other than 0 shows 2).
  final int decimals;

  bool get decimalComma =>
      style == NumberStyle.dotComma || style == NumberStyle.spaceComma;

  String get decimalSeparator => decimalComma ? ',' : '.';

  String get groupSeparator {
    switch (style) {
      case NumberStyle.dotComma:
        return '.';
      case NumberStyle.spaceComma:
        return ' '; // no-break space, so a number never wraps
      case NumberStyle.apostropheDot:
        return "'";
      case NumberStyle.auto:
      case NumberStyle.commaDot:
      case NumberStyle.indian:
        return ',';
    }
  }

  /// Grouped number without a symbol, e.g. "1,234.50" or "1.235".
  String number(int minor) {
    final negative = minor < 0;
    final abs = minor.abs();
    String whole;
    var fraction = '';
    if (decimals == 0) {
      whole = ((abs + 50) ~/ 100).toString();
    } else {
      whole = (abs ~/ 100).toString();
      fraction = (abs % 100).toString().padLeft(2, '0');
    }
    final isZero = whole == '0' && (fraction.isEmpty || fraction == '00');
    final text = _group(whole) +
        (decimals > 0 ? '$decimalSeparator$fraction' : '');
    return negative && !isZero ? '-$text' : text;
  }

  /// "₹ 1,23,456.00", "-€ 12,50".
  String money(int minor, String symbol) {
    final n = number(minor);
    return n.startsWith('-') ? '-$symbol ${n.substring(1)}' : '$symbol $n';
  }

  /// Plain text for an editable amount field: no grouping, trailing zeros
  /// removed, e.g. 1250 -> "12.5" (or "12,5"), 32000 -> "320".
  String input(int minor) {
    final abs = minor.abs();
    var text = decimals == 0
        ? ((abs + 50) ~/ 100).toString()
        : '${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}'
            .replaceFirst(RegExp(r'\.?0+$'), '');
    if (decimalComma) text = text.replaceAll('.', ',');
    return minor < 0 ? '-$text' : text;
  }

  /// Turns a typed value into stored minor units, rounding to whole units
  /// when decimals are hidden.
  int toMinor(double value) =>
      decimals == 0 ? value.round() * 100 : (value * 100).round();

  /// Parses (and calculates) what the user typed.
  double? parse(String text) =>
      evaluateAmount(text, decimalComma: decimalComma);

  String _group(String digits) {
    if (digits.length <= 3) return digits;
    final sep = groupSeparator;
    if (style == NumberStyle.indian) {
      final last3 = digits.substring(digits.length - 3);
      var rest = digits.substring(0, digits.length - 3);
      final parts = <String>[];
      while (rest.length > 2) {
        parts.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }
      if (rest.isNotEmpty) parts.insert(0, rest);
      return '${parts.join(sep)}$sep$last3';
    }
    final buf = StringBuffer();
    final first = digits.length % 3;
    if (first > 0) buf.write(digits.substring(0, first));
    for (var i = first; i < digits.length; i += 3) {
      if (buf.isNotEmpty) buf.write(sep);
      buf.write(digits.substring(i, i + 3));
    }
    return buf.toString();
  }
}
