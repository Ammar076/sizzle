/// Best-effort scaling of a free-text ingredient line by [factor]. It parses a
/// leading quantity — integer, decimal, ASCII fraction ("1/2"), unicode
/// fraction ("½"), mixed ("1½" / "1 1/2"), or a range ("2-3") — multiplies it,
/// and reformats using friendly fractions. Lines that don't start with a
/// number are returned unchanged.
String scaleIngredient(String line, double factor) {
  if (factor == 1.0) return line;

  final trimmed = line.trimLeft();
  final leadingWs = line.substring(0, line.length - trimmed.length);

  final first = _matchQuantity(trimmed);
  if (first == null) return line;

  // Range, e.g. "2-3 tbsp" or "2 – 3 cups".
  final afterFirst = trimmed.substring(first.end);
  final rangeSep = RegExp(r'^\s*[-–—]\s*').firstMatch(afterFirst);
  if (rangeSep != null) {
    final second = _matchQuantity(afterFirst.substring(rangeSep.end));
    if (second != null) {
      final rest = afterFirst.substring(rangeSep.end + second.end);
      return '$leadingWs${_formatQuantity(first.value * factor)}'
          '–${_formatQuantity(second.value * factor)}$rest';
    }
  }

  final rest = trimmed.substring(first.end);
  return '$leadingWs${_formatQuantity(first.value * factor)}$rest';
}

const _unicodeFractions = <String, double>{
  '¼': 0.25,
  '½': 0.5,
  '¾': 0.75,
  '⅓': 1 / 3,
  '⅔': 2 / 3,
  '⅛': 0.125,
  '⅜': 0.375,
  '⅝': 0.625,
  '⅞': 0.875,
  '⅕': 0.2,
  '⅖': 0.4,
  '⅗': 0.6,
  '⅘': 0.8,
  '⅙': 1 / 6,
  '⅚': 5 / 6,
};

const _fractionChars = '¼½¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚';

class _QtyMatch {
  final double value;
  final int end;
  const _QtyMatch(this.value, this.end);
}

/// Matches a quantity at the start of [s], returning its value and how many
/// characters it consumed, or null if [s] doesn't start with a quantity.
_QtyMatch? _matchQuantity(String s) {
  // Mixed number with a unicode fraction: "1½" or "1 ½".
  final mixedUni = RegExp('^(\\d+)\\s*([$_fractionChars])').firstMatch(s);
  if (mixedUni != null) {
    final whole = double.parse(mixedUni.group(1)!);
    return _QtyMatch(
        whole + _unicodeFractions[mixedUni.group(2)!]!, mixedUni.end);
  }

  // Mixed number with an ASCII fraction: "1 1/2".
  final mixedAscii = RegExp(r'^(\d+)\s+(\d+)/(\d+)').firstMatch(s);
  if (mixedAscii != null) {
    final whole = double.parse(mixedAscii.group(1)!);
    final n = double.parse(mixedAscii.group(2)!);
    final d = double.parse(mixedAscii.group(3)!);
    if (d != 0) return _QtyMatch(whole + n / d, mixedAscii.end);
  }

  // ASCII fraction: "1/2".
  final frac = RegExp(r'^(\d+)/(\d+)').firstMatch(s);
  if (frac != null) {
    final n = double.parse(frac.group(1)!);
    final d = double.parse(frac.group(2)!);
    if (d != 0) return _QtyMatch(n / d, frac.end);
  }

  // Single unicode fraction: "½".
  final uni = RegExp('^([$_fractionChars])').firstMatch(s);
  if (uni != null) {
    return _QtyMatch(_unicodeFractions[uni.group(1)!]!, uni.end);
  }

  // Decimal or integer: "1.5" or "2".
  final dec = RegExp(r'^(\d+(?:\.\d+)?)').firstMatch(s);
  if (dec != null) {
    return _QtyMatch(double.parse(dec.group(1)!), dec.end);
  }

  return null;
}

String _formatQuantity(double v) {
  const eps = 0.05;
  final whole = v.floor();
  final frac = v - whole;

  const fractions = <(double, String)>[
    (0.125, '⅛'),
    (0.25, '¼'),
    (0.333, '⅓'),
    (0.5, '½'),
    (0.667, '⅔'),
    (0.75, '¾'),
    (0.875, '⅞'),
  ];
  for (final (value, symbol) in fractions) {
    if ((frac - value).abs() < eps) {
      return whole > 0 ? '$whole$symbol' : symbol;
    }
  }
  if (frac.abs() < eps) return '$whole';

  var s = v.toStringAsFixed(2);
  s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  return s;
}
