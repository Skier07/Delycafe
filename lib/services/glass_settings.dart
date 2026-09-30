import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Conservative Android default; shader support alone doesn't indicate speed.
class GlassSettings extends ChangeNotifier {
  static final instance = GlassSettings();
  static const _key = 'liquid_glass_enabled';
  bool? _override;
  bool get enabled => _override ?? defaultTargetPlatform == TargetPlatform.iOS;
  Future<void> load() async {
    try {
      _override = (await SharedPreferences.getInstance()).getBool(_key);
      notifyListeners();
    } catch (_) {
      // Keep the platform default when local storage is unavailable.
    }
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(_key, enabled)) {
      throw StateError('Could not save glass preference');
    }
    _override = enabled;
    notifyListeners();
  }
}
