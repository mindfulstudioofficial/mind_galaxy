# Firebase Auth セットアップ手順（MindGalaxy）

この手順は、現在のプロジェクト設定値に合わせた最短ルートです。  
対象は **Google ログイン → Apple ログイン** の順です。

## 0. 事前に確定している値

- Android `applicationId`: `studio.mindful.mindgalaxy`
- iOS `Bundle ID`: `studio.mindful.mindgalaxy`
- Apple Team ID: `3BF9U87432`
- Android Debug SHA-1: `DE:DB:EF:7E:D9:53:5B:77:DD:C9:95:5C:47:70:49:BE:6D:96:B4:6D`
- Android Debug SHA-256: `F2:C1:9D:6E:1B:DF:7A:4F:EA:78:0B:BF:87:1D:8F:36:C2:E5:2B:5F:BF:75:43:89:E7:E9:BC:DF:4F:93:93:BF`

## 1. Firebase プロジェクト作成

1. [Firebase Console](https://console.firebase.google.com/) でプロジェクト作成
2. Authentication を有効化
3. Sign-in method で次を有効化
   - Google
   - Apple

## 2. Android アプリ登録（Googleログインの必須）

1. Firebase Console -> Project settings -> Your apps -> Android 追加
2. Android package name に `studio.mindful.mindgalaxy` を入力
3. SHA 証明書フィンガープリントを登録
   - まず Debug の SHA-1 / SHA-256 を登録
   - Play配布用は Play Console の **App signing certificate** の SHA-1 / SHA-256 も追加
4. `google-services.json` をダウンロードし、`android/app/google-services.json` に配置

## 3. iOS アプリ登録（Google / Apple の必須）

1. Firebase Console -> iOS 追加
2. iOS bundle ID に `studio.mindful.mindgalaxy` を入力
3. `GoogleService-Info.plist` をダウンロード
4. Xcodeで Runner ターゲットに追加（Copy items if needed をON）
5. `Info.plist` に URL Scheme を追加（`REVERSED_CLIENT_ID`）
   - 値は `GoogleService-Info.plist` 内の `REVERSED_CLIENT_ID`

## 4. Apple Sign In の Apple Developer 側設定

1. Apple Developer -> Identifiers -> App ID (`studio.mindful.mindgalaxy`) で **Sign In with Apple** をON
2. Xcode Runner target -> Signing & Capabilities で **Sign In with Apple** を追加
3. Apple Developer -> Identifiers -> **Services ID** を作成（例: `studio.mindful.mindgalaxy.signin`）
4. 作成した Services ID の Sign In with Apple 設定で次を登録
   - Primary App ID: `studio.mindful.mindgalaxy`
   - Return URL: `https://<firebase-project-id>.firebaseapp.com/__/auth/handler`
5. Apple Developer -> Keys で Sign In with Apple 用の `.p8` キーを作成し、Key ID を控える

## 5. Firebase 側 Apple Provider 設定（Android対応の必須）

1. Firebase Console -> Authentication -> Sign-in method -> Apple を開く
2. Apple Team ID / Key ID / Private Key (`.p8`) を入力
3. Service ID に、Apple Developerで作成した Services ID を入力
4. 保存後、許可済みリダイレクトURLとして次を利用
   - `https://<firebase-project-id>.firebaseapp.com/__/auth/handler`

## 6. Android で Apple ログインを有効化する実装値

`sign_in_with_apple` の Android は Web 認証フローを使うため、アプリ起動時に次を `--dart-define` で渡します。

- `APPLE_ANDROID_SERVICE_ID`  
  例: `studio.mindful.mindgalaxy.signin`
- `APPLE_ANDROID_REDIRECT_URI`  
  例: `https://mind-galaxy-d5589.firebaseapp.com/__/auth/handler`

実行例:

```bash
flutter run -d <android_device_id> \
  --dart-define=APPLE_ANDROID_SERVICE_ID=studio.mindful.mindgalaxy.signin \
  --dart-define=APPLE_ANDROID_REDIRECT_URI=https://mind-galaxy-d5589.firebaseapp.com/__/auth/handler
```

## 7. アプリ側の状態（実装済み）

- `firebase_core`, `firebase_auth`, `google_sign_in`, `sign_in_with_apple` を導入済み
- 起動時 `Firebase.initializeApp()` を実行
- 設定画面で
  - Google ログイン
  - Apple ログイン
  - ログアウト
  - ゲスト利用継続
  を実装済み

## 8. 動作確認

1. `flutter clean`
2. `flutter pub get`
3. `flutter run`（Android は Apple 用 `--dart-define` を付与）
4. 設定画面で
   - Google ログイン
   - Apple ログイン
   - ログアウト
   を順に確認

## 9. つまずきポイント

- `google-services.json` 未配置（AndroidでGoogleログイン失敗）
- `GoogleService-Info.plist` 未追加 or URL Scheme 未設定（iOSでGoogleログイン失敗）
- Play App Signing のSHA未登録（クローズドテスト環境でGoogleログイン失敗）
- Apple Capability 未設定（Appleログイン失敗）
- Apple Services ID / Firebase Apple Provider 未設定（AndroidでAppleログイン失敗）
- `APPLE_ANDROID_SERVICE_ID` / `APPLE_ANDROID_REDIRECT_URI` 未指定（AndroidでAppleログイン失敗）
