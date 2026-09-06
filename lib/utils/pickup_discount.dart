/// Скидка самовывоза — построчно, как на кассе (Saby cost).
///
/// discounted = unitPrice * (100 - percent) ~/ 100
/// discount = sum((unitPrice - discounted) * quantity)
///
/// Нельзя считать percent% от всей суммы корзины — иначе ±1 ₽ к чеку.
int pickupDiscountForLines(
  Iterable<({int unitPrice, int quantity})> lines,
  int percent,
) {
  if (percent <= 0) {
    return 0;
  }

  var total = 0;
  for (final line in lines) {
    if (line.unitPrice <= 0 || line.quantity <= 0) {
      continue;
    }
    final discounted = line.unitPrice * (100 - percent) ~/ 100;
    total += (line.unitPrice - discounted) * line.quantity;
  }
  return total;
}
