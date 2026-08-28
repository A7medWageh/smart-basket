enum PaymentMethodType { vodafoneCash, instaPay, visaCard }

class PaymentMethod {
  final PaymentMethodType type;
  final String name;
  final String logoPath;

  const PaymentMethod({
    required this.type,
    required this.name,
    required this.logoPath,
  });

  static const List<PaymentMethod> defaultMethods = [
    PaymentMethod(
      type: PaymentMethodType.vodafoneCash,
      name: 'Vodafone Cash',
      logoPath: 'assets/vodafone.png',
    ),
    PaymentMethod(
      type: PaymentMethodType.instaPay,
      name: 'InstaPay',
      logoPath: 'assets/instapay.png',
    ),
    PaymentMethod(
      type: PaymentMethodType.visaCard,
      name: 'Visa Card',
      logoPath: 'assets/visa.png',
    ),
  ];
}
