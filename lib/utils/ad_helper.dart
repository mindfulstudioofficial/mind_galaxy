import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

/// AdMob 広告ユニット。
class AdHelper {
  AdHelper._();

  /// Android: AndroidManifest の APPLICATION_ID と一致。
  static const String androidApplicationId =
      'ca-app-pub-8944199388403475~6539577557';

  /// iOS: Info.plist の GADApplicationIdentifier と一致。
  static const String iosApplicationId =
      'ca-app-pub-8944199388403475~5449493172';

  // Google 公式テスト ID（debug ビルド用）
  static const String _androidBannerTest =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _iosBannerTest =
      'ca-app-pub-3940256099942544/2934735716';
  static const String _androidRewardedTest =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _iosRewardedTest =
      'ca-app-pub-3940256099942544/1712485313';

  // 本番 ID（release ビルド用）
  static const String _androidBannerProd =
      'ca-app-pub-8944199388403475/2951686334';
  static const String _androidRewardedProd =
      'ca-app-pub-8944199388403475/9486139241';
  static const String _iosBannerProd =
      'ca-app-pub-8944199388403475/5532572430';
  static const String _iosRewardedProd =
      'ca-app-pub-8944199388403475/4239975982';

  static bool get _useProductionAds => !kDebugMode;

  /// バナー（[input_screen.dart]）。
  static String get bannerAdUnitId {
    if (kIsWeb) return _androidBannerTest;
    if (Platform.isIOS) {
      return _useProductionAds ? _iosBannerProd : _iosBannerTest;
    }
    return _useProductionAds ? _androidBannerProd : _androidBannerTest;
  }

  /// リワード（[home_screen.dart] 流星群フロー）。
  static String get rewardedAdUnitId {
    if (kIsWeb) return _androidRewardedTest;
    if (Platform.isIOS) {
      return _useProductionAds ? _iosRewardedProd : _iosRewardedTest;
    }
    return _useProductionAds ? _androidRewardedProd : _androidRewardedTest;
  }
}
