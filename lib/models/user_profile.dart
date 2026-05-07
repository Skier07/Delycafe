class UserProfile {
  final String name;
  final String phone;
  final int points;
  final List<String> addresses;
  final int ordersCount;
  final String favoriteItem;
  final String lastOrderDate;

  const UserProfile({
    required this.name,
    required this.phone,
    required this.points,
    required this.addresses,
    required this.ordersCount,
    required this.favoriteItem,
    required this.lastOrderDate,
  });
}
