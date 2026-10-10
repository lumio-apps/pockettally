/// Turns what the user typed in an amount field into a number.
///
/// Supports simple math so the field works as a calculator:
///   "120+45"      -> 165
///   "3 × 40"      -> 120
///   "1,500/2"     -> 750     (comma before 3 digits = thousands separator)
///   "12,5"        -> 12.5    (other commas = decimal point)
///   "(100+50)*2"  -> 300
///
/// Returns null when the text is empty or not a valid expression.
double? evaluateAmount(String input) {
  var s = input.trim();
  if (s.isEmpty) return null;

  s = s
      .replaceAll('×', '*')
      .replaceAll('x', '*')
      .replaceAll('X', '*')
      .replaceAll('÷', '/')
      .replaceAll('−', '-')
      .replaceAll(' ', '');
  // "1,500" -> "1500"; any comma left after that is a decimal comma.
  s = s.replaceAllMapped(
      RegExp(r'(\d),(?=\d{3}(?!\d))'), (m) => m.group(1)!);
  s = s.replaceAll(',', '.');

  final parser = _Parser(s);
  final value = parser.parse();
  if (value == null || value.isNaN || value.isInfinite) return null;
  return value;
}

/// True when [input] contains an operator, i.e. it is a calculation and not
/// just a plain number (used to decide whether to show "= result").
bool isCalculation(String input) =>
    RegExp(r'\d\s*[-+*/×÷x−]\s*[\d(]').hasMatch(input);

class _Parser {
  _Parser(this.s);

  final String s;
  int i = 0;

  double? parse() {
    final v = _expr();
    if (v == null || i != s.length) return null;
    return v;
  }

  // expr := term (('+' | '-') term)*
  double? _expr() {
    final first = _term();
    if (first == null) return null;
    var v = first;
    while (i < s.length && (s[i] == '+' || s[i] == '-')) {
      final op = s[i++];
      final r = _term();
      if (r == null) return null;
      v = op == '+' ? v + r : v - r;
    }
    return v;
  }

  // term := factor (('*' | '/') factor)*
  double? _term() {
    final first = _factor();
    if (first == null) return null;
    var v = first;
    while (i < s.length && (s[i] == '*' || s[i] == '/')) {
      final op = s[i++];
      final r = _factor();
      if (r == null) return null;
      if (op == '/' && r == 0) return null;
      v = op == '*' ? v * r : v / r;
    }
    return v;
  }

  // factor := number | '-' factor | '(' expr ')'
  double? _factor() {
    if (i >= s.length) return null;
    if (s[i] == '-') {
      i++;
      final v = _factor();
      return v == null ? null : -v;
    }
    if (s[i] == '(') {
      i++;
      final v = _expr();
      if (v == null || i >= s.length || s[i] != ')') return null;
      i++;
      return v;
    }
    final start = i;
    while (i < s.length && RegExp(r'[0-9.]').hasMatch(s[i])) {
      i++;
    }
    if (start == i) return null;
    return double.tryParse(s.substring(start, i));
  }
}
