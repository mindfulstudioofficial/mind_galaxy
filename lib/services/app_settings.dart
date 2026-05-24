import 'package:hive/hive.dart';

class AppSettings {
  AppSettings._();

  static const String _boxName = 'settings';
  static const String _isPremiumKey = 'isPremium';
  static const String _meteorExpiryTimeKey = 'meteorExpiryTime';
  static const String _authProviderKey = 'authProvider';
  static const String _authDisplayNameKey = 'authDisplayName';

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
    if (!_box.containsKey(_authProviderKey)) {
      await _box.put(_authProviderKey, '');
    }
    if (!_box.containsKey(_authDisplayNameKey)) {
      await _box.put(_authDisplayNameKey, '');
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

  static String get authProvider =>
      (_box.get(_authProviderKey, defaultValue: '') as String).trim();

  static String get authDisplayName =>
      (_box.get(_authDisplayNameKey, defaultValue: '') as String).trim();

  static bool get isLoggedIn => authProvider.isNotEmpty;

  static Future<void> setLoggedInUser({
    required String provider,
    required String displayName,
  }) async {
    await _box.put(_authProviderKey, provider.trim());
    await _box.put(_authDisplayNameKey, displayName.trim());
  }

  static Future<void> signOut() async {
    await _box.put(_authProviderKey, '');
    await _box.put(_authDisplayNameKey, '');
  }
}
