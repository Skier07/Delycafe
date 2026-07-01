import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const String cafeTimeZoneId = 'Asia/Yekaterinburg';

bool _timeZonesInitialized = false;
tz.Location? _cafeLocation;

/// Загружает базу часовых поясов. Вызывается из [main] при старте приложения.
void initializeAppTimezone() {
  if (_timeZonesInitialized) {
    return;
  }

  tz_data.initializeTimeZones();
  _cafeLocation = tz.getLocation(cafeTimeZoneId);
  _timeZonesInitialized = true;
}

tz.Location get cafeLocation {
  if (_cafeLocation == null) {
    initializeAppTimezone();
  }

  return _cafeLocation!;
}

/// Текущее время кафе (Озёрск), независимо от настроек устройства.
DateTime cafeNow() {
  return tz.TZDateTime.now(cafeLocation);
}

/// Дата и время в часовом поясе кафе.
DateTime cafeDateTime(
  int year,
  int month,
  int day, [
  int hour = 0,
  int minute = 0,
  int second = 0,
  int millisecond = 0,
  int microsecond = 0,
]) {
  return tz.TZDateTime(
    cafeLocation,
    year,
    month,
    day,
    hour,
    minute,
    second,
    millisecond,
    microsecond,
  );
}
