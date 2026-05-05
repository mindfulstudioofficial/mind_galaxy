import 'package:flutter/foundation.dart';

/// Resolves AdMob ad unit IDs by platform:
/// - **iOS**: production units (Mind Galaxy / AdMob console).
/// - **Android**: Google's official [demo test units][demo] (safe during dev; replace
///   with your own Android production IDs before Play release if needed).
///
/// [demo]: https://developers.google.com/admob/android/test-ads
class AdHelper {
  AdHelper._();

  /// iOS & general fallback — production banner.
  static const String _prodBannerAdUnitId =
      'ca-app-pub-8944199388403475/2951686334';

  /// iOS & general fallback — production rewarded.
  static const String _prodRewardedAdUnitId =
      'ca-app-pub-8944199388403475/9486139241';

  /// Android — Google sample banner (test).
  static const String _androidTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  /// Android — Google sample rewarded (test).
  static const String _androidTestRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  static bool get _useAndroidTestIds =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Banner placement ([input_screen.dart]).
  static String get bannerAdUnitId =>
      _useAndroidTestIds ? _androidTestBannerAdUnitId : _prodBannerAdUnitId;

  /// Rewarded placement ([home_screen.dart] meteor shower flow).
  static String get rewardedAdUnitId => _useAndroidTestIds
      ? _androidTestRewardedAdUnitId
      : _prodRewardedAdUnitId;
}
