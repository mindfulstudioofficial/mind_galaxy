import 'package:flutter/foundation.dart';

/// デモ・スクショなどで広告だけ切りたいとき。
/// 例: `--dart-define=DISABLE_ADS=true`
const bool _kDisableAds =
    bool.fromEnvironment('DISABLE_ADS', defaultValue: false);

/// バナー・リワードを表示するか。Web のみオフ。
bool get kShowAds => !kIsWeb && !_kDisableAds;
