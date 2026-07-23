import 'package:delycafe/utils/app_timezone.dart';

/// Правила приёма заказов (время кафе: Asia/Yekaterinburg).
class DeliverySchedule {
  DeliverySchedule._();

  static const int openHour = 10;
  static const int openMinute = 0;
  static const int slotIntervalMinutes = 5;

  static const int sundayThroughThursdayCloseHour = 20;
  static const int sundayThroughThursdayCloseMinute = 30;
  static const int fridaySaturdayCloseHour = 21;
  static const int fridaySaturdayCloseMinute = 30;

  /// Текст для UI: вс–чт до 20:30, пт–сб до 21:30.
  static const String acceptanceHoursShort =
      'вс–чт до 20:30, пт–сб до 21:30';

  static const String acceptanceHoursLong =
      'Приём заказов: с 10:00, вс–чт до 20:30, пт–сб до 21:30';

  static DateTime get now => cafeNow();

  static Duration leadTime(String deliveryTypeApi) {
    if (deliveryTypeApi == 'tatysh') {
      return const Duration(hours: 2);
    }

    return const Duration(hours: 1, minutes: 30);
  }

  /// Приём заказов открыт: с 10:00 до 20:30 (вс–чт) / 21:30 (пт–сб).
  static bool isAcceptingOrders(DateTime now) {
    return _isWithinKitchenHours(now);
  }

  static bool isAnyOrderingOpen(DateTime now) {
    return isAcceptingOrders(now);
  }

  /// Есть ли сегодня слот доставки с учётом lead time.
  static bool isOrderingOpen(DateTime now, String deliveryTypeApi) {
    if (!isAcceptingOrders(now)) {
      return false;
    }

    return _canDeliverToday(now, deliveryTypeApi);
  }

  /// До 10:00 или с 20:30 (вс–чт) / 21:30 (пт–сб) — кухня закрыта.
  static bool isKitchenClosed(DateTime now) {
    return !isAcceptingOrders(now);
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
    if (!isAcceptingOrders(now)) {
      return const [];
    }

    final minSlot = _roundUpToInterval(
      minDeliveryTime(now, deliveryTypeApi),
      slotIntervalMinutes,
    );
    final maxSlot = maxDeliveryTime(now);

    if (minSlot.isAfter(maxSlot)) {
      return [maxSlot];
    }

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
    if (isAcceptingOrders(now)) {
      final earliest = minDeliveryTime(now, deliveryTypeApi);
      final latest = maxDeliveryTime(now);
      final target = earliest.isAfter(latest) ? latest : earliest;

      return _roundUpToInterval(
        target,
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

    if (isAcceptingOrders(now)) {
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
    if (_isFridayOrSaturday(weekday)) {
      return fridaySaturdayCloseHour;
    }

    return sundayThroughThursdayCloseHour;
  }

  static int _lastSlotMinute(int weekday) {
    if (_isFridayOrSaturday(weekday)) {
      return fridaySaturdayCloseMinute;
    }

    return sundayThroughThursdayCloseMinute;
  }

  static bool _isFridayOrSaturday(int weekday) {
    return weekday == DateTime.friday || weekday == DateTime.saturday;
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
