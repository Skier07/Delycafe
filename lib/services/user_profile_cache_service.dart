import 'package:delycafe/data/hive/hive_boxes.dart';
import 'package:delycafe/models/user.dart';
import 'package:hive/hive.dart';

class UserProfileCacheService {
  Box get _box => Hive.box(HiveBoxes.user);

  User? read(String phone) {
    final raw = _box.get(_cacheKey(phone));

    if (raw is! Map) {
      return null;
    }

    try {
      return User.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> save(User user) async {
    await _box.put(_cacheKey(user.phone), user.toJson());
  }

  Future<void> clear(String phone) async {
    await _box.delete(_cacheKey(phone));
  }

  String _cacheKey(String phone) {
    return 'profile_${phone.replaceAll(RegExp(r'\D'), '')}';
  }
}
