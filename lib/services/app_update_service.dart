import 'dart:convert';
import 'dart:io';

import 'package:delycafe/utils/version_compare.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppUpdateInfo {
  final String currentVersion;
  final String storeVersion;
  final String storeUrl;

  const AppUpdateInfo({
    required this.currentVersion,
    required this.storeVersion,
    required this.storeUrl,
  });
}

/// Проверка новой версии в App Store / Google Play (не устанавливает обновление).
class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  static const _dismissedVersionKey = 'dismissed_store_version';

  Future<AppUpdateInfo?> checkForUpdate({bool ignoreDismissed = false}) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version.trim();

    if (currentVersion.isEmpty) {
      return null;
    }

    final lookup = await _lookupStoreVersion(packageInfo.packageName);

    if (lookup == null) {
      return null;
    }

    final storeVersion = lookup.version.trim();
    final storeUrl = lookup.url.trim();

    if (storeVersion.isEmpty ||
        storeUrl.isEmpty ||
        !isVersionGreater(storeVersion, currentVersion)) {
      return null;
    }

    if (!ignoreDismissed) {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getString(_dismissedVersionKey);

      if (dismissed == storeVersion) {
        return null;
      }
    }

    return AppUpdateInfo(
      currentVersion: currentVersion,
      storeVersion: storeVersion,
      storeUrl: storeUrl,
    );
  }

  Future<void> dismissVersion(String storeVersion) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedVersionKey, storeVersion.trim());
  }

  Future<_StoreLookup?> _lookupStoreVersion(String packageName) async {
    if (Platform.isIOS) {
      return _lookupAppleStore(packageName);
    }

    if (Platform.isAndroid) {
      return _lookupGooglePlay(packageName);
    }

    return null;
  }

  Future<_StoreLookup?> _lookupAppleStore(String bundleId) async {
    final uri = Uri.https(
      'itunes.apple.com',
      '/lookup',
      {
        'bundleId': bundleId,
        'country': 'ru',
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      return null;
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final results = decoded['results'];

    if (results is! List || results.isEmpty) {
      return null;
    }

    final first = results.first;

    if (first is! Map<String, dynamic>) {
      return null;
    }

    final version = first['version']?.toString() ?? '';
    final trackViewUrl = first['trackViewUrl']?.toString() ?? '';

    if (version.isEmpty || trackViewUrl.isEmpty) {
      return null;
    }

    return _StoreLookup(version: version, url: trackViewUrl);
  }

  Future<_StoreLookup?> _lookupGooglePlay(String packageName) async {
    final uri = Uri.https(
      'play.google.com',
      '/store/apps/details',
      {
        'id': packageName,
        'hl': 'ru',
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      return null;
    }

    final html = utf8.decode(response.bodyBytes);
    final version = _extractPlayStoreVersion(html);
    final url = uri.toString();

    if (version == null || version.isEmpty) {
      return null;
    }

    return _StoreLookup(version: version, url: url);
  }

  String? _extractPlayStoreVersion(String html) {
    final patterns = [
      RegExp(r'\[\[\["([0-9]+(?:\.[0-9]+)*)"\]\]'),
      RegExp(r'Current Version</div><span[^>]*><div[^>]*><span[^>]*>([^<]+)'),
      RegExp(r'itemprop="softwareVersion">([^<]+)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);

      if (match != null && match.groupCount >= 1) {
        final value = match.group(1)?.trim() ?? '';

        if (value.isNotEmpty) {
          return value;
        }
      }
    }

    return null;
  }
}

class _StoreLookup {
  final String version;
  final String url;

  const _StoreLookup({
    required this.version,
    required this.url,
  });
}
