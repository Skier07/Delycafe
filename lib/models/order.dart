class Order {
  final List<String> items;
  final int totalPrice;
  final DateTime date;

  Order({
    required this.items,
    required this.totalPrice,
    required this.date,
  });
}
