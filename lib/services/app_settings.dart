import 'package:hive/hive.dart';

class AppSettings {
  AppSettings._();

  static const String _boxName = 'settings';
  static const String _isPremiumKey = 'isPremium';
  static const String _meteorExpiryTimeKey = 'meteorExpiryTime';

  static Box get _box => Hive.box(_boxName);

  static bool get isPremium =>
      _box.get(_isPremiumKey, defaultValue: false) as bool;

  static Future<void> ensureDefaults() async {
    if (!_box.containsKey(_isPremiumKey)) {
      await _box.put(_isPremiumKey, false);
    }
    if (!_box.containsKey(_meteorExpiryTimeKey)) {
      await _box.put(_meteorExpiryTimeKey, null);
    }
  }

  static Future<void> setIsPremium(bool value) =>
      _box.put(_isPremiumKey, value);

  static DateTime? get meteorExpiryTime {
    final raw = _box.get(_meteorExpiryTimeKey) as String?;
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static Future<void> setMeteorExpiryTime(DateTime? value) =>
      _box.put(_meteorExpiryTimeKey, value?.toIso8601String());
}
