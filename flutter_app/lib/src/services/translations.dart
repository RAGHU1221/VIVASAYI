import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class Translations {
  Translations._();

  static final Map<String, Map<String, dynamic>> _cache = {};

  static Future<void> preload(String localeCode) async {
    if (_cache.containsKey(localeCode)) return;
    final raw = await rootBundle.loadString('assets/lang/$localeCode.json');
    _cache[localeCode] = json.decode(raw) as Map<String, dynamic>;
  }

  /// Looks up a dot-separated [key] (e.g. "settings.title") for [localeCode],
  /// falling back to English, then to the key itself if nothing is loaded yet.
  static String t(String localeCode, String key) {
    final table = _cache[localeCode] ?? _cache['en'];
    if (table == null) return key;

    dynamic value = table;
    for (final part in key.split('.')) {
      if (value is Map<String, dynamic> && value.containsKey(part)) {
        value = value[part];
      } else {
        return key;
      }
    }

    return value is String ? value : key;
  }
}
