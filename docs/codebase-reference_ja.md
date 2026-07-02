# MindGalaxy コードベースリファレンス

このドキュメントは、MindGalaxy（Flutter アプリ、v1.3.7+20）のソースコード構造・モジュール・データモデル・技術スタックを説明します。NotebookLM 等でコード理解のための参照資料として使えます。

---

## 1. プロジェクト概要

| 項目 | 内容 |
|------|------|
| 名前 | mindgalaxy |
| 説明 | 思考を「星」として宇宙に配置し、振り返りを支援するメンタルウェルネス系アプリ |
| フレームワーク | Flutter (Dart SDK >=3.4.0) |
| パッケージ ID | `studio.mindful.mindgalaxy` |
| 対応プラットフォーム | iOS, Android, Web, macOS, Windows, Linux（主要機能はモバイル向け） |
| ローカライズ | 日本語・英語（`flutter gen-l10n`） |

### 主要依存関係

- **Hive / hive_flutter** — ローカル永続化（思考データ・設定）
- **shared_preferences** — （間接利用）
- **firebase_core, firebase_auth, firebase_analytics** — 認証・分析（オプション）
- **google_sign_in, sign_in_with_apple** — ソーシャルログイン
- **google_mobile_ads** — バナー・リワード広告（Web 除く）
- **share_plus, screenshot, path_provider, file_picker** — バックアップ・週間銀河シェア
- **url_launcher** — プライバシーポリシー・メールサポート
- **flutter_svg** — Google ロゴアイコン

---

## 2. ディレクトリ構造

```
lib/
├── main.dart                 # エントリポイント、Hive 初期化、マイグレーション
├── config/
│   └── ads_config.dart       # 広告表示フラグ、デバッグ用 dart-define
├── models/
│   ├── thought.dart          # コアデータモデル（HiveObject）
│   ├── thought.g.dart        # Hive TypeAdapter（自動生成）
│   └── star_tag.dart         # カテゴリ enum（参考用）
├── services/
│   ├── thought_repository.dart  # Hive Box への CRUD
│   ├── thought_service.dart     # Repository ラッパー（薄い層）
│   ├── app_settings.dart        # 設定 Box（プレミアム、認証、流星群期限）
│   ├── auth_service.dart        # Firebase 認証
│   └── backup_service.dart      # JSON エクスポート/インポート
├── screens/
│   ├── home_screen.dart         # メイン画面（最大・中核、約2900行）
│   ├── input_screen.dart        # 思考入力画面
│   ├── settings_screen.dart     # 設定・バックアップ・ログイン
│   └── weekly_galaxy_screen.dart # 週間振り返り可視化
├── widgets/
│   ├── central_star.dart        # 中央の再訪トリガー星
│   ├── thought_star.dart        # 個々の思考星（ドラッグ・表示）
│   ├── tutorial_category_compass.dart # チュートリアル用方位コンパス
│   ├── constellation_lines_overlay.dart
│   ├── constellation_resonance_overlay.dart
│   └── reflection_dialog.dart
├── overlays/
│   ├── thought_popup.dart       # 再訪ダイアログ
│   └── tutorial_overlay.dart    # 汎用オーバーレイラッパー
├── utils/
│   ├── colors.dart, styles.dart, constants.dart
│   ├── responsive_layout.dart   # タブレット対応
│   ├── constellation_layout.dart # 星座スロット計算
│   ├── constellation_naming.dart # 星座名生成
│   ├── revisit_prompt.dart      # 再訪プロンプト・スケジュール
│   ├── ad_helper.dart           # AdMob ユニット ID
│   ├── admob_test_device_debug.dart
│   └── web_image_download.dart
└── l10n/
    ├── app_ja.arb, app_en.arb
    └── app_localizations*.dart  # 自動生成
```

---

## 3. エントリポイント（main.dart）

起動時の処理順:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `MobileAds.instance.initialize()` — iOS は Info.plist 検証のため常に初期化
3. `Hive.initFlutter()` + `ThoughtAdapter` 登録
4. `Hive.openBox<Thought>('thoughts')` と `Hive.openBox('settings')`
5. `AppSettings.ensureDefaults()`
6. `AuthService.initialize()` — Firebase 利用可能なら Analytics も
7. **カテゴリ正規化マイグレーション**（一度だけ）— 旧ラベル（「未来」「↑ 未来」等）を canonical キーへ
8. **スクリーンショット用シードデータ削除**（一度だけ）
9. `runApp(MindGalaxyApp())` — `MaterialApp`、ダークテーマ、`HomeScreen` が home

### カテゴリ canonical 値

`neutral`, `future`, `past`, `emotion`, `action`

UI 表示は `AppLocalizations` でローカライズ。DB には英語キーで保存。

---

## 4. データモデル: Thought

`lib/models/thought.dart` — `@HiveType(typeId: 0)`

| HiveField | 型 | 説明 |
|-----------|-----|------|
| 0 | int | id（アプリ内でインクリメント管理） |
| 1, 2 | double | dx, dy（画面上の座標） |
| 3 | String | content（思考本文、必須） |
| 4 | String? | insight（気づき） |
| 5 | String? | action（行動） |
| 6 | String | category（タグ。`tag` getter は alias） |
| 7 | bool | isDeleting（削除アニメーション中） |
| 8 | DateTime | createdAt |
| 9 | DateTime? | revisitAt（次回再訪予定） |
| 10 | String? | clusterId（週・星団用、将来拡張） |
| 11 | bool | isArchived（銀河アーカイブ済み） |
| 12 | int | revisitCount（0=未、1=1日後、2=3日後、3=7日後…） |
| 13–15 | double | starSize, glowIntensity, particleSpread（見た目パラメータ） |

非永続フィールド: `isDragging`

### 再訪タイミング判定

`isReadyToRevisit`: 作成から 24h / 72h / 168h の各タイミング ±18h 以内

---

## 5. 永続化レイヤー

### Hive Box

| Box 名 | 型 | 用途 |
|--------|-----|------|
| `thoughts` | `Thought` | 全思考データ |
| `settings` | dynamic | アプリ設定 |

### AppSettings（settings Box のキー）

- `isPremium` — プレミアム（広告非表示、将来課金用）
- `meteorExpiryTime` — 流星群報酬の有効期限（ISO8601 文字列）
- `authProvider`, `authDisplayName` — ログイン状態
- `tutorialDone` — チュートリアル完了
- `reflectionDailyCountDay`, `reflectionDailyCount` — 日次再訪クォータ
- マイグレーション用フラグ各種

### ThoughtRepository

- `fetchAll()`, `add()`, `save()`, `delete()` — Hive Box の薄いラッパー

### BackupService

- **schemaVersion: 1** の JSON
- `exportToJson()` / `shareBackupFile()` — 共有シートでエクスポート
- `importAndReplace()` — 全件置換インポート（検証後 all-or-nothing）

---

## 6. 認証（AuthService）

- Firebase 初期化失敗時は `_firebaseAvailable = false` でグレースフルデグレード
- Google / Apple サインイン → Firebase User → `AppSettings.setLoggedInUser()`
- ログアウト時は Firebase + GoogleSignIn + AppSettings をクリア
- **データ同期は未実装** — ログインは将来の端末引き継ぎ用の準備

---

## 7. 画面別コード解説

### 7.1 HomeScreen（`lib/screens/home_screen.dart`）

アプリの中核。状態が最も多い。

**主要 State 変数:**

- `_thoughts` — ホームに表示する星（最大 30 件、新しい順）
- `_observationThoughts` — 観測モード用（全件、古い順）
- `_isObservationMode` — 観測モード ON/OFF
- 星座関連: `_activeConstellation`, `_constellationMain`, `_constellationContext`, `_constellationFormed`, `_constellationFormationTargets`
- チュートリアル: `_tutorialStep`（0–7、8=完了 `_tutorialInteractiveStep`）
- 流星群: `_meteorTrails`, RewardedAd
- 再訪: `_revisitCenterPosition`, `_deleteHolePosition`

**主要メソッド:**

| メソッド | 役割 |
|----------|------|
| `_reflectionCandidates()` | 再訪候補星を 2–4 個選定 |
| `_startRevisitEvent()` | 中央星タップで星座形成開始 |
| `_animateConstellationFormation()` | 星を中央周辺スロットへアニメ移動 |
| `_openConstellationRevisit()` | ThoughtPopup 表示 → InputScreen へ |
| `_addThoughtFromInputResult()` | InputScreen から新規星作成 |
| `_checkBlackHoleSuckIn()` | 右上ブラックホール付近で削除 |
| `_toggleObservationMode()` | 縦スクロールタイムライン表示 |
| `_openFabInput()` | FAB → InputScreen |
| `_openWeeklyGalaxy()` | WeeklyGalaxyScreen |
| `_showRewardedMeteorAd()` | リワード広告 → 12h 流星群 |

**内包クラス:**

- `_MeteorTrail`, `_MeteorShowerPainter` — 流星描画
- `_TutorialWeeklyPreviewPainter` — チュートリアル週間プレビュー

**再訪スコアリング（`_reflectionScore`）:**

- action 未記入 +3, insight 未記入 +2, 長文 +1, 7日以上経過 +1

**日次再訪クォータ:**

- `_dailyReflectionLimit(now)` = 1〜3（日付ベースの疑似ランダム）
- 保存完了時のみ `_recordReflectionTriggered()` でカウント

### 7.2 InputScreen（`lib/screens/input_screen.dart`）

**2 モード:**

1. **シンプル入力** — content のみ
2. **まとめて入力** — content + insight + action

**星の見た目は入力に連動:**

- content 長 → `starSize`（1.0–2.8）
- insight 長 → `glowIntensity`（1.0–5.2）
- action 長 → `particleSpread`（1.0–5.8）、粒子表示

**保存フロー:**

- 新規: `Navigator.pop` で Map を返す → HomeScreen が Hive に追加
- 編集: `thoughtToEdit` を直接更新、`advanceRevisitScheduleOnSave` で再訪スケジュール進行
- 保存時 `ConstellationResonanceOverlay` で共鳴アニメーション

**広告:** フッターバナー（`kShowAds` && !Premium && モバイル）

### 7.3 SettingsScreen

- データエクスポート/インポート（BackupService + file_picker）
- Google / Apple ログイン UI
- プレミアムプラン（Coming Soon、無効化 ListTile）
- インポート成功時 `Navigator.pop(true)` → Home がリロード

### 7.4 WeeklyGalaxyScreen

- 週単位（月曜始まり）で Thought をフィルタ
- `_WeeklyGalaxyLayout` + `_WeeklyGalaxyPainter` で CustomPaint 描画
- カテゴリ別レイヤー: future → emotion → action → past → neutral
- `_WeeklySummary` — 件数・カテゴリ内訳・insight/action 数
- **Cinematic モード**: 30 件以上かつ 3 カテゴリ以上が各 5 件以上
- Screenshot + share_plus / Web ダウンロード

---

## 8. ウィジェット

### ThoughtStar

- ドラッグで位置変更・カテゴリ分類（方向: 上=future, 下=past, 左=emotion, 右=action）
- 長押しで詳細、タップでポップアップ
- 中央（revisitPosition）へドラッグで再訪トリガー（通常モード）
- ステージ: 0=content のみ, 1=+insight, 2=+action（粒子・グロー強化）
- `formationTarget` 指定時は星座形成アニメ中

### CentralStar

- 思考数バッジ、再訪クォータ赤ドット（`revisitCount`）
- パルスアニメーション

### TutorialCategoryCompass

- チュートリアル step 3 でドラッグ方向とカテゴリを視覚化

### ConstellationLinesOverlay

- ハブ（中央）から各メンバーへ光の線が順次接続

### ConstellationResonanceOverlay

- InputScreen 保存時の波紋・共鳴演出

### ThoughtPopup

- 星座名（`deriveConstellationName`）+ 再訪プロンプト（`revisitNavigationPrompt`）
- 「あとで」/「内容を更新する」

---

## 9. ユーティリティ

### constellation_layout.dart

`constellationLayoutSlots(count, center)` — 1〜4 星の極座標スロット

### constellation_naming.dart

カテゴリ構成から英語名プールを選び、`id` の XOR で決定。日本語は「〜座」サフィックス

### revisit_prompt.dart

- `applyRevisitSaveSchedule` — revisitCount 1→2（+1分）→3（+7日）→終了
- `applyRevisitSaveScheduleToGroup` — 星座グループ一括

### responsive_layout.dart

- `kTabletBreakpoint = 600`
- `ResponsiveContentWidth`, `showAdaptivePanel`

### ad_helper.dart / ads_config.dart

| dart-define | 効果 |
|-------------|------|
| `DISABLE_ADS=true` | 広告オフ |
| `FORCE_TEST_ADS=true` | テスト広告 ID |
| `FORCE_REVISIT_DEBUG=true` | 再訪を常時可能 |

`kShowAds` = !Web && !DISABLE_ADS

---

## 10. ローカライズ

- ARB ファイル: `lib/l10n/app_ja.arb`, `app_en.arb`
- `flutter: generate: true` で `AppLocalizations` 生成
- カテゴリ表示・チュートリアル・再訪プロンプト・設定文言など全 UI 文言

---

## 11. テスト

- `test/tutorial_category_compass_test.dart` — コンパス UI
- `test/responsive_layout_test.dart` — レスポンシブ

---

## 12. ビルド・ネイティブ設定

- Android: `android/app/google-services.json`, AdMob APPLICATION_ID
- iOS: `GoogleService-Info.plist`, Podfile
- アイコン: `flutter_launcher_icons`, `assets/icon/`
- Firebase セットアップ手順: `docs/firebase_auth_setup_ja.md`

---

## 13. コード生成

```bash
dart run build_runner build   # thought.g.dart (Hive)
flutter gen-l10n              # ローカライズ
```

---

## 14. アーキテクチャ上の特徴

1. **Repository パターンは薄い** — 実質 Hive を各画面が直接参照することも多い（特に HomeScreen）
2. **HomeScreen が God Object** — チュートリアル・星座・観測・流星・再訪・FAB を一元管理
3. **状態はローカルファースト** — クラウド同期なし、バックアップは手動 JSON
4. **カテゴリはドラッグ方向で決定** — DB は string キー、色は switch でマッピング
5. **見た目パラメータは入力時に計算して永続化** — ホーム・観測・週間銀河で再利用

---

## 15. ファイル間の依存関係（簡略）

```
main.dart
  → HomeScreen
      → InputScreen, SettingsScreen, WeeklyGalaxyScreen
      → ThoughtStar, CentralStar, ConstellationLinesOverlay
      → ThoughtPopup, TutorialCategoryCompass
      → Hive (Thought), AppSettings, AdHelper
  → AuthService, AppSettings (起動時)

InputScreen
  → ConstellationResonanceOverlay
  → Hive, AppSettings, revisit_prompt

SettingsScreen
  → BackupService, AuthService, file_picker

WeeklyGalaxyScreen
  → Hive, CustomPaint レイアウトエンジン（同一ファイル内）
```

---

*最終更新: プロジェクト v1.3.7+20 時点のソースに基づく*
