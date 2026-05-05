import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/thought.dart';
import 'screens/home_screen.dart';
import 'services/app_settings.dart';
import 'package:mindgalaxy/l10n/app_localizations.dart';
import 'utils/admob_test_device_debug.dart';

const String _categoryCanonicalMigrationDoneKey =
    'migration_category_canonical_v1_done';
const Set<String> _canonicalCategories = {
  'neutral',
  'future',
  'past',
  'emotion',
  'action',
};
// Migration-only aliases for historical data normalization.
// NOTE: UI labels are localized via AppLocalizations in each screen.
const Map<String, String> _legacyCategoryNormalizationAliases = {
  '未来': 'future',
  'future': 'future',
  '↑ 未来': 'future',
  'up: future': 'future',
  '過去': 'past',
  'past': 'past',
  '↓ 過去': 'past',
  'down: past': 'past',
  '感情': 'emotion',
  'emotion': 'emotion',
  '← 感情': 'emotion',
  'left: emotion': 'emotion',
  '行動': 'action',
  'action': 'action',
  '行動 →': 'action',
  'action: right': 'action',
  '未分類': 'neutral',
  'uncategorized': 'neutral',
  'neutral': 'neutral',
};

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // iOS requires GADApplicationIdentifier in Info.plist; the native SDK still
  // validates on launch even when Dart-side ad units are gated by kShowAds.
  await MobileAds.instance.initialize();
  await AdMobTestDeviceDebug.logDiagnostics();
  await Hive.initFlutter();
  Hive.registerAdapter(ThoughtAdapter());
  await Hive.openBox<Thought>('thoughts');
  await Hive.openBox('settings');
  await AppSettings.ensureDefaults();
  await _runCategoryCanonicalMigrationOnce();
  await _removeLegacyScreenshotSeedThoughtsOnce();
  runApp(const MindGalaxyApp());
}

/// One-time cleanup of demo `Thought`s left by the removed screenshot-seeding build.
const String _legacyScreenshotClusterId = 'mg_screenshot_seed';
const String _legacyScreenshotPurgeDoneKey = 'legacy_mg_screenshot_seed_purged_v1';

Future<void> _removeLegacyScreenshotSeedThoughtsOnce() async {
  final settings = Hive.box('settings');
  if (settings.get(_legacyScreenshotPurgeDoneKey, defaultValue: false) as bool) {
    return;
  }
  final box = Hive.box<Thought>('thoughts');
  for (final t in box.values.toList()) {
    if (t.clusterId == _legacyScreenshotClusterId) {
      t.delete();
    }
  }
  await settings.put(_legacyScreenshotPurgeDoneKey, true);
}

Future<void> _runCategoryCanonicalMigrationOnce() async {
  final settingsBox = Hive.box('settings');
  final alreadyDone = settingsBox.get(_categoryCanonicalMigrationDoneKey,
      defaultValue: false) as bool;
  if (alreadyDone) return;

  final thoughtsBox = Hive.box<Thought>('thoughts');
  var updatedCount = 0;
  for (final thought in thoughtsBox.values) {
    final normalized = _normalizeCategory(thought.category);
    if (normalized == thought.category) continue;
    thought.category = normalized;
    await thought.save();
    updatedCount++;
  }

  await settingsBox.put(_categoryCanonicalMigrationDoneKey, true);
  debugPrint('Category migration completed. Updated $updatedCount thoughts.');
}

String _normalizeCategory(String raw) {
  final trimmed = raw.trim();
  if (_canonicalCategories.contains(trimmed)) return trimmed;

  final lowered = trimmed.toLowerCase();
  if (_canonicalCategories.contains(lowered)) return lowered;

  final mappedByRaw = _legacyCategoryNormalizationAliases[trimmed];
  if (mappedByRaw != null) return mappedByRaw;

  final mappedByLower = _legacyCategoryNormalizationAliases[lowered];
  if (mappedByLower != null) return mappedByLower;

  return 'neutral';
}

class MindGalaxyApp extends StatelessWidget {
  const MindGalaxyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mind Galaxy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const HomeScreen(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
