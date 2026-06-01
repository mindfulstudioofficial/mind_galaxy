import 'package:flutter/foundation.dart';

/// デモ・スクショなどで広告だけ切りたいとき。
/// 例: `--dart-define=DISABLE_ADS=true`
const bool _kDisableAds =
    bool.fromEnvironment('DISABLE_ADS', defaultValue: false);

/// テスター配布中は本番広告を避けるため、デフォルトでテスト広告を強制する。
/// ただし iOS release 起動時は [AdHelper] 側で本番広告を優先する。
const bool kForceTestAds =
    bool.fromEnvironment('FORCE_TEST_ADS', defaultValue: true);

/// バナー・リワードを表示するか。Web のみオフ。
bool get kShowAds => !kIsWeb && !_kDisableAds;
