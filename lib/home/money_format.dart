/// Formats an amount as Philippine pesos — used by listing cards.
///
/// Prices are always green and weight 800 (DESIGN.md §2/§5), displayed as
/// whole pesos with thousands separators: `1250` → `₱1,250`.
String formatPesos(num amount) {
  final digits = amount.round().toString();
  final buffer = StringBuffer('₱');
  for (var i = 0; i < digits.length; i++) {
    buffer.write(digits[i]);
    final remaining = digits.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) buffer.write(',');
  }
  return buffer.toString();
}
