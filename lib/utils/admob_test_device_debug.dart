import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// デバッグ時のみ、`RequestConfiguration` とテスト機器ハッシュ取得手順をログに出力する。
abstract final class AdMobTestDeviceDebug {
  AdMobTestDeviceDebug._();

  /// 現在適用されている [RequestConfiguration]（特に `testDeviceIds`）を確認します。
  ///
  /// ハッシュ済みテスト機器 ID は Flutter 側 API には出ません。初めて広告を読み込むと、
  /// ネイティブ側ログに **`Use RequestConfiguration.Builder().setTestDeviceIds(...)`**
  /// に相当する文言とともに一覧が出力されます。その文字列を [RequestConfiguration]
  /// の `testDeviceIds` に反映してください。
  static Future<void> logDiagnostics({String tag = '[AdMob test device]'}) async {
    if (!kDebugMode) return;
    debugPrint('');
    debugPrint('$tag RequestConfiguration を取得しています…');
    try {
      final cfg = await MobileAds.instance.getRequestConfiguration();
      debugPrint('$tag ── MobileAds に登録済み ──');
      debugPrint('$tag testDeviceIds: ${cfg.testDeviceIds ?? '(未設定/null)'}');
      debugPrint(
        '$tag maxAdContentRating: ${cfg.maxAdContentRating ?? '(未設定)'}',
      );
      debugPrint(
        '$tag tagForChildDirectedTreatment: '
        '${cfg.tagForChildDirectedTreatment ?? '(未設定)'}',
      );
      debugPrint(
        '$tag tagForUnderAgeOfConsent: '
        '${cfg.tagForUnderAgeOfConsent ?? '(未設定)'}',
      );
    } catch (e) {
      // google_mobile_ads はネイティブが未設定リストを返すと decode 側で例外になることがある。
      debugPrint(
        '$tag RequestConfiguration は取得できませんでした '
        '(未登録またはプラットフォーム差): $e',
      );
      debugPrint('$tag → 設定の確認は下記「ハッシュ済み ID」手順またはネイティブログへ。');
    }
    _logHowToFindHashedDeviceIds(tag);
    debugPrint('');
  }

  static void _logHowToFindHashedDeviceIds(String tag) {
    debugPrint('$tag ── ハッシュ済みテスト機器 ID を取るには ──');
    debugPrint(
      '$tag 1) アプリからバナー/リワードなど実際に広告を 1 回読み込む',
    );
    debugPrint('$tag 2) 次のコンソールを開き、「RequestConfiguration」「testDevice」「Ads」などで検索');
    debugPrint('$tag Android:');
    debugPrint(
      '$tag   adb logcat | grep -Ei \'RequestConfiguration|testDeviceIds|Ads\'',
    );
    debugPrint('$tag iOS Simulator / 実機:');
    debugPrint('$tag   Xcode の Run コンソール、または Devices and Simulators でログ確認');
    debugPrint(
      '$tag 3) 表示されたハッシュ（例: 16進大文字など）を '
      '`MobileAds.instance.updateRequestConfiguration('
      'RequestConfiguration(testDeviceIds: [\'...\']))` に追加',
    );
    debugPrint(
      '$tag 参考: https://developers.google.com/admob/flutter/test-ads',
    );
  }
}
