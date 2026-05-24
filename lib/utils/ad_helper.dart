import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// AdMob 広告ユニット。
class AdHelper {
  AdHelper._();

  /// AndroidManifest / Info.plist の APPLICATION_ID と一致させること。
  static const String sampleApplicationId =
      'ca-app-pub-3940256099942544~3347511713';

  static const String _androidBannerProduction =
      'ca-app-pub-8944199388403475/2951686334';
  static const String _iosBannerProduction =
      'ca-app-pub-8944199388403475/2951686334';

  static const String _androidRewardedProduction =
      'ca-app-pub-8944199388403475/9486139241';
  static const String _iosRewardedProduction =
      'ca-app-pub-8944199388403475/9486139241';

  /// バナー（[input_screen.dart]）。
  static String get bannerAdUnitId {
    if (kIsWeb) return _androidBannerProduction;
    if (Platform.isIOS) return _iosBannerProduction;
    return _androidBannerProduction;
  }

  /// リワード（[home_screen.dart] 流星群フロー）。
  static String get rewardedAdUnitId {
    if (kIsWeb) return _androidRewardedProduction;
    if (Platform.isIOS) return _iosRewardedProduction;
    return _androidRewardedProduction;
  }
}
