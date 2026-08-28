class CurrencyFormatter {
  CurrencyFormatter._();

  static String format(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }
}
