import 'package:delycafe/utils/app_timezone.dart';

/// Правила приёма заказов (время кафе: Asia/Yekaterinburg).
class DeliverySchedule {
  DeliverySchedule._();

  static const int openHour = 10;
  static const int openMinute = 0;
  static const int slotIntervalMinutes = 5;

  static DateTime get now => cafeNow();

  static Duration leadTime(String deliveryTypeApi) {
    if (deliveryTypeApi == 'tatysh') {
      return const Duration(hours: 2);
    }

    return const Duration(hours: 1, minutes: 30);
  }

  static bool isAnyOrderingOpen(DateTime now) {
    if (!_isWithinKitchenHours(now)) {
      return false;
    }

    const types = ['ozersk', 'promploshadka', 'tatysh', 'pickup'];

    return types.any((type) => _canDeliverToday(now, type));
  }

  static bool isOrderingOpen(DateTime now, String deliveryTypeApi) {
    if (!_isWithinKitchenHours(now)) {
      return false;
    }

    return _canDeliverToday(now, deliveryTypeApi);
  }

  /// До 10:00 или с 20:30 (вс–чт) / 21:30 (пт–сб) — кухня закрыта.
  static bool isKitchenClosed(DateTime now) {
    return !_isWithinKitchenHours(now);
  }

  static bool _isWithinKitchenHours(DateTime now) {
    if (now.isBefore(_openOnDate(now))) {
      return false;
    }

    return now.isBefore(_closingTimeOnDate(now));
  }

  static bool _canDeliverToday(DateTime now, String deliveryTypeApi) {
    final minDelivery = minDeliveryTime(now, deliveryTypeApi);
    final maxDelivery = maxDeliveryTime(now);

    return !minDelivery.isAfter(maxDelivery);
  }

  static DateTime nextOrderingOpensAt(DateTime now) {
    final todayOpen = _openOnDate(now);

    if (now.isBefore(todayOpen)) {
      return todayOpen;
    }

    final nextDay = cafeDateTime(now.year, now.month, now.day).add(
      const Duration(days: 1),
    );

    return _openOnDate(nextDay);
  }

  static DateTime minDeliveryTime(DateTime now, String deliveryTypeApi) {
    final todayOpen = _openOnDate(now);
    final earliest = now.add(leadTime(deliveryTypeApi));

    if (earliest.isBefore(todayOpen)) {
      return todayOpen;
    }

    return earliest;
  }

  static DateTime maxDeliveryTime(DateTime now) {
    return _closingTimeOnDate(now);
  }

  static List<DateTime> availableSlots(DateTime now, String deliveryTypeApi) {
    if (!isOrderingOpen(now, deliveryTypeApi)) {
      return const [];
    }

    final minSlot = _roundUpToInterval(
      minDeliveryTime(now, deliveryTypeApi),
      slotIntervalMinutes,
    );
    final maxSlot = maxDeliveryTime(now);

    final slots = <DateTime>[];
    var cursor = minSlot;

    while (!cursor.isAfter(maxSlot)) {
      slots.add(cursor);
      cursor = cursor.add(
        const Duration(minutes: slotIntervalMinutes),
      );
    }

    return slots;
  }

  static String formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  static String formatNextOpening(DateTime now) {
    final opensAt = nextOrderingOpensAt(now);
    final today = cafeDateTime(now.year, now.month, now.day);
    final opensDay = cafeDateTime(opensAt.year, opensAt.month, opensAt.day);

    if (opensDay == today) {
      return 'сегодня в ${formatTime(opensAt)}';
    }

    final tomorrow = today.add(const Duration(days: 1));

    if (opensDay == tomorrow) {
      return 'завтра в ${formatTime(opensAt)}';
    }

    return '${opensAt.day.toString().padLeft(2, '0')}.'
        '${opensAt.month.toString().padLeft(2, '0')} '
        'в ${formatTime(opensAt)}';
  }

  static String closedMessage(DateTime now) {
    return 'Приём заказов закрыт. Оформление снова будет доступно '
        '${formatNextOpening(now)}.';
  }

  static DateTime firstSlotAfterOpen(
    DateTime openAt,
    String deliveryTypeApi,
  ) {
    final earliest = openAt.add(leadTime(deliveryTypeApi));

    return _roundUpToInterval(earliest, slotIntervalMinutes);
  }

  static DateTime displayAsapSlot(DateTime now, String deliveryTypeApi) {
    if (isOrderingOpen(now, deliveryTypeApi)) {
      return _roundUpToInterval(
        minDeliveryTime(now, deliveryTypeApi),
        slotIntervalMinutes,
      );
    }

    return firstSlotAfterOpen(
      nextOrderingOpensAt(now),
      deliveryTypeApi,
    );
  }

  static String asapChoiceLabel(DateTime now, String deliveryTypeApi) {
    final slot = displayAsapSlot(now, deliveryTypeApi);
    final time = formatTime(slot);

    if (isOrderingOpen(now, deliveryTypeApi)) {
      return 'к $time';
    }

    return 'завтра к $time';
  }

  static String previewTimeLabel(DateTime now, String deliveryTypeApi) {
    return formatTime(displayAsapSlot(now, deliveryTypeApi));
  }

  static bool isClosedUntilTomorrow(DateTime now) {
    if (now.isBefore(_openOnDate(now))) {
      return false;
    }

    return true;
  }

  static String closedSubmitButtonLabel(DateTime now) {
    return 'Кухня закрыта';
  }

  static String asapEstimateMessage(DateTime now, String deliveryTypeApi) {
    return 'Ориентировочно ${asapChoiceLabel(now, deliveryTypeApi)}';
  }

  static int _lastSlotHour(int weekday) {
    if (weekday == DateTime.friday || weekday == DateTime.saturday) {
      return 21;
    }

    return 20;
  }

  static int _lastSlotMinute(int weekday) {
    return 30;
  }

  static DateTime _openOnDate(DateTime date) {
    return cafeDateTime(
      date.year,
      date.month,
      date.day,
      openHour,
      openMinute,
    );
  }

  static DateTime _closingTimeOnDate(DateTime date) {
    return cafeDateTime(
      date.year,
      date.month,
      date.day,
      _lastSlotHour(date.weekday),
      _lastSlotMinute(date.weekday),
    );
  }

  static DateTime _roundUpToInterval(DateTime value, int intervalMinutes) {
    final totalMinutes = value.hour * 60 + value.minute;
    final remainder = totalMinutes % intervalMinutes;

    if (remainder == 0 &&
        value.second == 0 &&
        value.millisecond == 0 &&
        value.microsecond == 0) {
      return cafeDateTime(
        value.year,
        value.month,
        value.day,
        value.hour,
        value.minute,
      );
    }

    final roundedMinutes = totalMinutes + (intervalMinutes - remainder);

    return cafeDateTime(value.year, value.month, value.day).add(
      Duration(minutes: roundedMinutes),
    );
  }
}
