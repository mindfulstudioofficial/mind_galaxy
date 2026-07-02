import 'package:flutter/foundation.dart';

/// デモ・スクショなどで広告だけ切りたいとき。
/// 例: `--dart-define=DISABLE_ADS=true`
const bool _kDisableAds =
    bool.fromEnvironment('DISABLE_ADS', defaultValue: false);

/// テスター配布などでテスト広告だけ使いたいとき。
/// 例: `--dart-define=FORCE_TEST_ADS=true`
const bool kForceTestAds =
    bool.fromEnvironment('FORCE_TEST_ADS', defaultValue: false);

/// 星の再訪フローを実機・シミュレータで確認するときのみ。
/// 例: `flutter run --dart-define=FORCE_REVISIT_DEBUG=true`
const bool kForceRevisitDebug =
    bool.fromEnvironment('FORCE_REVISIT_DEBUG', defaultValue: false);

/// バナー・リワードを表示するか。Web のみオフ。
bool get kShowAds => !kIsWeb && !_kDisableAds;
