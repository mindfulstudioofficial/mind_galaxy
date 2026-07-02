import 'dart:ui';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mindgalaxy/l10n/app_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/central_star.dart';
import '../widgets/thought_star.dart';
import '../widgets/tutorial_category_compass.dart';
import '../models/thought.dart';
import '../utils/constants.dart';
import '../config/ads_config.dart';
import '../services/app_settings.dart';
import '../utils/ad_helper.dart';
import '../utils/responsive_layout.dart';
import '../utils/revisit_prompt.dart';
import '../utils/constellation_layout.dart';
import '../utils/constellation_naming.dart';
import '../widgets/constellation_lines_overlay.dart';
import '../overlays/thought_popup.dart';
import 'input_screen.dart';
import 'settings_screen.dart';
import 'weekly_galaxy_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  static const String _supportEmail = 'mindful.studio.official@gmail.com';
  static const String _privacyPolicyUrl =
      'https://docs.google.com/document/d/e/2PACX-1vTbrdJ28P5n0d7xxAwNn9fOiTvXUEGbirNim-p8PwwnAIpFJd2y9cV-g6puFW7yPe_YG-eCyweE99Ow/pub';
  static const int _maxVisibleThoughts = 30;
  static const double _observationSpacing = 140.0;
  static const int _meteorMinActive = 1;
  static const int _meteorMaxActive = 3;
  static const double _tutorialDragVisualYOffset = 50.0;
  static const double _tutorialStarSpawnRightOffset = 64.0;
  static const double _tutorialStarSpawnVerticalOffset = -8.0;
  static const int _tutorialInteractiveStep = 5;
  final List<Offset> _smallStars = [];
  final Random _random = Random();
  final List<Thought> _thoughts = [];
  final List<Thought> _observationThoughts = [];
  bool _isObservationMode = false;
  double _observationScrollOffset = 0.0;
  final TextEditingController _observationSearchController =
      TextEditingController();
  String _observationSearchQuery = '';
  final List<int> _observationSearchMatches = <int>[];
  int _observationSearchMatchCursor = -1;
  int _thoughtIdCounter = 0;
  int? _spawnHighlightThoughtId;
  Timer? _spawnHighlightTimer;

  Offset _deleteHolePosition = Offset.zero; // 右上のゴミ箱用
  Offset _revisitCenterPosition = Offset.zero; // 中央の再訪用

  // 星座システム
  List<Thought> _activeConstellation = [];
  Thought? _constellationMain;
  List<Thought> _constellationContext = [];
  bool _constellationFormed = false;
  bool _isConstellationAnimating = false;
  String? _constellationName;
  final Map<int, Offset> _constellationOriginalPositions = {};
  final Map<int, Offset> _constellationFormationTargets = {};
  bool _showConstellationLines = false;
  bool _revisitDialogOpen = false;

  // オンボーディング管理
  int _tutorialStep = 0;
  String? _onboardingDraftContent;
  bool _tutorialCompleting = false;
  final TextEditingController _controller = TextEditingController();
  Offset _tutorialStar = Offset.zero;
  Offset? _tutorialDragTouchOffset;
  bool _isTutorialDragging = false;
  Offset _tutorialDragVector = Offset.zero;
  Color _tutorialStarColor = Colors.white;
  String? _tutorialDragPreviewCategory;
  bool _onboardingConstellationDemo = false;
  bool _onboardingStep4MessageVisible = false;
  List<Offset> _onboardingDemoGhostSlots = const [];
  List<Offset> _onboardingDemoAllSlots = const [];
  final bool _flashCenter = false;
  Timer? _refreshTimer;
  Timer? _meteorSpawnTimer;
  Timer? _meteorFrameTimer;
  final List<_MeteorTrail> _meteorTrails = [];
  RewardedAd? _rewardedAd;
  bool _isRewardAdLoading = false;
  bool _isRewardAdShowing = false;
  int _dailyReflectionCount = 0;

  void _resetTutorialStarPosition([Size? size]) {
    final viewport = size ?? MediaQuery.of(context).size;
    if (viewport.width <= 0 || viewport.height <= 0) {
      _tutorialStar = Offset.zero;
      return;
    }
    final centerX = viewport.width * 0.5;
    final centerY = viewport.height * 0.5;
    final minX = centerX + 28.0;
    final maxX = viewport.width - 64.0;
    final spawnX = maxX < minX
        ? centerX
        : (centerX + _tutorialStarSpawnRightOffset)
            .clamp(minX, maxX)
            .toDouble();

    final minY = viewport.height * 0.36;
    final maxY = centerY + 28.0;
    final spawnY = maxY < minY
        ? centerY
        : (centerY + _tutorialStarSpawnVerticalOffset)
            .clamp(minY, maxY)
            .toDouble();
    _tutorialStar = Offset(spawnX, spawnY);
  }

  @override
  void initState() {
    super.initState();

    final box = Hive.box<Thought>('thoughts');
    final settingsBox = Hive.box('settings');
    final allThoughts = _loadThoughtsFromBox(box);
    final isTutorialDone = settingsBox.get('tutorialDone', defaultValue: false);
    if (isTutorialDone) {
      _tutorialStep = _tutorialInteractiveStep;
    } else if (allThoughts.isNotEmpty) {
      unawaited(settingsBox.put('tutorialDone', true));
      _tutorialStep = _tutorialInteractiveStep;
    } else {
      _tutorialStep = 0;
    }
    _applyLoadedThoughts(allThoughts);
    _loadDailyReflectionState(settingsBox);
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          // 1分ごとにここが走り、再訪タイミングの星をチェックします
        });
      }
      _syncMeteorShowerState();
    });
    _syncMeteorShowerState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final size = MediaQuery.of(context).size;
      await _clampThoughtsToViewport(size);
      if (!mounted) return;

      for (int i = 0; i < 50; i++) {
        _smallStars.add(
          Offset(
            _random.nextDouble() * size.width,
            _random.nextDouble() * size.height,
          ),
        );
      }
      if (mounted) setState(() {});
    });
  }

  bool _isJapaneseLocale() {
    return Localizations.localeOf(context).languageCode.startsWith('ja');
  }

  static const Set<String> _validCategories = {
    'neutral',
    'future',
    'past',
    'emotion',
    'action',
  };

  String _normalizeCategory(String c) {
    if (_validCategories.contains(c)) return c;
    return 'neutral';
  }

  List<Thought> _loadThoughtsFromBox(Box<Thought> box) {
    final allThoughts = <Thought>[];
    for (final t in box.values) {
      if (t.isArchived) continue;
      final normalized = _normalizeCategory(t.category);
      if (normalized != t.category) {
        t.category = normalized;
        unawaited(t.save());
      }
      allThoughts.add(t);
      if (t.id >= _thoughtIdCounter) _thoughtIdCounter = t.id + 1;
    }
    return allThoughts;
  }

  void _applyLoadedThoughts(List<Thought> allThoughts) {
    _observationThoughts
      ..clear()
      ..addAll(allThoughts..sort((a, b) => a.createdAt.compareTo(b.createdAt)));
    allThoughts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _thoughts
      ..clear()
      ..addAll(allThoughts.take(_maxVisibleThoughts));
    _rebuildObservationSearchMatches();
  }

  /// Re-reads Hive after backup import so the UI matches stored data.
  Future<void> _reloadThoughtsFromHive() async {
    _thoughtIdCounter = 0;
    _spawnHighlightTimer?.cancel();
    _spawnHighlightThoughtId = null;

    final allThoughts =
        _loadThoughtsFromBox(Hive.box<Thought>('thoughts'));
    _applyLoadedThoughts(allThoughts);

    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    await _clampThoughtsToViewport(size);
    if (mounted) setState(() {});
  }

  Future<void> _clampThoughtsToViewport(Size size) async {
    const edgeMargin = 56.0;
    final viewPadding = MediaQuery.of(context).viewPadding;
    final isPhoneLayout = size.shortestSide < kTabletBreakpoint;
    final isCompactHeight = isPhoneLayout && size.height <= 740;
    final topControlOffset = viewPadding.top + (isCompactHeight ? 8.0 : 12.0);
    final controlButtonSize = isCompactHeight ? 50.0 : 56.0;
    final settingsButtonUnsafeRect = Rect.fromLTWH(
            16, topControlOffset, controlButtonSize, controlButtonSize)
        .inflate(54);

    final minX = edgeMargin;
    final maxX = max(edgeMargin, size.width - edgeMargin);
    final minY = max(edgeMargin, viewPadding.top + 8.0);
    final maxY = max(edgeMargin, size.height - edgeMargin);
    var changed = false;
    for (final t in _thoughts) {
      var nx = t.dx.clamp(minX, maxX).toDouble();
      var ny = t.dy.clamp(minY, maxY).toDouble();

      // Keep stars draggable by avoiding the menu button's touch area.
      if (settingsButtonUnsafeRect.contains(Offset(nx, ny))) {
        ny =
            (settingsButtonUnsafeRect.bottom + 18).clamp(minY, maxY).toDouble();
      }

      if (nx != t.dx || ny != t.dy) {
        t.dx = nx;
        t.dy = ny;
        if (t.isInBox) {
          await t.save();
        }
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _meteorSpawnTimer?.cancel();
    _meteorFrameTimer?.cancel();
    _spawnHighlightTimer?.cancel();
    _rewardedAd?.dispose();
    _controller.dispose();
    _observationSearchController.dispose();
    super.dispose();
  }

  // --- 再訪イベント関連の処理 ---

  bool _isBlank(String? value) => isThoughtFieldBlank(value);

  String _dayKey(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return "${dt.year}-$m-$d";
  }

  int _dailyReflectionLimit(DateTime now) {
    // 1〜3回/日をゆるく変動させる
    return ((now.year + now.month + now.day) % 3) + 1;
  }

  void _loadDailyReflectionState(Box settingsBox) {
    final now = DateTime.now();
    final todayKey = _dayKey(now);
    final storedDay = settingsBox.get('reflectionDailyCountDay') as String?;
    final storedCount =
        settingsBox.get('reflectionDailyCount', defaultValue: 0) as int;
    _dailyReflectionCount = storedDay == todayKey ? storedCount : 0;
  }

  bool _hasReflectionQuota() {
    if (kForceRevisitDebug) return true;
    final now = DateTime.now();
    final settingsBox = Hive.box('settings');
    final todayKey = _dayKey(now);
    final storedDay = settingsBox.get('reflectionDailyCountDay') as String?;
    if (storedDay != todayKey) {
      _dailyReflectionCount = 0;
    }
    return _dailyReflectionCount < _dailyReflectionLimit(now);
  }

  int _remainingReflectionQuota(DateTime now) {
    final settingsBox = Hive.box('settings');
    final todayKey = _dayKey(now);
    final storedDay = settingsBox.get('reflectionDailyCountDay') as String?;
    final storedCount =
        settingsBox.get('reflectionDailyCount', defaultValue: 0) as int;
    final todaysCount = storedDay == todayKey ? storedCount : 0;
    return max(0, _dailyReflectionLimit(now) - todaysCount);
  }

  Future<void> _recordReflectionTriggered() async {
    final settingsBox = Hive.box('settings');
    final now = DateTime.now();
    final todayKey = _dayKey(now);
    final storedDay = settingsBox.get('reflectionDailyCountDay') as String?;
    final storedCount =
        settingsBox.get('reflectionDailyCount', defaultValue: 0) as int;
    final nextCount = storedDay == todayKey ? storedCount + 1 : 1;
    _dailyReflectionCount = nextCount;
    await settingsBox.put('reflectionDailyCountDay', todayKey);
    await settingsBox.put('reflectionDailyCount', nextCount);
    await settingsBox.put('reflectionLastTriggeredAt', now.toIso8601String());
  }

  bool _isNearReflectionTiming(Thought t, DateTime now) {
    final elapsedHours = now.difference(t.createdAt).inHours;
    if (elapsedHours < 0) return false;
    const targets = [24, 72, 168]; // 1日/3日/7日
    const toleranceHours = 18;
    for (final target in targets) {
      if ((elapsedHours - target).abs() <= toleranceHours) return true;
    }
    return false;
  }

  List<Thought> _reflectionCandidates(DateTime now) {
    if (kForceRevisitDebug && _thoughts.isNotEmpty) {
      return List<Thought>.from(_thoughts.take(min(4, _thoughts.length)));
    }

    final due = _thoughts.where((t) => _isNearReflectionTiming(t, now)).toList()
      ..sort((a, b) => _reflectionScore(b, now).compareTo(_reflectionScore(a, now)));

    if (due.isEmpty) {
      final allCompleted =
          _thoughts.isNotEmpty && _thoughts.every((t) => !_isBlank(t.action));
      if (!allCompleted) return const [];
      final oldestFirst = [..._thoughts]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return oldestFirst.take(min(4, oldestFirst.length)).toList();
    }

    final group = <Thought>[];
    final usedIds = <int>{};
    for (final t in due) {
      if (group.length >= 4) break;
      group.add(t);
      usedIds.add(t.id);
    }

    _fillConstellationFallbacks(group, usedIds, now, minCount: 2);
    if (group.length >= 2 && group.length < 3 && _thoughts.length >= 3) {
      _fillConstellationFallbacks(group, usedIds, now, minCount: 3);
    }
    return group;
  }

  void _fillConstellationFallbacks(
    List<Thought> group,
    Set<int> usedIds,
    DateTime now, {
    required int minCount,
  }) {
    if (group.length >= minCount || group.length >= 4) return;
    final ranked = [..._thoughts]
      ..sort((a, b) => _reflectionScore(b, now).compareTo(_reflectionScore(a, now)));
    for (final t in ranked) {
      if (group.length >= minCount || group.length >= 4) break;
      if (usedIds.contains(t.id)) continue;
      group.add(t);
      usedIds.add(t.id);
    }
  }

  int _reflectionScore(Thought t, DateTime now) {
    var score = 0;
    if (_isBlank(t.action)) score += 3;
    if (_isBlank(t.insight)) score += 2;
    if (t.content.trim().length >= 50) score += 1;
    if (now.difference(t.createdAt).inDays >= 7) score += 1;
    return score;
  }

  Thought? _pickWeightedRevisitTarget(List<Thought> candidates, DateTime now) {
    if (candidates.isEmpty) return null;
    final scored = <Thought, int>{
      for (final t in candidates) t: _reflectionScore(t, now)
    };
    final bestScore = scored.values.reduce(max);
    final best = candidates.where((t) => scored[t] == bestScore).toList();
    return best[_random.nextInt(best.length)];
  }

  void _startRevisitEvent() async {
    if (_isConstellationAnimating) return;
    if (_constellationFormed && _constellationMain != null) {
      _openConstellationRevisit();
      return;
    }

    HapticFeedback.heavyImpact();

    if (!_hasReflectionQuota()) return;
    final now = DateTime.now();
    final group = _reflectionCandidates(now);
    if (group.isEmpty) return;

    final main = _pickWeightedRevisitTarget(group, now) ?? group.first;
    final context = group.where((t) => t.id != main.id).toList();
    final members = [main, ...context];

    _constellationOriginalPositions.clear();
    _constellationFormationTargets.clear();
    for (final t in members) {
      _constellationOriginalPositions[t.id] = Offset(t.dx, t.dy);
    }

    final slots = constellationLayoutSlots(
      members.length,
      _revisitCenterPosition,
    );
    for (var i = 0; i < members.length; i++) {
      _constellationFormationTargets[members[i].id] = slots[i];
    }

    setState(() {
      _activeConstellation = members;
      _constellationMain = main;
      _constellationContext = context;
      _constellationName = deriveConstellationName(
        members,
        japaneseSuffix: _isJapaneseLocale(),
      );
      _isConstellationAnimating = true;
      _constellationFormed = false;
      _showConstellationLines = false;
    });

    await _animateConstellationFormation(members);
    if (!mounted) return;

    setState(() => _showConstellationLines = true);
  }

  Future<void> _animateConstellationFormation(List<Thought> members) async {
    final controllers = <AnimationController>[];
    final startPositions = <int, Offset>{};
    for (final t in members) {
      startPositions[t.id] = Offset(t.dx, t.dy);
    }

    for (var i = 0; i < members.length; i++) {
      final thought = members[i];
      final target = _constellationFormationTargets[thought.id]!;
      final start = startPositions[thought.id]!;
      final delayMs = i * 90;

      await Future<void>.delayed(Duration(milliseconds: delayMs));
      if (!mounted) return;

      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 820),
      );
      controllers.add(controller);
      final animation = CurvedAnimation(
        parent: controller,
        curve: Curves.elasticOut,
      );

      controller.addListener(() {
        if (!mounted) return;
        setState(() {
          thought.dx = lerpDouble(start.dx, target.dx, animation.value)!;
          thought.dy = lerpDouble(start.dy, target.dy, animation.value)!;
        });
      });

      await controller.forward();
    }

    for (final c in controllers) {
      c.dispose();
    }
    if (!mounted) return;
    setState(() {
      _isConstellationAnimating = false;
      _constellationFormed = true;
    });
  }

  void _onConstellationLinesComplete() async {
    if (!mounted) return;
    await SystemSound.play(SystemSoundType.click);
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() => _showConstellationLines = false);

    // 線の演出が終わったら再訪ダイアログを自動表示
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted || !_constellationFormed || _constellationMain == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openConstellationRevisit();
    });
  }

  void _onConstellationLineConnected() {
    HapticFeedback.lightImpact();
  }

  /// Ends a constellation revisit: restores star layout and optionally counts quota.
  Future<void> _finishConstellationRevisitSession({required bool saved}) async {
    if (!_constellationFormed && _activeConstellation.isEmpty) return;
    if (saved) {
      await _recordReflectionTriggered();
    }
    if (!mounted) return;
    _resetConstellationState();
  }

  Future<void> _openConstellationRevisit() async {
    if (_revisitDialogOpen) return;
    final main = _constellationMain;
    if (main == null) return;
    _revisitDialogOpen = true;

    final chosenUpdate = await ThoughtPopup.show(
      context,
      mainThought: main,
      contextThoughts: _constellationContext,
      constellationName: _constellationName,
    );

    if (!mounted) return;
    _revisitDialogOpen = false;

    if (chosenUpdate == true) {
      final saved = await _editThought(
        main,
        focusFollowupOnOpen: true,
        advanceRevisitScheduleOnSave: true,
        contextThoughts: _constellationContext,
      );
      await _finishConstellationRevisitSession(saved: saved == true);
    } else {
      await _finishConstellationRevisitSession(saved: false);
    }
  }

  void _resetConstellationState() {
    for (final entry in _constellationOriginalPositions.entries) {
      final thought = _thoughts.cast<Thought?>().firstWhere(
            (t) => t?.id == entry.key,
            orElse: () => null,
          );
      if (thought != null) {
        thought.dx = entry.value.dx;
        thought.dy = entry.value.dy;
        if (thought.isInBox) thought.save();
      }
    }
    setState(() {
      _activeConstellation = [];
      _constellationMain = null;
      _constellationContext = [];
      _constellationFormed = false;
      _isConstellationAnimating = false;
      _constellationName = null;
      _constellationOriginalPositions.clear();
      _constellationFormationTargets.clear();
      _showConstellationLines = false;
    });
  }

  // 3. カテゴリ色の取得（もし未実装なら追加）
  Color _getCategoryColor(String category) {
    switch (category) {
      case "future":
        return Colors.blue;
      case "past":
        return Colors.purple;
      case "emotion":
        return Colors.pink;
      case "action":
        return Colors.yellow;
      default:
        return Colors.white54;
    }
  }

  // 🚀 ここから追加
  Future<bool?> _editThought(
    Thought thought, {
    bool focusFollowupOnOpen = false,
    bool advanceRevisitScheduleOnSave = false,
    List<Thought>? contextThoughts,
  }) async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (context) => InputScreen(
          thoughtToEdit: thought,
          initialContent: thought.content,
          initialInsight: thought.insight,
          initialAction: thought.action,
          initialStarSize: thought.starSize,
          initialGlowIntensity: thought.glowIntensity,
          initialParticleSpread: thought.particleSpread,
          forceBulkMode: true,
          focusFollowupOnOpen: focusFollowupOnOpen,
          advanceRevisitScheduleOnSave: advanceRevisitScheduleOnSave,
          contextThoughts: contextThoughts,
        ),
        fullscreenDialog: true,
      ),
    );
    if (!mounted) return result == true ? true : null;
    final shouldHighlight = result == true ||
        result == InputScreen.highlightOnReturnHome;
    if (shouldHighlight) {
      _markNewlySpawnedThought(thought);
    }
    setState(() {});
    if (result == true) {
      HapticFeedback.lightImpact();
      debugPrint(
          "${AppLocalizations.of(context)!.revisitComplete}: ${thought.content}");
    }
    return result == true ? true : null;
  }
  // 🚀 ここまで追加

  String _colorToCategory(Color color) {
    if (color == Colors.blue) return 'future';
    if (color == Colors.purple) return 'past';
    if (color == Colors.pink) return 'emotion';
    if (color == Colors.yellow) return 'action';
    return 'neutral';
  }

  String? _tutorialCategoryFromDragVector(Offset vector) {
    const deadZone = 14.0;
    if (vector.distance < deadZone) return null;

    if (vector.dy.abs() >= vector.dx.abs()) {
      return vector.dy < 0 ? 'future' : 'past';
    }
    return vector.dx >= 0 ? 'action' : 'emotion';
  }

  Map<String, String> _tutorialCategoryLabels(AppLocalizations loc) {
    return {
      'future': loc.categoryFuture,
      'past': loc.categoryPast,
      'emotion': loc.categoryEmotion,
      'action': loc.categoryAction,
    };
  }

  // --- オンボーディング関連 ---

  Future<void> _persistOnboardingThought() async {
    final content = _onboardingDraftContent?.trim();
    if (content == null || content.isEmpty) return;

    final newThought = Thought(
      id: _thoughtIdCounter++,
      dx: _tutorialStar.dx,
      dy: _tutorialStar.dy,
      content: content,
      insight: null,
      action: null,
      category: _colorToCategory(_tutorialStarColor),
      createdAt: DateTime.now(),
      revisitAt: DateTime.now().add(const Duration(days: 1)),
      revisitCount: 1,
      isArchived: false,
      starSize: 1.0,
      glowIntensity: 1.0,
      particleSpread: 1.0,
    );

    final box = Hive.box<Thought>('thoughts');
    await box.add(newThought);
    if (!mounted) return;
    setState(() {
      _insertIntoVisibleThoughts(newThought);
      _onboardingDraftContent = null;
    });
  }

  Future<void> _submitOnboardingInput() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;

    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();

    _onboardingDraftContent = content;
    _resetTutorialStarPosition();
    _tutorialStarColor = Colors.white;
    _tutorialDragVector = Offset.zero;
    _isTutorialDragging = false;
    _tutorialDragPreviewCategory = null;
    setState(() => _tutorialStep = 1);
  }

  Future<void> _advanceOnboarding() async {
    if (_tutorialCompleting) return;

    if (_tutorialStep == 2) {
      await _persistOnboardingThought();
      if (!mounted) return;
      setState(() => _tutorialStep = 3);
      return;
    }

    if (_tutorialStep == 3) {
      setState(() {
        _tutorialStep = 4;
        _onboardingStep4MessageVisible = false;
      });
      unawaited(_startOnboardingConstellationDemo());
      return;
    }

    if (_tutorialStep == 4) {
      if (!_onboardingStep4MessageVisible) return;
      _resetOnboardingConstellationDemo();
      await _completeOnboarding();
      return;
    }

    if (_tutorialStep < 3) {
      setState(() => _tutorialStep++);
    }
  }

  Future<void> _startOnboardingConstellationDemo() async {
    if (_isConstellationAnimating || _thoughts.isEmpty) {
      if (mounted) {
        setState(() => _onboardingStep4MessageVisible = true);
      }
      return;
    }

    final userThought = _thoughts.first;
    final slots = constellationLayoutSlots(4, _revisitCenterPosition);

    _constellationOriginalPositions[userThought.id] =
        Offset(userThought.dx, userThought.dy);
    _constellationFormationTargets[userThought.id] = slots[0];

    setState(() {
      _onboardingConstellationDemo = true;
      _onboardingStep4MessageVisible = false;
      _onboardingDemoAllSlots = slots;
      _onboardingDemoGhostSlots = slots.sublist(1);
      _activeConstellation = [userThought];
      _constellationMain = userThought;
      _constellationContext = [];
      _isConstellationAnimating = true;
      _constellationFormed = false;
      _showConstellationLines = false;
    });

    HapticFeedback.heavyImpact();
    await _animateConstellationFormation([userThought]);
    if (!mounted) return;
    setState(() => _showConstellationLines = true);
  }

  void _onOnboardingConstellationLinesComplete() {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _showConstellationLines = false;
      _onboardingStep4MessageVisible = true;
    });
  }

  void _resetOnboardingConstellationDemo() {
    if (!_onboardingConstellationDemo) return;
    _resetConstellationState();
    setState(() {
      _onboardingConstellationDemo = false;
      _onboardingStep4MessageVisible = false;
      _onboardingDemoGhostSlots = const [];
      _onboardingDemoAllSlots = const [];
    });
  }

  Future<void> _completeOnboarding() async {
    if (_tutorialCompleting) return;
    _tutorialCompleting = true;
    HapticFeedback.lightImpact();

    try {
      await Hive.box('settings').put('tutorialDone', true);
    } catch (_) {
      if (!mounted) return;
      _tutorialCompleting = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.onboardingSaveFailed),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _tutorialStep = _tutorialInteractiveStep;
      _tutorialCompleting = false;
    });
  }

  Widget _buildOnboardingNextButton(
    AppLocalizations loc, {
    required VoidCallback onPressed,
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      child: Text(loc.onboardingNextButton),
    );
  }

  Widget _buildTutorialStarIcon({required bool draggable}) {
    return Positioned(
      left: _tutorialStar.dx - 48,
      top: _tutorialStar.dy -
          48 -
          (_isTutorialDragging ? _tutorialDragVisualYOffset : 0),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: draggable
            ? (details) {
                setState(() {
                  _isTutorialDragging = true;
                  _tutorialDragVector = Offset.zero;
                  _tutorialDragPreviewCategory = null;
                  _tutorialDragTouchOffset =
                      const Offset(20, 20) - details.localPosition;
                });
              }
            : null,
        onPanUpdate: draggable
            ? (details) {
                setState(() {
                  final renderBox = context.findRenderObject() as RenderBox?;
                  if (renderBox != null && _tutorialDragTouchOffset != null) {
                    final localTouch =
                        renderBox.globalToLocal(details.globalPosition);
                    _tutorialStar = localTouch + _tutorialDragTouchOffset!;
                  } else {
                    _tutorialStar += details.delta;
                  }
                  _tutorialDragVector += details.delta;
                  final previewCategory =
                      _tutorialCategoryFromDragVector(_tutorialDragVector);
                  if (previewCategory != null) {
                    if (previewCategory != _tutorialDragPreviewCategory) {
                      _tutorialDragPreviewCategory = previewCategory;
                      HapticFeedback.selectionClick();
                    }
                    _tutorialStarColor = _getCategoryColor(previewCategory);
                  }
                });
              }
            : null,
        onPanEnd: draggable
            ? (_) {
                setState(() {
                  _isTutorialDragging = false;
                  _tutorialDragVector = Offset.zero;
                  _tutorialDragTouchOffset = null;
                });
              }
            : null,
        child: SizedBox(
          width: 96,
          height: 96,
          child: Center(
            child: AnimatedScale(
              scale: _isTutorialDragging ? 1.5 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: Icon(Icons.star, color: _tutorialStarColor, size: 40),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTutorialText(String text, {Key? key}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 50),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w300,
          letterSpacing: 1.5,
          height: 1.6,
          shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
        ),
      ),
    );
  }

  Widget _buildTutorialSublineText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 14,
          fontWeight: FontWeight.w300,
          letterSpacing: 0.8,
          height: 1.5,
        ),
      ),
    );
  }

  void _insertIntoVisibleThoughts(Thought thought) {
    _observationThoughts.add(thought);
    _observationThoughts.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _rebuildObservationSearchMatches();
    _thoughts.add(thought);
    _thoughts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (_thoughts.length > _maxVisibleThoughts) {
      _thoughts.removeRange(_maxVisibleThoughts, _thoughts.length);
    }
    _markNewlySpawnedThought(thought);
  }

  void _markNewlySpawnedThought(Thought thought) {
    _spawnHighlightTimer?.cancel();
    _spawnHighlightThoughtId = thought.id;
    _spawnHighlightTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      if (_spawnHighlightThoughtId != thought.id) return;
      setState(() => _spawnHighlightThoughtId = null);
    });
  }

  Widget _tutorialVeil() {
    if (_tutorialStep >= _tutorialInteractiveStep) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: Container(color: Colors.black.withValues(alpha: 0.6)),
    );
  }

  Widget _buildTutorialForeground() {
    if (_tutorialStep >= _tutorialInteractiveStep) {
      return const SizedBox.shrink();
    }
    final size = MediaQuery.of(context).size;
    final viewPadding = MediaQuery.of(context).viewPadding;
    final loc = AppLocalizations.of(context)!;
    final isPhoneLayout = size.shortestSide < kTabletBreakpoint;
    final tutorialCompactLayout = isPhoneLayout && size.height <= 760;
    final headlineAlignment =
        tutorialCompactLayout ? const Alignment(0, -0.30) : const Alignment(0, -0.35);
    final canSubmit = _controller.text.trim().isNotEmpty;
    final tutorialCompassTop =
        viewPadding.top + (tutorialCompactLayout ? 8.0 : 16.0);
    final nextButtonBottom = viewPadding.bottom + 24.0;

    if (_tutorialStep == 0) {
      return Positioned.fill(
        child: Column(
          children: [
            Expanded(
              child: Align(
                alignment: headlineAlignment,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTutorialText(loc.onboardingInputHeadline),
                    const SizedBox(height: 8),
                    _buildTutorialSublineText(loc.onboardingInputSubline),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(40, 0, 40, size.height * 0.22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    maxLength: AppConstants.defaultTextLimit,
                    textInputAction: TextInputAction.done,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 22),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      hintText: loc.onboardingInputHint,
                      hintStyle: const TextStyle(color: Colors.white38),
                      counterText: '',
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white38),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => unawaited(_submitOnboardingInput()),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: canSubmit
                        ? () => unawaited(_submitOnboardingInput())
                        : null,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white38,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      disabledBackgroundColor:
                          Colors.white.withValues(alpha: 0.05),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(loc.onboardingSubmitButton),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Positioned.fill(
      child: Stack(
        children: [
          if (_tutorialStep == 1)
            _buildTutorialStarIcon(draggable: false),
          if (_tutorialStep == 1)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => unawaited(_advanceOnboarding()),
                child: Stack(
                  children: [
                    Align(
                      alignment: const Alignment(0, -0.45),
                      child: _buildTutorialText(loc.onboardingBeat1Born),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: nextButtonBottom,
                      child: Center(
                        child: _buildOnboardingNextButton(
                          loc,
                          onPressed: () => unawaited(_advanceOnboarding()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_tutorialStep == 2)
            Stack(
              children: [
                Positioned(
                  top: tutorialCompassTop,
                  left: 20,
                  right: 20,
                  child: IgnorePointer(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedOpacity(
                          opacity: _isTutorialDragging ? 0.38 : 1.0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          child: _buildTutorialText(loc.onboardingDragHint),
                        ),
                        SizedBox(height: tutorialCompactLayout ? 12 : 18),
                        TutorialCategoryCompass(
                          labels: _tutorialCategoryLabels(loc),
                          colorForCategory: _getCategoryColor,
                          activeCategory: _tutorialCategoryFromDragVector(
                            _tutorialDragVector,
                          ),
                          isDragging: _isTutorialDragging,
                          compact: tutorialCompactLayout,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: nextButtonBottom,
                  child: Center(
                    child: _buildOnboardingNextButton(
                      loc,
                      onPressed: () => unawaited(_advanceOnboarding()),
                    ),
                  ),
                ),
              ],
            ),
          if (_tutorialStep == 2)
            _buildTutorialStarIcon(draggable: true),
          if (_tutorialStep == 3)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => unawaited(_advanceOnboarding()),
                child: Stack(
                  children: [
                    Align(
                      alignment: const Alignment(0, -0.45),
                      child: _buildTutorialText(loc.onboardingBeat2Revisit),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: nextButtonBottom,
                      child: Center(
                        child: _buildOnboardingNextButton(
                          loc,
                          onPressed: () => unawaited(_advanceOnboarding()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_tutorialStep == 4 && _onboardingStep4MessageVisible)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => unawaited(_advanceOnboarding()),
                child: Stack(
                  children: [
                    Align(
                      alignment: const Alignment(0, -0.45),
                      child: _buildTutorialText(loc.onboardingBeat3Future),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: nextButtonBottom,
                      child: Center(
                        child: _buildOnboardingNextButton(
                          loc,
                          onPressed: () => unawaited(_advanceOnboarding()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openFabInput() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const InputScreen(),
        fullscreenDialog: true,
      ),
    );
    if (!mounted || result == null) return;
    await _addThoughtFromInputResult(result);
    if (!mounted) return;
  }

  Future<void> _openWeeklyGalaxy() async {
    HapticFeedback.selectionClick();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (context) => const WeeklyGalaxyScreen()),
    );
  }

  Future<void> _openSettings() async {
    final thoughtsReplaced = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
    if (!mounted) return;
    if (thoughtsReplaced == true) {
      await _reloadThoughtsFromHive();
    }
  }

  Future<void> _openPrivacyPolicy() async {
    final loc = AppLocalizations.of(context)!;
    final launched = await launchUrl(
      Uri.parse(_privacyPolicyUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      _showFloatingNotice(loc.privacyPolicyLoadFailed);
    }
  }

  void _showFloatingNotice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _launchSupportEmail() async {
    final loc = AppLocalizations.of(context)!;
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {'subject': 'MindGalaxy Inquiry'},
    );
    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      _showFloatingNotice('${loc.aboutAppTitle}: $_supportEmail');
    }
  }

  Future<void> _showMeteorSupportDialog() async {
    final loc = AppLocalizations.of(context)!;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A1020),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          loc.supportDeveloperTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          loc.meteorSupportContent,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.approve),
          ),
        ],
      ),
    );

    if (approved != true) return;
    // showDialog の await は pop 完了後に戻るため、ここではルートは既に閉じている。
    if (!kShowAds) {
      await _activateMeteorShowerRewardWindow();
      return;
    }
    await _showRewardedMeteorAd();
  }

  Future<void> _showRewardedMeteorAd() async {
    if (!kShowAds) return;
    if (_isRewardAdShowing || _isRewardAdLoading) return;
    if (_rewardedAd != null) {
      _presentRewardedAd(_rewardedAd!);
      return;
    }
    await _loadRewardedAd(showWhenReady: true);
  }

  Future<void> _loadRewardedAd({bool showWhenReady = false}) async {
    if (!kShowAds) return;
    if (_isRewardAdLoading || _isRewardAdShowing) return;
    final loc = AppLocalizations.of(context)!;
    setState(() {
      _isRewardAdLoading = true;
    });
    _showFloatingNotice('${loc.meteorRewardAd} ${loc.preparing}...');

    await RewardedAd.load(
      adUnitId: AdHelper.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _isRewardAdLoading = false;
            _rewardedAd = ad;
          });
          if (showWhenReady) {
            _presentRewardedAd(ad);
          }
        },
        onAdFailedToLoad: (error) {
          if (!mounted) return;
          setState(() {
            _isRewardAdLoading = false;
            _rewardedAd = null;
          });
          _showFloatingNotice(
            '${loc.meteorRewardAd}: ${error.message}',
          );
        },
      ),
    );
  }

  void _presentRewardedAd(RewardedAd ad) {
    if (_isRewardAdShowing) return;
    final loc = AppLocalizations.of(context)!;
    var earnedReward = false;
    _isRewardAdShowing = true;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        if (mounted) {
          setState(() {});
        }
      },
      onAdDismissedFullScreenContent: (ad) async {
        ad.dispose();
        if (!mounted) return;
        setState(() {
          _rewardedAd = null;
          _isRewardAdShowing = false;
        });
        if (!earnedReward) {
          _showFloatingNotice(loc.cancel);
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!mounted) return;
        setState(() {
          _rewardedAd = null;
          _isRewardAdShowing = false;
        });
        _showFloatingNotice('${loc.meteorRewardAd}: ${error.message}');
      },
    );

    ad.show(
      onUserEarnedReward: (_, __) async {
        earnedReward = true;
        await _activateMeteorShowerRewardWindow();
      },
    );
  }

  Future<void> _activateMeteorShowerRewardWindow() async {
    final loc = AppLocalizations.of(context)!;
    await AppSettings.setMeteorExpiryTime(
      DateTime.now().add(const Duration(hours: 12)),
    );
    if (!mounted) return;
    _spawnMeteor();
    _syncMeteorShowerState();
    _showFloatingNotice(loc.meteorSupportNotice);
  }

  bool _isMeteorWindowActive() {
    final expiry = AppSettings.meteorExpiryTime;
    return expiry != null && expiry.isAfter(DateTime.now());
  }

  void _syncMeteorShowerState() {
    if (!_isMeteorWindowActive()) {
      _meteorSpawnTimer?.cancel();
      _meteorSpawnTimer = null;
      if (_meteorTrails.isEmpty) {
        _meteorFrameTimer?.cancel();
        _meteorFrameTimer = null;
      }
      return;
    }
    _scheduleNextMeteorSpawn();
    _ensureMeteorFrameLoop();
  }

  void _scheduleNextMeteorSpawn() {
    if (_meteorSpawnTimer != null) return;
    final activeCount = _meteorTrails.length;
    final waitMs = activeCount < _meteorMinActive
        ? 120 + _random.nextInt(120)
        : 260 + _random.nextInt(300);
    _meteorSpawnTimer = Timer(Duration(milliseconds: waitMs), () {
      _meteorSpawnTimer = null;
      if (!mounted || !_isMeteorWindowActive()) {
        _syncMeteorShowerState();
        return;
      }
      final nowActive = _meteorTrails.length;
      final remainingSlots = max(0, _meteorMaxActive - nowActive);
      if (remainingSlots == 0) {
        _scheduleNextMeteorSpawn();
        return;
      }

      final burstCount = nowActive < _meteorMinActive
          ? min(
              _meteorMinActive - nowActive + _random.nextInt(2),
              remainingSlots,
            )
          : 1;
      for (int i = 0; i < burstCount; i++) {
        _spawnMeteor();
      }
      if (_meteorTrails.length < _meteorMaxActive &&
          _random.nextDouble() < 0.32) {
        _spawnMeteor();
      }
      _scheduleNextMeteorSpawn();
    });
  }

  void _ensureMeteorFrameLoop() {
    if (_meteorFrameTimer != null) return;
    _meteorFrameTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!mounted) return;
      final changed = _cleanupExpiredMeteors();
      if (changed) {
        setState(() {});
      }
      if (!_isMeteorWindowActive() && _meteorTrails.isEmpty) {
        _meteorFrameTimer?.cancel();
        _meteorFrameTimer = null;
      }
    });
  }

  bool _cleanupExpiredMeteors() {
    final now = DateTime.now();
    final before = _meteorTrails.length;
    _meteorTrails.removeWhere(
      (trail) => now.difference(trail.startedAt) > trail.duration,
    );
    return before != _meteorTrails.length;
  }

  void _spawnMeteor() {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    final useRightEdge = _random.nextBool();
    final startX = useRightEdge
        ? size.width * (0.86 + _random.nextDouble() * 0.24)
        : size.width * (0.06 + _random.nextDouble() * 0.88);
    final startY = useRightEdge
        ? size.height * (0.04 + _random.nextDouble() * 0.46)
        : size.height * (-0.08 + _random.nextDouble() * 0.24);
    final glowColor = Color.lerp(
      const Color(0xFF5CFFD8),
      Colors.white,
      0.10 + _random.nextDouble() * 0.28,
    )!;
    final coreColor = Color.lerp(
      const Color(0xFF81FFE4),
      Colors.white,
      0.18 + _random.nextDouble() * 0.35,
    )!;
    final headColor = Color.lerp(
      const Color(0xFFA6FFF0),
      Colors.white,
      0.28 + _random.nextDouble() * 0.4,
    )!;
    final trail = _MeteorTrail(
      startedAt: DateTime.now(),
      duration: Duration(milliseconds: 580 + _random.nextInt(480)),
      start: Offset(startX, startY),
      distance: 180 + _random.nextDouble() * 230,
      angle: pi * (0.64 + _random.nextDouble() * 0.2),
      thickness: 1.2 + _random.nextDouble() * 2.0,
      tailLengthFactor: 0.22 + _random.nextDouble() * 0.34,
      glowColor: glowColor,
      coreColor: coreColor,
      headColor: headColor,
    );
    setState(() {
      _meteorTrails.add(trail);
    });
    _ensureMeteorFrameLoop();
  }

  Widget _buildRoundSpaceButton({
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
    double size = 56,
    double iconSize = 24,
    Widget? iconChild,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: active
                ? [
                    Colors.blueGrey.withValues(alpha: 0.42),
                    Colors.indigo.withValues(alpha: 0.28),
                    Colors.transparent,
                  ]
                : [
                    Colors.white.withValues(alpha: 0.12),
                    Colors.indigoAccent.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
          ),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.2), width: 0.85),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.08),
              blurRadius: 12,
              spreadRadius: 0,
            ),
          ],
        ),
        child: iconChild ??
            Icon(
              icon,
              size: iconSize,
              color: active ? Colors.lightBlueAccent : Colors.white70,
            ),
      ),
    );
  }

  Drawer _buildMainDrawer() {
    final loc = AppLocalizations.of(context)!;
    return Drawer(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF081226),
              Color(0xFF060E1F),
              Color(0xFF040915),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.white70),
                title: Text(
                  loc.settingsTitle,
                  style:
                      const TextStyle(color: Colors.white, letterSpacing: 1.1),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _openSettings();
                },
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined,
                    color: Colors.white70),
                title: Text(
                  loc.privacyPolicyTitle,
                  style:
                      const TextStyle(color: Colors.white, letterSpacing: 1.1),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _openPrivacyPolicy();
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.white70),
                title: Text(
                  loc.aboutAppTitle,
                  style:
                      const TextStyle(color: Colors.white, letterSpacing: 1.1),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _launchSupportEmail();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addThoughtFromInputResult(Map<String, dynamic> result) async {
    final content = result['content'] as String? ?? '';
    if (content.isEmpty) return;
    HapticFeedback.mediumImpact();
    final size = MediaQuery.of(context).size;
    final pos = _findVisibleSpawnPosition(size);

    final newThought = Thought(
      id: _thoughtIdCounter++,
      dx: pos.dx,
      dy: pos.dy,
      content: content,
      insight: (result['insight'] as String?)?.trim().isEmpty ?? true
          ? null
          : result['insight'],
      action: (result['action'] as String?)?.trim().isEmpty ?? true
          ? null
          : result['action'],
      category: 'neutral',
      createdAt: DateTime.now(),
      revisitAt: DateTime.now().add(const Duration(days: 1)),
      revisitCount: 1,
      isArchived: false,
      starSize: (result['starSize'] as double?) ?? 1.0,
      glowIntensity: (result['glowIntensity'] as double?) ?? 1.0,
      particleSpread: (result['particleSpread'] as double?) ?? 1.0,
    );
    final box = Hive.box<Thought>('thoughts');
    await box.add(newThought);
    if (!mounted) return;
    setState(() => _insertIntoVisibleThoughts(newThought));
  }

  Offset _findVisibleSpawnPosition(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const margin = 56.0;
    final minX = margin;
    final maxX = max(margin, size.width - margin);
    final minY = margin;
    final maxY = max(margin, size.height - margin);
    const goldenAngleRad = 137.5 * (pi / 180);
    const minRadius = 44.0;
    final crowded = _thoughts.length >= 8;
    final maxRadius = crowded
        ? (min(size.width, size.height) * 0.30).clamp(80.0, 170.0)
        : (min(size.width, size.height) * 0.38).clamp(90.0, 260.0);
    final seed = max(1, _thoughtIdCounter);

    for (int attempt = 0; attempt < 28; attempt++) {
      final index = seed + attempt;
      final angle = index * goldenAngleRad;
      final ringT = crowded
          ? (index % 8) / 7 * 0.58
          : (index % 14) / 13;
      final distance = minRadius + (maxRadius - minRadius) * ringT;
      final candidate = Offset(
        (center.dx + cos(angle) * distance).clamp(minX, maxX).toDouble(),
        (center.dy + sin(angle) * distance).clamp(minY, maxY).toDouble(),
      );
      if (!_isSpawnPointCrowded(candidate)) return candidate;
    }

    return Offset(
      center.dx.clamp(minX, maxX).toDouble(),
      center.dy.clamp(minY, maxY).toDouble(),
    );
  }

  bool _isSpawnPointCrowded(Offset candidate) {
    for (final thought in _thoughts) {
      if ((Offset(thought.dx, thought.dy) - candidate).distance < 54) {
        return true;
      }
    }
    return false;
  }

  double _observationContentHeight(double viewportHeight) {
    if (_observationThoughts.isEmpty) return viewportHeight;
    return max(
        viewportHeight,
        (_observationThoughts.length - 1) * _observationSpacing +
            viewportHeight);
  }

  double _observationMaxScroll(double viewportHeight) {
    if (_observationThoughts.isEmpty) return 0.0;
    // 最後（最新）の星が画面中央へ来る位置まで到達可能にする
    final latestIndex = (_observationThoughts.length - 1).toDouble();
    final maxByCenterAnchor = latestIndex * _observationSpacing;
    final maxByContent =
        max(0.0, _observationContentHeight(viewportHeight) - viewportHeight);
    return max(maxByCenterAnchor, maxByContent);
  }

  void _setObservationToLatest(double viewportHeight) {
    _observationScrollOffset = _observationMaxScroll(viewportHeight);
  }

  void _toggleObservationMode(double viewportHeight) {
    setState(() {
      _isObservationMode = !_isObservationMode;
      if (_isObservationMode) {
        _setObservationToLatest(viewportHeight);
      } else {
        FocusScope.of(context).unfocus();
      }
    });
  }

  String _formatObservationDateLabel(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return "$y.$m.$d  $hh:$mm";
  }

  bool _thoughtContainsObservationKeyword(Thought thought, String keyword) {
    final content = thought.content.toLowerCase();
    final insight = (thought.insight ?? '').toLowerCase();
    final action = (thought.action ?? '').toLowerCase();
    return content.contains(keyword) ||
        insight.contains(keyword) ||
        action.contains(keyword);
  }

  String _sanitizeObservationSupplement(String raw) {
    return raw.replaceFirst(RegExp(r'^\s*[💡🏃]\s*'), '');
  }

  void _rebuildObservationSearchMatches() {
    final normalized = _observationSearchQuery.trim().toLowerCase();
    if (normalized.isEmpty) {
      _observationSearchMatches.clear();
      _observationSearchMatchCursor = -1;
      return;
    }
    Thought? activeThought;
    if (_observationSearchMatchCursor >= 0 &&
        _observationSearchMatchCursor < _observationSearchMatches.length) {
      final activeIndex =
          _observationSearchMatches[_observationSearchMatchCursor];
      if (activeIndex >= 0 && activeIndex < _observationThoughts.length) {
        activeThought = _observationThoughts[activeIndex];
      }
    }
    final matches = <int>[];
    for (int i = 0; i < _observationThoughts.length; i++) {
      if (_thoughtContainsObservationKeyword(
          _observationThoughts[i], normalized)) {
        matches.add(i);
      }
    }
    _observationSearchMatches
      ..clear()
      ..addAll(matches);
    if (_observationSearchMatches.isEmpty) {
      _observationSearchMatchCursor = -1;
      return;
    }
    if (activeThought == null) {
      _observationSearchMatchCursor = 0;
      return;
    }
    final activeThoughtNonNull = activeThought;
    final nextCursor = _observationSearchMatches.indexWhere((index) {
      final candidate = _observationThoughts[index];
      return identical(candidate, activeThoughtNonNull) ||
          candidate.id == activeThoughtNonNull.id;
    });
    _observationSearchMatchCursor = nextCursor >= 0 ? nextCursor : 0;
  }

  void _updateObservationSearch(String query) {
    setState(() {
      _observationSearchQuery = query;
      _rebuildObservationSearchMatches();
    });
  }

  void _jumpToObservationMatch({
    required bool forward,
    required double viewportHeight,
  }) {
    if (_observationSearchMatches.isEmpty) return;
    setState(() {
      if (_observationSearchMatchCursor == -1) {
        _observationSearchMatchCursor = 0;
      } else if (forward) {
        _observationSearchMatchCursor = (_observationSearchMatchCursor + 1) %
            _observationSearchMatches.length;
      } else {
        _observationSearchMatchCursor = (_observationSearchMatchCursor -
                1 +
                _observationSearchMatches.length) %
            _observationSearchMatches.length;
      }
      final targetIndex =
          _observationSearchMatches[_observationSearchMatchCursor];
      _observationScrollOffset = (targetIndex * _observationSpacing)
          .clamp(0.0, _observationMaxScroll(viewportHeight));
    });
  }

  Widget _buildObservationSearchPanel({
    required Size size,
    required double topControlOffset,
    required double controlButtonSize,
  }) {
    final loc = AppLocalizations.of(context)!;
    final hasQuery = _observationSearchQuery.trim().isNotEmpty;
    final hasMatch = _observationSearchMatches.isNotEmpty;
    final resultLabel = !hasQuery
        ? ''
        : hasMatch
            ? loc.observationSearchResultCount(
                _observationSearchMatchCursor + 1,
                _observationSearchMatches.length,
              )
            : loc.observationSearchNoResult;
    return Positioned(
      left: 14,
      right: 14,
      top: topControlOffset + controlButtonSize + 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xCC0A1326),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.white70, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _observationSearchController,
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: loc.observationSearchHint,
                  hintStyle: const TextStyle(color: Colors.white38),
                ),
                onChanged: _updateObservationSearch,
                onSubmitted: (_) => _jumpToObservationMatch(
                    forward: true, viewportHeight: size.height),
              ),
            ),
            if (hasQuery)
              Text(
                resultLabel,
                style: TextStyle(
                  color: hasMatch
                      ? Colors.lightBlueAccent.withValues(alpha: 0.92)
                      : Colors.white54,
                  fontSize: 12,
                ),
              ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 30, height: 30),
              color: hasMatch ? Colors.white70 : Colors.white24,
              tooltip: loc.observationSearchPreviousTooltip,
              onPressed: hasMatch
                  ? () => _jumpToObservationMatch(
                        forward: false,
                        viewportHeight: size.height,
                      )
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 30, height: 30),
              color: hasMatch ? Colors.white70 : Colors.white24,
              tooltip: loc.observationSearchNextTooltip,
              onPressed: hasMatch
                  ? () => _jumpToObservationMatch(
                        forward: true,
                        viewportHeight: size.height,
                      )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildObservationStars(Size size) {
    final centerX = size.width / 2;
    final centerY = size.height * 0.5;
    const focusRange = 100.0;
    const cullMargin = 220.0;
    final widgets = <Widget>[];
    if (_observationThoughts.isEmpty) return widgets;
    final matchSet = _observationSearchMatches.toSet();
    final activeMatchIndex = (_observationSearchMatchCursor >= 0 &&
            _observationSearchMatchCursor < _observationSearchMatches.length)
        ? _observationSearchMatches[_observationSearchMatchCursor]
        : -1;
    final startRaw = ((_observationScrollOffset - centerY - cullMargin) /
            _observationSpacing)
        .floor();
    final endRaw =
        ((_observationScrollOffset - centerY + size.height + cullMargin) /
                _observationSpacing)
            .ceil();
    final startIndex = startRaw.clamp(0, _observationThoughts.length - 1);
    final endIndex = endRaw.clamp(0, _observationThoughts.length - 1);

    for (int i = startIndex; i <= endIndex; i++) {
      final thought = _observationThoughts[i];
      final baseY = i * _observationSpacing;
      final y = baseY - _observationScrollOffset + centerY;
      final isMatched = matchSet.contains(i);
      final isActiveMatch = activeMatchIndex == i;

      final wave = sin(i * 0.72) * 90;
      final spread = min(110.0, 30.0 + i * 0.9);
      final x = centerX + wave + cos(i * 0.38) * spread * 0.35;
      final scale = (thought.starSize).clamp(0.9, 2.8);
      final starColor = _getCategoryColor(thought.category);
      final starSize = (16.0 * scale).clamp(12.0, 42.0);
      final distanceToCenter = (y - centerY).abs();
      final focusFactor =
          (1.0 - (distanceToCenter / focusRange)).clamp(0.0, 1.0);
      final glow = ((thought.glowIntensity - 1.0) * 10).clamp(0.0, 22.0);
      final matchBoost = isActiveMatch
          ? 12.0
          : isMatched
              ? 5.5
              : 0.0;
      final focusedGlow = glow + (6.0 * focusFactor) + matchBoost;
      final focusedStarSize = starSize + (2.0 * focusFactor);

      widgets.add(
        Positioned(
          left: x - 28,
          top: y - 28,
          child: IgnorePointer(
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: focusedGlow > 0
                    ? [
                        BoxShadow(
                          color: starColor.withValues(
                              alpha: 0.18 +
                                  (0.18 * focusFactor) +
                                  (isMatched ? 0.12 : 0)),
                          blurRadius: focusedGlow,
                          spreadRadius: focusedGlow * 0.1,
                        ),
                      ]
                    : const [],
              ),
              child: Icon(Icons.star, color: starColor, size: focusedStarSize),
            ),
          ),
        ),
      );

      if (focusFactor > 0) {
        final loc = AppLocalizations.of(context)!;
        final thoughtTrim = thought.content.trim();
        final insightRaw =
            _sanitizeObservationSupplement(thought.insight?.trim() ?? "");
        final actionRaw =
            _sanitizeObservationSupplement(thought.action?.trim() ?? "");
        final dateLabel = _formatObservationDateLabel(thought.createdAt);
        final placeLabelOnLeft = x > (size.width * 0.5);
        final textAlign = placeLabelOnLeft ? TextAlign.right : TextAlign.left;
        final crossAxisAlignment = placeLabelOnLeft
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start;

        const thoughtStyle = TextStyle(
          color: Color(0xFFEAEAEA),
          fontSize: 16,
          height: 1.34,
          letterSpacing: 0.15,
          fontWeight: FontWeight.w300,
          shadows: [
            Shadow(
              color: Color(0x80000000),
              blurRadius: 4.0,
              offset: Offset(1.0, 1.0),
            ),
          ],
        );
        const maxObservationTextLines = 3;
        const blockGap = 6.0;
        const thoughtBlockMaxH = 16.0 * 1.34 * maxObservationTextLines;

        final textLines = <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: const Color(0xFF152138).withValues(
                alpha: (0.34 + (0.18 * focusFactor)).clamp(0.0, 0.62),
              ),
              border: Border.all(
                color: const Color(0xFF8FB0E8).withValues(
                  alpha: (0.14 + (0.22 * focusFactor)).clamp(0.0, 0.4),
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text(
                "${loc.createdAtLabel}  $dateLabel",
                textAlign: textAlign,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white
                      .withValues(alpha: 0.72 + (0.18 * focusFactor)),
                  fontSize: 11.2,
                  height: 1.15,
                  letterSpacing: 0.28,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (thoughtTrim.isNotEmpty)
            Text(
              thoughtTrim,
              textAlign: textAlign,
              maxLines: maxObservationTextLines,
              overflow: TextOverflow.ellipsis,
              style: thoughtStyle,
            ),
          if (insightRaw.isNotEmpty) ...[
            if (thoughtTrim.isNotEmpty) const SizedBox(height: blockGap),
            Text(
              insightRaw,
              textAlign: textAlign,
              maxLines: maxObservationTextLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFFDDE7EF).withValues(alpha: 0.78),
                fontSize: 14.2,
                height: 1.32,
                letterSpacing: 0.12,
                fontWeight: FontWeight.w300,
                shadows: const [
                  Shadow(
                    color: Color(0x80000000),
                    blurRadius: 4.0,
                    offset: Offset(1.0, 1.0),
                  ),
                ],
              ),
            ),
          ],
          if (actionRaw.isNotEmpty) ...[
            if (thoughtTrim.isNotEmpty || insightRaw.isNotEmpty)
              const SizedBox(height: blockGap),
            Text(
              actionRaw,
              textAlign: textAlign,
              maxLines: maxObservationTextLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFFBFC5CC).withValues(alpha: 0.68),
                fontSize: 13.6,
                height: 1.32,
                letterSpacing: 0.1,
                fontWeight: FontWeight.w300,
                shadows: const [
                  Shadow(
                    color: Color(0x80000000),
                    blurRadius: 4.0,
                    offset: Offset(1.0, 1.0),
                  ),
                ],
              ),
            ),
          ],
        ];
        double estimatedBlockHeight = 0;
        // Date badge + spacing; keep a little extra slack to avoid sub-pixel overflow.
        estimatedBlockHeight += 34.0;
        if (thoughtTrim.isNotEmpty) estimatedBlockHeight += thoughtBlockMaxH;
        if (insightRaw.isNotEmpty) {
          estimatedBlockHeight += 14.2 * 1.32 * maxObservationTextLines;
          if (thoughtTrim.isNotEmpty) estimatedBlockHeight += blockGap;
        }
        if (actionRaw.isNotEmpty) {
          estimatedBlockHeight += 13.6 * 1.32 * maxObservationTextLines;
          if (thoughtTrim.isNotEmpty || insightRaw.isNotEmpty) {
            estimatedBlockHeight += blockGap;
          }
        }
        estimatedBlockHeight += 12.0;
        const horizontalMargin = 12.0;
        const starLabelGap = 24.0;
        final labelSideSpace = placeLabelOnLeft
            ? max(0.0, x - starLabelGap - horizontalMargin)
            : max(0.0, size.width - (x + starLabelGap) - horizontalMargin);
        final maxLabelWidth = labelSideSpace.clamp(60.0, size.width * 0.68);
        final labelLeftRaw = placeLabelOnLeft
            ? x - starLabelGap - maxLabelWidth
            : x + starLabelGap;
        final labelLeft = labelLeftRaw.clamp(
          horizontalMargin,
          size.width - horizontalMargin - maxLabelWidth,
        );
        widgets.add(
          Positioned(
            left: labelLeft,
            top: y - (estimatedBlockHeight / 2),
            child: IgnorePointer(
              child: SizedBox(
                width: maxLabelWidth,
                child: Opacity(
                  opacity: 0.2 + (0.75 * focusFactor),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: crossAxisAlignment,
                    children: textLines,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  Thought? _currentObservationFocusThought(Size size) {
    if (_observationThoughts.isEmpty) return null;
    final nearestIndex =
        (_observationScrollOffset / _observationSpacing).round();
    final clampedIndex = nearestIndex.clamp(0, _observationThoughts.length - 1);
    return _observationThoughts[clampedIndex];
  }

  @override
  Widget build(BuildContext context) {
    // 赤バッジは「候補件数」ではなく「本日あと何回発火できるか」を表示する。
    final now = DateTime.now();
    final revisitCandidates = _reflectionCandidates(now);
    final revisitCount = kForceRevisitDebug && _thoughts.isNotEmpty
        ? 1
        : (revisitCandidates.isEmpty ? 0 : _remainingReflectionQuota(now));

    final size = MediaQuery.of(context).size;
    final viewPadding = MediaQuery.of(context).viewPadding;
    final isPhoneLayout = size.shortestSide < kTabletBreakpoint;
    final isCompactHeight = isPhoneLayout && size.height <= 740;
    final topControlOffset = viewPadding.top + (isCompactHeight ? 8 : 12);
    final bottomControlOffset =
        viewPadding.bottom + (isCompactHeight ? 10 : 16);
    final controlButtonSize = isCompactHeight ? 50.0 : 56.0;
    final controlIconSize = isCompactHeight ? 21.0 : 24.0;
    _deleteHolePosition = Offset(
      size.width - 80,
      viewPadding.top + 56,
    ); // 右上（ブラックホール削除）
    _revisitCenterPosition = Offset(size.width / 2, size.height / 2); // 中央（再訪）

    return Scaffold(
      backgroundColor: Colors.black,
      drawer: _buildMainDrawer(),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragUpdate: _isObservationMode
            ? (details) {
                setState(() {
                  _observationScrollOffset =
                      (_observationScrollOffset - details.delta.dy)
                          .clamp(0.0, _observationMaxScroll(size.height));
                });
              }
            : null,
        child: Stack(
          children: [
            ..._smallStars.map((star) => Positioned(
                  left: star.dx,
                  top: star.dy,
                  child: Icon(Icons.star,
                      color: Colors.white24,
                      size: 2 + _random.nextDouble() * 2),
                )),
            if (_meteorTrails.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _MeteorShowerPainter(
                      trails: _meteorTrails,
                      now: DateTime.now(),
                    ),
                  ),
                ),
              ),
            // 🚀 ここも _deleteHolePosition に変えます
            Positioned(
              left: _deleteHolePosition.dx - 40,
              top: _deleteHolePosition.dy - 40,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.black,
                      Colors.purple.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
                // ぼんやりとした光の輪
                child: Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 0.5),
                    ),
                  ),
                ),
              ),
            ),

            IgnorePointer(
              ignoring: _tutorialStep < _tutorialInteractiveStep ||
                  _isObservationMode,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    if (_constellationFormed) {
                      _openConstellationRevisit();
                      return;
                    }
                    if (revisitCount > 0 || _isConstellationAnimating) {
                      _startRevisitEvent();
                    }
                  },
                  child: CentralStar(
                    thoughtCount: _thoughts.length,
                    flash: _flashCenter || _constellationFormed,
                    revisitCount: revisitCount,
                  ),
                ),
              ),
            ),

            if (_isObservationMode)
              ..._buildObservationStars(size)
            else
              ..._thoughts.map((thought) {
                final isMember = _activeConstellation.any((t) => t.id == thought.id);
                final isCandidate = revisitCandidates.contains(thought);
                final isMain = _constellationMain?.id == thought.id;
                return ThoughtStar(
                    thought: thought,
                    x: thought.dx,
                    y: thought.dy,
                    content: thought.content,
                    insight: thought.insight ?? '',
                    action: thought.action ?? '',
                    category: thought.category,
                    isDeleting: thought.isDeleting,
                    blackHolePosition: _deleteHolePosition,
                    onDragEnd: () => _checkBlackHoleSuckIn(thought),
                    revisitPosition: _revisitCenterPosition,
                    isTarget: isMember || (!_constellationFormed && isCandidate),
                    isConstellationMain: isMain && _constellationFormed,
                    isFirstMagnitude:
                        _constellationFormed && _activeConstellation.length == 1 && isMember,
                    formationTarget: _constellationFormationTargets[thought.id],
                    isNewlySpawned: thought.id == _spawnHighlightThoughtId,
                    suppressDetailPopup:
                        _tutorialStep < _tutorialInteractiveStep ||
                            _isObservationMode,
                    interactionEnabled: _tutorialStep >= _tutorialInteractiveStep &&
                        !_isConstellationAnimating &&
                        !( _constellationFormed && isMember),
                    onThoughtPersisted: () => setState(() {}),
                    onThoughtRemovedFromHive: () => setState(() {
                      _thoughts.remove(thought);
                      _observationThoughts.remove(thought);
                      _rebuildObservationSearchMatches();
                    }),
                    onCategoryChanged: (newCategory) async {
                      setState(() {
                        thought.category = newCategory;
                      });
                      if (thought.isInBox) {
                        await thought.save();
                        _persistAllThoughts();
                      }

                      debugPrint("Category saved: $newCategory");
                    },
                    onPositionChanged: (newOffset) {
                      setState(() {
                        thought.dx = newOffset.dx;
                        thought.dy = newOffset.dy;
                      });
                    },
                    onTap: (t) {
                      if (_constellationFormed && isMember) {
                        _openConstellationRevisit();
                        return;
                      }
                      _editThought(t);
                    },
                    onLongPress: () {},
                  );
              }),

            if (_onboardingConstellationDemo)
              for (final ghost in _onboardingDemoGhostSlots)
                Positioned(
                  left: ghost.dx - 20,
                  top: ghost.dy - 20,
                  child: IgnorePointer(
                    child: Icon(
                      Icons.star,
                      color: Colors.white.withValues(alpha: 0.42),
                      size: 32,
                    ),
                  ),
                ),

            if (_showConstellationLines &&
                (_activeConstellation.isNotEmpty || _onboardingConstellationDemo))
              Positioned.fill(
                child: ConstellationLinesOverlay(
                  hub: _revisitCenterPosition,
                  memberPositions: _onboardingConstellationDemo
                      ? _onboardingDemoAllSlots
                      : _activeConstellation
                          .map((t) => Offset(t.dx, t.dy))
                          .toList(),
                  onLineConnected: _onConstellationLineConnected,
                  onComplete: _onboardingConstellationDemo
                      ? _onOnboardingConstellationLinesComplete
                      : _onConstellationLinesComplete,
                ),
              ),

            if (_constellationFormed &&
                !_onboardingConstellationDemo &&
                (_constellationName ?? '').isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                top: max(24.0, _revisitCenterPosition.dy - 178),
                child: IgnorePointer(
                  child: Text(
                    _constellationName!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 15,
                      letterSpacing: 2.4,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ),

            if (_tutorialStep >= _tutorialInteractiveStep)
              Positioned(
                left: 16,
                top: topControlOffset,
                child: Builder(
                  builder: (context) => _buildRoundSpaceButton(
                    icon: Icons.menu,
                    onTap: () => Scaffold.of(context).openDrawer(),
                    size: controlButtonSize,
                    iconSize: controlIconSize,
                  ),
                ),
              ),

            if (_tutorialStep >= _tutorialInteractiveStep)
              Positioned(
                left: 0,
                right: 0,
                top: topControlOffset,
                child: Center(
                  child: _buildRoundSpaceButton(
                    icon: Icons.insights,
                    onTap: _openWeeklyGalaxy,
                    size: controlButtonSize,
                    iconSize: controlIconSize,
                  ),
                ),
              ),

            if (_tutorialStep >= _tutorialInteractiveStep && _isObservationMode)
              _buildObservationSearchPanel(
                size: size,
                topControlOffset: topControlOffset,
                controlButtonSize: controlButtonSize,
              ),

            if (_tutorialStep >= _tutorialInteractiveStep)
              Positioned(
                left: 16,
                bottom: bottomControlOffset,
                child: _buildRoundSpaceButton(
                  icon: Icons.travel_explore,
                  active: _isObservationMode,
                  onTap: () => _toggleObservationMode(size.height),
                  size: controlButtonSize,
                  iconSize: controlIconSize,
                ),
              ),

            if (_tutorialStep >= _tutorialInteractiveStep)
              Positioned(
                left: 0,
                right: 0,
                bottom: bottomControlOffset,
                child: Center(
                  child: _buildRoundSpaceButton(
                    icon: Icons.auto_awesome,
                    onTap: () {
                      if (_isRewardAdLoading || _isRewardAdShowing) return;
                      _showMeteorSupportDialog();
                    },
                    size: controlButtonSize,
                    iconSize: controlIconSize,
                    iconChild: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: controlIconSize,
                          color: Colors.white70,
                        ),
                        Positioned(
                          right: 10,
                          top: 16,
                          child: Transform.rotate(
                            angle: -0.45,
                            child: Container(
                              width: 10,
                              height: 1.6,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                color: const Color(0xFF80FFE0)
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                        if (_isRewardAdLoading || _isRewardAdShowing)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

            if (_tutorialStep >= _tutorialInteractiveStep && !_isObservationMode)
              Positioned(
                right: 16,
                bottom: bottomControlOffset,
                child: _buildRoundSpaceButton(
                  icon: Icons.add,
                  onTap: _openFabInput,
                  size: controlButtonSize,
                  iconSize: controlIconSize,
                ),
              ),

            if (_isObservationMode)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.05,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.18),
                          Colors.black.withValues(alpha: 0.38),
                        ],
                        stops: const [0.55, 0.82, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

            _tutorialVeil(),
            _buildTutorialForeground(),
          ],
        ),
      ),
    );
  }

  // 🚀 すべての思考星の状態をHiveに上書き保存するメソッド
  void _persistAllThoughts() {
    try {
      for (var thought in _thoughts) {
        if (thought.isInBox) {
          thought.save();
        }
      }
      debugPrint("Saved latest state for ${_thoughts.length} stars");
    } catch (e) {
      debugPrint("Failed to save stars: $e");
    }
  }

  // 🚀 削除判定メソッドの追加
  void _checkBlackHoleSuckIn(Thought thought) async {
    // 星とブラックホールの距離を計算
    final distance =
        (Offset(thought.dx, thought.dy) - _deleteHolePosition).distance;
    // 距離が一定以下（例: 80px）なら吸い込み開始
    if (distance < 80) {
      setState(() {
        thought.isDeleting = true; // アニメーション開始
      });

      // 吸い込みアニメーション（0.5秒）を待ってから削除
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _thoughts.remove(thought);
        _observationThoughts.remove(thought);
        _rebuildObservationSearchMatches();
      });
      if (thought.isInBox) {
        await thought.delete(); // Hiveから削除
      }

      HapticFeedback.heavyImpact(); // 「消した」感触を手に伝える
    }
  }
}

class _MeteorTrail {
  final DateTime startedAt;
  final Duration duration;
  final Offset start;
  final double distance;
  final double angle;
  final double thickness;
  final double tailLengthFactor;
  final Color glowColor;
  final Color coreColor;
  final Color headColor;

  const _MeteorTrail({
    required this.startedAt,
    required this.duration,
    required this.start,
    required this.distance,
    required this.angle,
    required this.thickness,
    required this.tailLengthFactor,
    required this.glowColor,
    required this.coreColor,
    required this.headColor,
  });
}

class _MeteorShowerPainter extends CustomPainter {
  final List<_MeteorTrail> trails;
  final DateTime now;

  const _MeteorShowerPainter({
    required this.trails,
    required this.now,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final trail in trails) {
      final elapsedMs = now.difference(trail.startedAt).inMilliseconds;
      final totalMs = trail.duration.inMilliseconds;
      if (elapsedMs < 0 || elapsedMs > totalMs) continue;
      final t = (elapsedMs / totalMs).clamp(0.0, 1.0);
      final fade = sin(pi * t);
      final dx = cos(trail.angle) * trail.distance * t;
      final dy = sin(trail.angle) * trail.distance * t;
      final head = Offset(trail.start.dx + dx, trail.start.dy + dy);
      final tailLength = 46 + (trail.distance * trail.tailLengthFactor);
      final tail = Offset(
        head.dx - cos(trail.angle) * tailLength,
        head.dy - sin(trail.angle) * tailLength,
      );

      final glowPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            trail.glowColor.withValues(alpha: 0.25 * fade),
            trail.glowColor.withValues(alpha: 0.92 * fade),
          ],
        ).createShader(Rect.fromPoints(tail, head))
        ..strokeWidth = trail.thickness + 2.8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..blendMode = BlendMode.plus;
      final corePaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            trail.coreColor.withValues(alpha: 0.5 * fade),
            trail.coreColor.withValues(alpha: 0.96 * fade),
          ],
        ).createShader(Rect.fromPoints(tail, head))
        ..strokeWidth = trail.thickness
        ..strokeCap = StrokeCap.round
        ..blendMode = BlendMode.plus;

      canvas.drawLine(tail, head, glowPaint);
      canvas.drawLine(tail, head, corePaint);
      canvas.drawCircle(
        head,
        trail.thickness + 0.9,
        Paint()
          ..color = trail.headColor.withValues(alpha: 0.96 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
          ..blendMode = BlendMode.plus,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MeteorShowerPainter oldDelegate) {
    return oldDelegate.now != now || oldDelegate.trails != trails;
  }
}
