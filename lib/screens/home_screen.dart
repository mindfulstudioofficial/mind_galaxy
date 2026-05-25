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
import '../models/thought.dart';
import '../overlays/thought_popup.dart';
import '../config/ads_config.dart';
import '../services/app_settings.dart';
import '../utils/ad_helper.dart';
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
      'https://docs.google.com/document/d/1o1Y5qaTh8Lx6rJfqkgvrwsdnkDm3OkltABnAD0VeU6M/edit?usp=sharing';
  static const double _tutorialDragVisualYOffset = 50.0;
  static const double _tutorialStarSpawnRightOffset = 64.0;
  static const double _tutorialStarSpawnVerticalOffset = -8.0;
  static const int _maxVisibleThoughts = 30;
  static const double _observationSpacing = 140.0;
  static const int _meteorMinActive = 1;
  static const int _meteorMaxActive = 3;
  static const int _tutorialInteractiveStep = 8;
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

  Offset _deleteHolePosition = Offset.zero; // 右上のゴミ箱用
  Offset _revisitCenterPosition = Offset.zero; // 中央の再訪用

  // チュートリアル管理
  int _tutorialStep = 0;
  final TextEditingController _controller = TextEditingController();
  String _inputText = "";
  Offset _tutorialStar = Offset.zero;
  Offset? _tutorialDragTouchOffset;
  bool _isDragging = false;
  Color _tutorialStarColor = Colors.white;
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
    final centerX = viewport.width * 0.5;
    final centerY = viewport.height * 0.5;
    final spawnX = (centerX + _tutorialStarSpawnRightOffset)
        .clamp(centerX + 28.0, viewport.width - 64.0)
        .toDouble();
    final spawnY = (centerY + _tutorialStarSpawnVerticalOffset)
        .clamp(viewport.height * 0.36, centerY + 28.0)
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
    _tutorialStep = isTutorialDone ? _tutorialInteractiveStep : 0;
    _observationThoughts
      ..clear()
      ..addAll(allThoughts..sort((a, b) => a.createdAt.compareTo(b.createdAt)));
    allThoughts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _thoughts
      ..clear()
      ..addAll(allThoughts.take(_maxVisibleThoughts));
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
      _resetTutorialStarPosition(size);
      setState(() {});
    });
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

  Future<void> _clampThoughtsToViewport(Size size) async {
    const margin = 40.0;
    final minX = margin;
    final maxX = max(margin, size.width - margin);
    final minY = margin;
    final maxY = max(margin, size.height - margin);
    var changed = false;
    for (final t in _thoughts) {
      final nx = t.dx.clamp(minX, maxX);
      final ny = t.dy.clamp(minY, maxY);
      if (nx != t.dx || ny != t.dy) {
        t.dx = nx;
        t.dy = ny;
        await t.save();
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
    _rewardedAd?.dispose();
    _controller.dispose();
    _observationSearchController.dispose();
    super.dispose();
  }

  // --- 再訪イベント関連の処理 ---

  bool _isBlank(String? value) => value == null || value.trim().isEmpty;

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
    final due =
        _thoughts.where((t) => _isNearReflectionTiming(t, now)).toList();
    if (due.isNotEmpty) return due;

    // 全て行動まで入力済みなら、古い星側からランダム抽出できる候補を返す
    final allCompleted =
        _thoughts.isNotEmpty && _thoughts.every((t) => !_isBlank(t.action));
    if (!allCompleted) return const [];

    final oldestFirst = [..._thoughts]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return oldestFirst.take(min(10, oldestFirst.length)).toList();
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

  String _buildRevisitPrompt(Thought thought) {
    final loc = AppLocalizations.of(context)!;
    if (_isBlank(thought.action)) {
      return loc.revisitPromptAddAction;
    }
    if (_isBlank(thought.insight)) {
      return loc.revisitPromptAddInsight;
    }
    if (DateTime.now().difference(thought.createdAt).inDays >= 7) {
      return loc.revisitPromptReflectTimePassed;
    }
    return loc.revisitPromptDeepen;
  }

  void _startRevisitEvent() async {
    HapticFeedback.heavyImpact();

    if (!_hasReflectionQuota()) return;
    final now = DateTime.now();
    final candidates = _reflectionCandidates(now);
    if (candidates.isEmpty) return;

    final target = _pickWeightedRevisitTarget(candidates, now);
    if (target == null) return;

    // 🚀 演出：星を中央に引き寄せる（追加したアニメーションを呼び出す）
    await _animateStarToCenter(target);
    if (!mounted) return;
    await _recordReflectionTriggered();
    if (!mounted) return;

    // 引き寄せが終わったらダイアログを表示
    _showRevisitDialog(target);
  }

  // 🚀 ここから追加
  Future<void> _animateStarToCenter(Thought thought) async {
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height / 2);

    // 移動前の元の場所を覚えておく
    final startX = thought.dx;
    final startY = thought.dy;

    // 0.8秒かけて中央へ移動させる
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // 弾むような動き（elasticOut）を設定
    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.elasticOut,
    );

    // アニメーションの進行に合わせて座標を書き換える
    controller.addListener(() {
      setState(() {
        // lerpDoubleを使って、開始点から中心点までを滑らかに繋ぐ
        thought.dx = lerpDouble(startX, center.dx, animation.value)!;
        thought.dy = lerpDouble(startY, center.dy, animation.value)!;
      });
    });

    // アニメーション開始し、終わるまで待機
    await controller.forward();
    controller.dispose();
  }
  // 🚀 ここまで追加

  void _showRevisitDialog(Thought thought) {
    final loc = AppLocalizations.of(context)!;
    final prompt = _buildRevisitPrompt(thought);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "✨ ${loc.starRevisitTitle}",
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.revisitThoughtLabel,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text("「${thought.content}」",
                style:
                    const TextStyle(color: Colors.yellowAccent, fontSize: 18)),
            const SizedBox(height: 20),
            Text(prompt,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              loc.laterButtonLabel,
              style: const TextStyle(color: Colors.white38),
            ),
          ),
          // 120行目付近
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // 再訪ダイアログを閉じる
              _editThought(thought); // 🚀 共通の詳細表示メソッドを呼ぶ
            },
            child: Text(loc.updateContentButtonLabel),
          ),
        ],
      ),
    );
  }

  void _showThoughtDetail(Thought thought) {
    ThoughtPopup.show(
      context: context,
      thought: thought,
      onUpdated: () {
        if (!mounted) return;
        setState(() {});
      },
      onThoughtDeleted: () {
        if (!mounted) return;
        setState(() {
          _thoughts.remove(thought);
          _observationThoughts.remove(thought);
          _rebuildObservationSearchMatches();
        });
      },
    );
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

  String _colorToCategory(Color color) {
    if (color == Colors.blue) return "future";
    if (color == Colors.purple) return "past";
    if (color == Colors.pink) return "emotion";
    if (color == Colors.yellow) return "action";
    return "neutral";
  }

  // 🚀 ここから追加
  Future<void> _editThought(Thought thought) async {
    await Navigator.push(
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
          focusFollowupOnOpen: true,
        ),
        fullscreenDialog: true,
      ),
    );
    if (!mounted) return;
    setState(() {});
    HapticFeedback.lightImpact();
    debugPrint(
        "${AppLocalizations.of(context)!.revisitComplete}: ${thought.content}");
  }
  // 🚀 ここまで追加

  // --- チュートリアル関連 ---

  Future<void> _createThoughtFromTutorial() async {
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height / 2);
    final radians = _random.nextDouble() * 2 * pi;
    const distance = 120.0;

    final dx = center.dx + distance * cos(radians);
    final dy = center.dy + distance * sin(radians);

    final finalCategory = _colorToCategory(_tutorialStarColor);

    final newThought = Thought(
      id: _thoughtIdCounter++,
      dx: dx,
      dy: dy,
      content: _inputText,
      insight: null,
      action: null,
      category: finalCategory,
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
    setState(() => _insertIntoVisibleThoughts(newThought));
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
  }

  Widget _buildTutorialText(String text) {
    return Container(
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
    // Shorter phones (e.g. iPhone 8 Plus ~736pt): step-3 caption, quadrant hints, and
    // wrapped English lines share the vertical band—keep caption high and hints lower;
    // avoid lifting "Up: Future" into the caption (was translate -12).
    final tutorialCompactLayout = size.height <= 760;
    final tutorialControlCompactLayout = size.height <= 740;
    final tutorialBottomControlOffset =
        viewPadding.bottom + (tutorialControlCompactLayout ? 10.0 : 16.0);
    final tutorialControlButtonSize =
        tutorialControlCompactLayout ? 50.0 : 56.0;
    final tutorialStep3TextAlignment = tutorialCompactLayout
        ? const Alignment(0, -0.58)
        : const Alignment(0, -0.4);
    final tutorialDragHintsTop =
        tutorialCompactLayout ? size.height * 0.27 : 120.0;
    const tutorialSpotlightSize = 86.0;
    final tutorialSpotlightPadding =
        (tutorialSpotlightSize - tutorialControlButtonSize) / 2;

    return Positioned.fill(
      child: Stack(
        children: [
          if (_tutorialStep == 0)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _tutorialStep = 1),
                behavior: HitTestBehavior.opaque,
                child: Align(
                  alignment: const Alignment(0, -0.45), // 🚀 ここでバランスの良い上部に配置
                  child: _buildTutorialText(loc.tutorialStep0),
                ),
              ),
            ),
          if (_tutorialStep == 1)
            Positioned(
              top: size.height * 0.35,
              left: 40,
              right: 40,
              child: Column(
                children: [
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 22),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      hintText: loc.tutorialInputHint,
                      hintStyle: const TextStyle(color: Colors.white38),
                      enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white38)),
                      focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                    ),
                    onChanged: (value) => _inputText = value,
                    onSubmitted: (val) async {
                      if (val.isEmpty) return;
                      HapticFeedback.lightImpact();
                      setState(() {
                        _resetTutorialStarPosition();
                        _tutorialStarColor = Colors.white;
                        _tutorialStep = 2;
                      });

                      await Future.delayed(const Duration(seconds: 1));
                      if (!mounted) return;
                      setState(() => _tutorialStep = 3);
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    loc.tutorialPressEnter,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          if (_tutorialStep == 2)
            Align(
                alignment: const Alignment(0, -0.45),
                child: _buildTutorialText(loc.tutorialStep2)),
          if (_tutorialStep == 3 && !_isDragging)
            Align(
                alignment: tutorialStep3TextAlignment,
                child: _buildTutorialText(loc.tutorialStep3)),
          if (_isDragging)
            Positioned(
              left: 0,
              right: 0,
              top: tutorialDragHintsTop,
              child: IgnorePointer(
                child: Center(
                  child: SizedBox(
                    width: 340,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          loc.tutorialFuture,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 19,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text(
                              loc.tutorialEmotion,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.pink,
                                fontSize: 19,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              loc.tutorialAction,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.yellow,
                                fontSize: 19,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          loc.tutorialPast,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.purple,
                            fontSize: 19,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_tutorialStep == 4)
            Align(
                alignment: const Alignment(0, -0.45),
                child: _buildTutorialText(loc.tutorialStep4)),
          if (_tutorialStep == 5)
            Align(
                alignment: const Alignment(0, -0.45),
                child: _buildTutorialText(loc.tutorialStep5)),
          if (_tutorialStep >= 3)
            Positioned(
              left: _tutorialStar.dx - 48,
              top: _tutorialStar.dy -
                  48 -
                  (_isDragging ? _tutorialDragVisualYOffset : 0),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (details) {
                  setState(() {
                    _isDragging = true;
                    // Keep drag behavior consistent with regular stars.
                    _tutorialDragTouchOffset =
                        const Offset(20, 20) - details.localPosition;
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    final renderBox = context.findRenderObject() as RenderBox?;
                    if (renderBox != null && _tutorialDragTouchOffset != null) {
                      final localTouch =
                          renderBox.globalToLocal(details.globalPosition);
                      _tutorialStar = localTouch + _tutorialDragTouchOffset!;
                    } else {
                      _tutorialStar += details.delta;
                    }
                    if (details.delta.dx.abs() >= details.delta.dy.abs()) {
                      _tutorialStarColor =
                          details.delta.dx >= 0 ? Colors.yellow : Colors.pink;
                    } else {
                      _tutorialStarColor =
                          details.delta.dy >= 0 ? Colors.purple : Colors.blue;
                    }
                  });
                },
                onPanEnd: (_) async {
                  setState(() {
                    _isDragging = false;
                    _tutorialDragTouchOffset = null;
                  });
                  await _createThoughtFromTutorial();
                  if (!mounted) return;
                  setState(() => _tutorialStep = 4);
                  await Future.delayed(const Duration(seconds: 2));
                  if (!mounted) return;
                  setState(() => _tutorialStep = 5);
                  await Future.delayed(const Duration(seconds: 2));
                  if (!mounted) return;

                  setState(() => _tutorialStep = 6);
                },
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: Center(
                    child: AnimatedScale(
                      scale: _isDragging ? 1.5 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child:
                          Icon(Icons.star, color: _tutorialStarColor, size: 40),
                    ),
                  ),
                ),
              ),
            ),
          if (_tutorialStep == 6)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _tutorialStep = 7),
                child: Stack(
                  children: [
                    Align(
                      alignment: const Alignment(0, -0.45),
                      child: _buildTutorialText(loc.tutorialStep6),
                    ),
                    Positioned(
                      right: 16 - tutorialSpotlightPadding,
                      bottom: tutorialBottomControlOffset -
                          tutorialSpotlightPadding,
                      child: IgnorePointer(
                        child: Container(
                          width: tutorialSpotlightSize,
                          height: tutorialSpotlightSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.65),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.28),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_tutorialStep == 7)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  await Hive.box('settings').put('tutorialDone', true);
                  if (!mounted) return;
                  setState(() => _tutorialStep = _tutorialInteractiveStep);
                },
                child: Align(
                  alignment: const Alignment(0, -0.12),
                  child: Container(
                    width: min(size.width - 40, 360.0),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1730).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.insights,
                          color: Colors.lightBlueAccent,
                          size: 30,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          loc.tutorialStep7Title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          loc.tutorialStep7Body,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 246,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF1A2E57),
                                Color(0xFF0E1730),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _TutorialWeeklyPreviewPainter(),
                                ),
                              ),
                              Positioned(
                                left: 78,
                                right: 12,
                                top: 8,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      loc.weekdayMonShort,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.42),
                                        fontSize: 9,
                                      ),
                                    ),
                                    Text(
                                      loc.weekdayTueShort,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.42),
                                        fontSize: 9,
                                      ),
                                    ),
                                    Text(
                                      loc.weekdayWedShort,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.42),
                                        fontSize: 9,
                                      ),
                                    ),
                                    Text(
                                      loc.weekdayThuShort,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.42),
                                        fontSize: 9,
                                      ),
                                    ),
                                    Text(
                                      loc.weekdayFriShort,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.42),
                                        fontSize: 9,
                                      ),
                                    ),
                                    Text(
                                      loc.weekdaySatShort,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.42),
                                        fontSize: 9,
                                      ),
                                    ),
                                    Text(
                                      loc.weekdaySunShort,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.42),
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                left: 8,
                                top: 28,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      loc.categoryFuture,
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.5),
                                        fontSize: 10,
                                      ),
                                    ),
                                    Text(
                                      loc.starsCount(100),
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.34),
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                left: 8,
                                top: 64,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      loc.categoryEmotion,
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.5),
                                        fontSize: 10,
                                      ),
                                    ),
                                    Text(
                                      loc.starsCount(100),
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.34),
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                left: 8,
                                top: 100,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      loc.categoryAction,
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.5),
                                        fontSize: 10,
                                      ),
                                    ),
                                    Text(
                                      loc.starsCount(100),
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.34),
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                left: 8,
                                top: 136,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      loc.categoryPast,
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.5),
                                        fontSize: 10,
                                      ),
                                    ),
                                    Text(
                                      loc.starsCount(100),
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.34),
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                left: 8,
                                top: 172,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      loc.categoryUncategorized,
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.5),
                                        fontSize: 10,
                                      ),
                                    ),
                                    Text(
                                      loc.starsCount(100),
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.34),
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTutorialWeeklyMetricCard(
                                title: loc.weeklyDensity,
                                value: '100%',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildTutorialWeeklyMetricCard(
                                title: loc.weeklyInsightsLabel,
                                value: loc.starsCount(100),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildTutorialWeeklyMetricCard(
                                title: loc.weeklyActionsLabel,
                                value: loc.starsCount(100),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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

  Widget _buildTutorialWeeklyMetricCard({
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B2F52),
            Color(0xFF111C36),
          ],
        ),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF9CF8FF),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openWeeklyGalaxy() async {
    HapticFeedback.selectionClick();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (context) => const WeeklyGalaxyScreen()),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
    if (!mounted) return;
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
    final center = Offset(size.width / 2, size.height / 2);
    const spacing = 45.0;
    const goldenAngleRad = 137.5 * (pi / 180);
    final nextId = _thoughtIdCounter;
    final index = max(1, nextId).toDouble();
    final angle = index * goldenAngleRad;
    final distance = sqrt(index) * spacing;
    final pos = Offset(
      center.dx + cos(angle) * distance,
      center.dy + sin(angle) * distance,
    );

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

  String _formatMonthLabel(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    return "${dt.year}.$m";
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
        final thoughtTrim = thought.content.trim();
        final insightRaw =
            _sanitizeObservationSupplement(thought.insight?.trim() ?? "");
        final actionRaw =
            _sanitizeObservationSupplement(thought.action?.trim() ?? "");
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
        double blockHeight = 0;
        if (thoughtTrim.isNotEmpty) blockHeight += thoughtBlockMaxH;
        if (insightRaw.isNotEmpty) {
          blockHeight += 14.2 * 1.32 * maxObservationTextLines;
          if (thoughtTrim.isNotEmpty) blockHeight += blockGap;
        }
        if (actionRaw.isNotEmpty) {
          blockHeight += 13.6 * 1.32 * maxObservationTextLines;
          if (thoughtTrim.isNotEmpty || insightRaw.isNotEmpty) {
            blockHeight += blockGap;
          }
        }
        blockHeight += 8.0;
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
            top: y - (blockHeight / 2),
            child: IgnorePointer(
              child: SizedBox(
                width: maxLabelWidth,
                height: blockHeight,
                child: Opacity(
                  opacity: 0.2 + (0.75 * focusFactor),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: crossAxisAlignment,
                    mainAxisAlignment: MainAxisAlignment.center,
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
    final revisitCount =
        revisitCandidates.isEmpty ? 0 : _remainingReflectionQuota(now);

    final size = MediaQuery.of(context).size;
    final viewPadding = MediaQuery.of(context).viewPadding;
    final isCompactHeight = size.height <= 740;
    final topControlOffset = viewPadding.top + (isCompactHeight ? 8 : 12);
    final bottomControlOffset =
        viewPadding.bottom + (isCompactHeight ? 10 : 16);
    final controlButtonSize = isCompactHeight ? 50.0 : 56.0;
    final controlIconSize = isCompactHeight ? 21.0 : 24.0;
    _deleteHolePosition = Offset(size.width - 80, 80); // 右上（ブラックホール削除）
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
                    if (revisitCount > 0) {
                      _startRevisitEvent();
                    }
                  },
                  child: CentralStar(
                    thoughtCount: _thoughts.length,
                    flash: _flashCenter,
                    revisitCount: revisitCount,
                  ),
                ),
              ),
            ),

            if (_isObservationMode)
              ..._buildObservationStars(size)
            else
              ..._thoughts.map((thought) => ThoughtStar(
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
                    isTarget: revisitCandidates.contains(thought),
                    suppressDetailPopup:
                        _tutorialStep < _tutorialInteractiveStep ||
                            _isObservationMode,
                    interactionEnabled:
                        _tutorialStep >= _tutorialInteractiveStep,
                    onThoughtPersisted: () => setState(() {}),
                    onThoughtRemovedFromHive: () => setState(() {
                      _thoughts.remove(thought);
                      _observationThoughts.remove(thought);
                      _rebuildObservationSearchMatches();
                    }),
                    onCategoryChanged: (newCategory) async {
                      setState(() {
                        // 1. 画面上の星のデータを更新
                        thought.category = newCategory;
                        if (_tutorialStep < _tutorialInteractiveStep) {
                          _tutorialStarColor = _getCategoryColor(newCategory);
                        }
                      });
                      // 2. Hive 管理オブジェクトのみ永続化する（デモデータはメモリ上のみ）
                      if (thought.isInBox) {
                        await thought.save();
                        // 3. 念のため全体保存も走らせる
                        _persistAllThoughts();
                      }

                      debugPrint("Category saved: $newCategory");
                    },
                    onPositionChanged: (newOffset) {
                      setState(() {
                        // 🚀 ここでリスト内のデータの座標を常に最新にする
                        thought.dx = newOffset.dx;
                        thought.dy = newOffset.dy;
                      });
                    },
                    onTap: (t) => _showThoughtDetail(t),
                    onLongPress: () {},
                  )),

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

            if (_tutorialStep >= 6 && !_isObservationMode)
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

            if (_isObservationMode &&
                _currentObservationFocusThought(size) != null)
              Positioned(
                left: 14,
                top: size.height * 0.46,
                child: Text(
                  _formatMonthLabel(
                      _currentObservationFocusThought(size)!.createdAt),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 18,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w300,
                  ),
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
      // Hive 管理下の星だけ保存する。デモデータは box 外オブジェクト。
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

class _TutorialWeeklyPreviewPainter extends CustomPainter {
  static const _laneColors = <Color>[
    Color(0xFF87DFFF),
    Color(0xFFFFA3E2),
    Color(0xFFFFE89C),
    Color(0xFFE1B2FF),
    Color(0xFFF2F6FF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const left = 74.0;
    final right = size.width - 10;
    final laneHeight = (size.height - 42) / 5;

    for (var lane = 0; lane < 5; lane++) {
      final y = 24 + lane * laneHeight + laneHeight * 0.45;
      final color = _laneColors[lane];
      final phase = lane * 0.6;
      final path = Path()..moveTo(left, y);
      if (lane == 0 || lane == 4) {
        path.cubicTo(
          size.width * 0.34,
          y - 1.4,
          size.width * 0.65,
          y + 1.4,
          right,
          y + 0.4,
        );
      } else if (lane == 1) {
        path.cubicTo(
          size.width * 0.30,
          y + 22,
          size.width * 0.66,
          y - 20,
          right,
          y + 6,
        );
      } else if (lane == 2) {
        path.cubicTo(
          size.width * 0.30,
          y - 10,
          size.width * 0.64,
          y + 11,
          right,
          y + 1.5,
        );
      } else {
        path.cubicTo(
          size.width * 0.30,
          y - 16,
          size.width * 0.66,
          y + 19,
          right,
          y - 7,
        );
      }

      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = lane == 2 ? 4.8 : 4.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      final corePaint = Paint()
        ..color = color.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = lane == 2 ? 2.2 : 1.9
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.3);
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, corePaint);

      for (var i = 0; i < 138; i++) {
        final t = i / 137;
        final x = lerpDouble(left, right, t)!;
        final wave =
            sin((t * pi * 2.4) + phase) * (lane == 0 || lane == 4 ? 1.0 : 2.6);
        final micro = sin((t * pi * 12.0) + phase * 2.1) * 1.4;
        final py = y + wave + micro;
        final twinkle = ((sin((i + 1) * 1.7 + lane) + 1) / 2);
        final radius = 0.7 + (twinkle * 0.9);
        final pointPaint = Paint()
          ..color = color.withValues(alpha: 0.55 + twinkle * 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8)
          ..blendMode = BlendMode.plus;
        canvas.drawCircle(Offset(x, py), radius, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TutorialWeeklyPreviewPainter oldDelegate) =>
      false;
}
