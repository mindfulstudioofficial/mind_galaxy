import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/thought.dart';
import 'screens/home_screen.dart';
import 'services/app_settings.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

const String _categoryCanonicalMigrationDoneKey =
    'migration_category_canonical_v1_done';
const Set<String> _canonicalCategories = {
  'neutral',
  'future',
  'past',
  'emotion',
  'action',
};
const Map<String, String> _legacyCategoryAliasMap = {
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
  await Hive.initFlutter();
  Hive.registerAdapter(ThoughtAdapter());
  await Hive.openBox<Thought>('thoughts');
  await Hive.openBox('settings');
  await AppSettings.ensureDefaults();
  await _runCategoryCanonicalMigrationOnce();
  runApp(const MindGalaxyApp());
}

Future<void> _runCategoryCanonicalMigrationOnce() async {
  final settingsBox = Hive.box('settings');
  final alreadyDone =
      settingsBox.get(_categoryCanonicalMigrationDoneKey, defaultValue: false)
          as bool;
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

  final mappedByRaw = _legacyCategoryAliasMap[trimmed];
  if (mappedByRaw != null) return mappedByRaw;

  final mappedByLower = _legacyCategoryAliasMap[lowered];
  if (mappedByLower != null) return mappedByLower;

  return 'neutral';
}

class MindGalaxyApp extends StatelessWidget {
  const MindGalaxyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MindGalaxy',
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