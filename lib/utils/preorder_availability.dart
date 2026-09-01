import 'package:delycafe/models/cart_item.dart';
import 'package:delycafe/models/catalog_item.dart';
import 'package:delycafe/utils/app_timezone.dart';

bool catalogItemCanOrderNow(CatalogItem item) {
  if (!item.categoryPreorderCutoffEnabled) {
    return true;
  }

  final cutoff = _parseCutoffTime(item.categoryPreorderCutoffTime);

  if (cutoff == null) {
    return true;
  }

  final now = cafeNow();
  final nowMinutes = now.hour * 60 + now.minute;
  final cutoffMinutes = cutoff.hour * 60 + cutoff.minute;

  return nowMinutes < cutoffMinutes;
}

String catalogItemCannotOrderReason(CatalogItem item) {
  if (catalogItemCanOrderNow(item)) {
    return '';
  }

  final cutoff = item.categoryPreorderCutoffTime.trim();

  if (item.categoryPreorderLeadDays > 0) {
    return (
      'Заказ этой позиции сегодня принимается до $cutoff. '
      'Минимум за ${item.categoryPreorderLeadDays} сут.'
    );
  }

  return 'Заказ этой позиции сегодня принимается до $cutoff.';
}

List<String> cartPreorderBlockedTitles(List<CartItem> items) {
  return items
      .where((item) => !catalogItemCanOrderNow(item.product))
      .map((item) => item.displayTitle)
      .toList();
}

String? cartPreorderBlockMessage(List<CartItem> items) {
  final blocked = cartPreorderBlockedTitles(items);

  if (blocked.isEmpty) {
    return null;
  }

  final reasonItem = items.firstWhere(
    (item) => !catalogItemCanOrderNow(item.product),
  );
  final reason = catalogItemCannotOrderReason(reasonItem.product);

  return 'Сейчас нельзя заказать: ${blocked.join(', ')}. $reason';
}

DateTime? _parseCutoffTime(String? raw) {
  final value = raw?.trim() ?? '';

  if (value.isEmpty) {
    return null;
  }

  final parts = value.split(':');

  if (parts.length < 2) {
    return null;
  }

  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);

  if (hour == null || minute == null) {
    return null;
  }

  return DateTime(2000, 1, 1, hour, minute);
}
