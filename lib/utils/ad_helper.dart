/// AdMob 広告ユニット（Mind Galaxy／AdMob コンソールの本番 ID）。
///
/// Android / iOS ともに同一アプリ内でこの ID を参照します。
class AdHelper {
  AdHelper._();

  static const String _bannerAdUnitId =
      'ca-app-pub-8944199388403475/2951686334';

  static const String _rewardedAdUnitId =
      'ca-app-pub-8944199388403475/9486139241';

  /// バナー（[input_screen.dart]）。
  static String get bannerAdUnitId => _bannerAdUnitId;

  /// リワード（[home_screen.dart] 流星群フロー）。
  static String get rewardedAdUnitId => _rewardedAdUnitId;
}
