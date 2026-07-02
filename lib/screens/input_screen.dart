import 'dart:math'; // 🚀 【追加】粒子の計算用
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mindgalaxy/l10n/app_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/ads_config.dart';
import '../models/thought.dart';
import '../services/app_settings.dart';
import '../utils/ad_helper.dart';
import '../utils/colors.dart';
import '../utils/responsive_layout.dart';
import '../utils/revisit_prompt.dart';
import '../widgets/constellation_resonance_overlay.dart';

class InputScreen extends StatefulWidget {
  /// Pop result when returning home from bulk edit (highlights the star on home).
  static const highlightOnReturnHome = 'highlightOnReturn';

  final String? initialContent;
  final String? initialInsight;
  final String? initialAction;
  final double? initialStarSize;
  final double? initialGlowIntensity;
  final double? initialParticleSpread;
  final Thought? thoughtToEdit;
  final bool forceBulkMode;
  final bool focusFollowupOnOpen;
  /// When true (central-star revisit flow), advances automatic revisit schedule on save.
  final bool advanceRevisitScheduleOnSave;
  /// Surrounding constellation members shown as read-only context cards.
  final List<Thought>? contextThoughts;

  const InputScreen({
    super.key,
    this.initialContent,
    this.initialInsight,
    this.initialAction,
    this.initialStarSize,
    this.initialGlowIntensity,
    this.initialParticleSpread,
    this.thoughtToEdit,
    this.forceBulkMode = false,
    this.focusFollowupOnOpen = false,
    this.advanceRevisitScheduleOnSave = false,
    this.contextThoughts,
  });

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen>
    with TickerProviderStateMixin {
  /// まとめ入力: 粒子はやや強め、グローはキーボード有無で別係数。
  static const double _bulkParticleBoost = 1.28;
  static const double _bulkGlowBoostKeyboard = 1.05;
  static const double _bulkGlowBoostNoKeyboard = 1.1;
  static const double _contextCarouselHeight = 120.0;

  // 🚀 複数のAnimationControllerを使うため変更

  late TextEditingController _controller;
  late TextEditingController insightController;
  late TextEditingController actionController;
  final FocusNode _insightFocusNode = FocusNode();
  final FocusNode _actionFocusNode = FocusNode();
  final FocusNode _contentFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _bulkInsightFieldKey = GlobalKey();
  final GlobalKey _bulkBottomSectionKey = GlobalKey();
  final GlobalKey _saveButtonKey = GlobalKey();

  bool isBulkMode = false;

  // 保存時：星座共鳴 → 銀河へ還元する演出
  late AnimationController _saveAnimController;
  final Set<int> _rippleHapticsFired = {};
  bool _resonateHapticFired = false;
  bool _collapseHapticFired = false;

  // 🚀 【追加】常時またたき・粒子アニメーション用
  late AnimationController _idleController;
  late Animation<double> _pulseAnim;
  late Animation<double> _particleOpacityAnim;
  late AnimationController _inputPulseController;
  late Animation<double> _inputPulseAnim;

  bool _isSaving = false;
  bool _isNavigatingAway = false;
  bool _isDiscardDialogOpen = false;
  bool _isModeToggleLocked = false;
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  bool _hasBannerAdError = false;
  bool _bannerLoadScheduled = false;
  final Random _random = Random();
  List<Offset> _particleNoiseOffsets = const [];
  int _particleNoiseCount = 0;
  double _starSize = 1.0;
  double _glowIntensity = 1.0;
  double _particleSpread = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent ?? "");
    insightController =
        TextEditingController(text: widget.initialInsight ?? "");
    actionController = TextEditingController(text: widget.initialAction ?? "");

    if (widget.forceBulkMode ||
        widget.initialInsight != null ||
        widget.initialAction != null) {
      isBulkMode = true;
    }

    _starSize = widget.initialStarSize ??
        _sizeFromContentLength(_controller.text.length);
    _glowIntensity = widget.initialGlowIntensity ??
        _glowFromInsightLength(insightController.text.length);
    _particleSpread = widget.initialParticleSpread ??
        _spreadFromActionLength(actionController.text.length);

    // --- 保存時：星座共鳴演出 ---
    _saveAnimController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..addListener(_onSaveResonanceTick);

    // --- 🚀 【追加】常時アニメーション設定 (脈動と粒子) ---
    _idleController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true); // ゆっくり繰り返す

    // 脈動 (Glowの揺らぎ)
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
    );

    // 粒子の不透明度 (生まれて消える)
    _particleOpacityAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.7), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 0.0), weight: 70),
    ]).animate(CurvedAnimation(parent: _idleController, curve: Curves.easeOut));

    _inputPulseController = AnimationController(
      duration: const Duration(milliseconds: 170),
      vsync: this,
    );
    _inputPulseAnim = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(
          parent: _inputPulseController, curve: Curves.easeOutCubic),
    );

    if (kShowAds) {
      _loadBannerAd();
    }

    _insightFocusNode.addListener(_bulkScrollFocusedFieldStable);
    _actionFocusNode.addListener(_bulkScrollFocusedFieldStable);
    _contentFocusNode.addListener(() {
      if (isBulkMode) {
        _scrollContentRowIntoView();
      } else {
        _scrollSimpleFieldIntoView();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.focusFollowupOnOpen) return;
      final hasInsight = insightController.text.trim().isNotEmpty;
      final hasAction = actionController.text.trim().isNotEmpty;
      if (!hasInsight) {
        _insightFocusNode.requestFocus();
      } else if (!hasAction) {
        _actionFocusNode.requestFocus();
      } else {
        _actionFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    insightController.dispose();
    actionController.dispose();
    _insightFocusNode.dispose();
    _actionFocusNode.dispose();
    _contentFocusNode.dispose();
    _scrollController.dispose();
    _saveAnimController.dispose();
    _idleController.dispose(); // 🚀 忘れずにdispose
    _inputPulseController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  bool get _supportsMobileAds {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// [double.clamp] throws when [lower] > [upper]; star layout can hit that edge case.
  double _bounded(double value, double lower, double upper) {
    final lo = min(lower, upper);
    final hi = max(lower, upper);
    return value.clamp(lo, hi);
  }

  void _syncParticleNoise(int count) {
    if (count <= 0) {
      _particleNoiseCount = 0;
      _particleNoiseOffsets = const [];
      return;
    }
    if (count == _particleNoiseCount) return;
    _particleNoiseCount = count;
    _particleNoiseOffsets = List.generate(
      count,
      (_) => Offset(
        (_random.nextDouble() - 0.5) * 3,
        (_random.nextDouble() - 0.5) * 3,
      ),
    );
  }

  void _scheduleBannerAdLoadIfNeeded() {
    if (_bannerLoadScheduled ||
        _bannerAd != null ||
        _hasBannerAdError ||
        !kShowAds ||
        !_supportsMobileAds ||
        AppSettings.isPremium) {
      return;
    }
    _bannerLoadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bannerLoadScheduled = false;
      if (mounted) _loadBannerAd();
    });
  }

  /// 一番上の思考入力にフォーカスしたときは星側を見えるよう先頭へ寄せる。
  void _scrollContentRowIntoView() {
    if (!mounted || !isBulkMode) return;
    if (MediaQuery.of(context).viewInsets.bottom <= 0) return;
    if (!_contentFocusNode.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// シンプル入力のみ：フォーカス時は保存まで見えるよう末尾へ。
  void _scrollSimpleFieldIntoView() {
    if (!mounted || isBulkMode) return;
    final inset = MediaQuery.of(context).viewInsets.bottom;
    if (inset <= 0 || !_contentFocusNode.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      _scrollController.animateTo(
        max,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// まとめ入力かつキーボード表示中のみ。ensureVisible で必要最小限スクロール（割合スクロールの揺れを避ける）。
  void _bulkScrollFocusedFieldStable() {
    if (!mounted || !isBulkMode) return;
    if (MediaQuery.of(context).viewInsets.bottom <= 0) return;
    if (!_insightFocusNode.hasFocus && !_actionFocusNode.hasFocus) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!isBulkMode) return;
      if (MediaQuery.of(context).viewInsets.bottom <= 0) return;

      BuildContext? target;
      double alignment;

      if (_actionFocusNode.hasFocus) {
        target = _bulkBottomSectionKey.currentContext;
        alignment = 1.0;
      } else if (_insightFocusNode.hasFocus) {
        target = _bulkInsightFieldKey.currentContext;
        alignment = 0.22;
      } else {
        return;
      }

      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: alignment,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    });
  }

  void _loadBannerAd() {
    if (!kShowAds ||
        !_supportsMobileAds ||
        AppSettings.isPremium ||
        _bannerAd != null) {
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _isBannerAdReady = true;
            _hasBannerAdError = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _bannerAd = null;
            _isBannerAdReady = false;
            _hasBannerAdError = true;
          });
        },
      ),
    )..load();
  }

  // ===============================================
  // 🚀 星の見た目を計算する動的なロジック
  // ===============================================

  // 各フィールドの文字数
  int get contentLen => _controller.text.length;
  int get insightLen => insightController.text.length;
  int get actionLen => actionController.text.length;

  double _sizeFromContentLength(int length) {
    return (1.0 + (length.clamp(0, 120) / 120) * 1.8)
        .clamp(1.0, 2.8)
        .toDouble();
  }

  // ⭐ 星の色：入力状況で変化（白 -> 青白 -> 黄金）
  Color _calculateStarColor() {
    return Colors.white;
  }

  double _glowFromInsightLength(int length) {
    return (1.0 + (length.clamp(0, 120) / 120) * 4.4)
        .clamp(1.0, 5.2)
        .toDouble();
  }

  // ⭐ 粒子の数：行動が書かれた時だけ、粒子を放つ
  int _calculateParticleCount() {
    if (actionLen == 0) return 0;
    return (12 + ((_particleSpread - 1.0) * 24)).round().clamp(12, 44);
  }

  double _spreadFromActionLength(int length) {
    return (1.0 + (length.clamp(0, 120) / 120) * 4.6)
        .clamp(1.0, 5.8)
        .toDouble();
  }

  // ⭐ 粒子の飛び散る半径（行動入力でのみ成長）
  double _calculateParticleRadius() {
    return 14.0 + (_particleSpread * 24.0);
  }

  void _triggerInputPulse() {
    _inputPulseController.forward(from: 0).then((_) {
      if (mounted) {
        _inputPulseController.reverse();
      }
    });
  }

  bool _hasUnsavedChanges() {
    if (widget.thoughtToEdit != null) {
      final thought = widget.thoughtToEdit!;
      final initialContent =
          (widget.initialContent ?? thought.content).trim();
      final initialInsight =
          (widget.initialInsight ?? thought.insight ?? '').trim();
      final initialAction =
          (widget.initialAction ?? thought.action ?? '').trim();
      return _controller.text.trim() != initialContent ||
          insightController.text.trim() != initialInsight ||
          actionController.text.trim() != initialAction;
    }
    return _controller.text.trim().isNotEmpty ||
        insightController.text.trim().isNotEmpty ||
        actionController.text.trim().isNotEmpty;
  }

  Future<bool> _confirmDiscardIfNeeded() async {
    if (_isDiscardDialogOpen) return false;
    if (!_hasUnsavedChanges()) return true;
    final loc = AppLocalizations.of(context)!;
    _isDiscardDialogOpen = true;
    try {
      final shouldDiscard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF0D1322),
          title: Text(
            loc.discardInputTitle,
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            loc.discardInputMessage,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(loc.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(loc.discardInputConfirm),
            ),
          ],
        ),
      );
      return shouldDiscard == true;
    } finally {
      _isDiscardDialogOpen = false;
    }
  }

  Future<void> _handleBackToHome() async {
    if (_isNavigatingAway) return;
    _isNavigatingAway = true;
    try {
      if (!await _confirmDiscardIfNeeded()) return;
      if (!mounted) return;
      if (widget.thoughtToEdit != null) {
        Navigator.of(context).pop(InputScreen.highlightOnReturnHome);
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } finally {
      _isNavigatingAway = false;
    }
  }

  Future<void> _toggleInputMode() async {
    if (_isModeToggleLocked) return;
    _isModeToggleLocked = true;
    final enteringBulk = !isBulkMode;
    if (mounted) {
      setState(() => isBulkMode = !isBulkMode);
    }
    if (enteringBulk) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    await Future<void>.delayed(const Duration(milliseconds: 160));
    _isModeToggleLocked = false;
  }

  Widget? _buildUnifiedCounter(
    BuildContext context, {
    required int currentLength,
    required int? maxLength,
  }) {
    if (maxLength == null) return null;
    final remaining = maxLength - currentLength;
    Color color = Colors.white38;
    if (remaining <= 0) {
      color = Colors.redAccent.withValues(alpha: 0.9);
    } else if (remaining <= 20) {
      color = Colors.orangeAccent.withValues(alpha: 0.9);
    }
    return Text(
      "$currentLength/$maxLength",
      style: TextStyle(
        color: color,
        fontSize: 11,
        letterSpacing: 0.3,
      ),
    );
  }

  InputDecoration _labeledInputDecoration({
    required String label,
    required String hint,
    required int currentLength,
    required int? maxLength,
    double hintFontSize = 15,
    double fillAlpha = 0.05,
  }) {
    final labelStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.62),
      fontSize: 13,
      fontWeight: FontWeight.w500,
    );
    final outlineBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.inputBorder, width: 1),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.inputFocus, width: 1.25),
    );
    final focusedLabelStyle =
        labelStyle.copyWith(color: AppColors.inputFocus);
    return InputDecoration(
      labelText: label,
      labelStyle: labelStyle,
      floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return focusedLabelStyle;
        }
        return labelStyle;
      }),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      alignLabelWithHint: true,
      hintText: hint,
      hintMaxLines: 2,
      hintStyle: TextStyle(
        color: Colors.white38,
        fontSize: hintFontSize,
        height: 1.25,
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: fillAlpha),
      border: outlineBorder,
      enabledBorder: outlineBorder,
      focusedBorder: focusedBorder,
      counter: _buildUnifiedCounter(
        context,
        currentLength: currentLength,
        maxLength: maxLength,
      ),
    );
  }

  void _onSaveResonanceTick() {
    if (!_isSaving) return;
    final t = _saveAnimController.value;
    final contextCount = widget.contextThoughts?.length ?? 0;

    for (var i = 0; i < contextCount; i++) {
      if (_rippleHapticsFired.contains(i)) continue;
      final reach = 0.12 + i * 0.09 + 0.12;
      if (t >= reach) {
        _rippleHapticsFired.add(i);
        HapticFeedback.lightImpact();
      }
    }

    if (!_resonateHapticFired && t >= 0.52) {
      _resonateHapticFired = true;
      HapticFeedback.mediumImpact();
    }

    if (!_collapseHapticFired && t >= 0.75) {
      _collapseHapticFired = true;
      HapticFeedback.heavyImpact();
    }
  }

  List<Color> _resonanceContextColors() {
    final thoughts = widget.contextThoughts;
    if (thoughts == null || thoughts.isEmpty) return const [];
    return thoughts.map((t) => _contextCategoryColor(t.category)).toList();
  }

  // --- 保存処理 ---
  Future<void> _saveThought() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSaving = true);
    _rippleHapticsFired.clear();
    _resonateHapticFired = false;
    _collapseHapticFired = false;
    HapticFeedback.heavyImpact();
    _saveAnimController.reset();
    await _saveAnimController.forward();
    if (!mounted) return;
    if (widget.thoughtToEdit != null) {
      final thought = widget.thoughtToEdit!;
      thought.content = text;
      thought.insight = insightController.text.trim().isEmpty
          ? null
          : insightController.text.trim();
      thought.action = actionController.text.trim().isEmpty
          ? null
          : actionController.text.trim();
      thought.starSize = _starSize;
      thought.glowIntensity = _glowIntensity;
      thought.particleSpread = _particleSpread;
      if (widget.advanceRevisitScheduleOnSave) {
        final batch = <Thought>[thought];
        if (widget.contextThoughts != null) {
          batch.addAll(widget.contextThoughts!);
        }
        await applyRevisitSaveScheduleToGroup(batch);
      } else {
        thought.revisitAt = DateTime.now().add(const Duration(days: 1));
        if (thought.isInBox) {
          await thought.save();
        }
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      return;
    }

    Navigator.pop(context, {
      'content': text,
      'insight': insightController.text.trim(),
      'action': actionController.text.trim(),
      'starSize': _starSize,
      'glowIntensity': _glowIntensity,
      'particleSpread': _particleSpread,
    });
  }

  Widget _buildBottomBannerAd({required bool isPremium}) {
    if (isPremium) return const SizedBox.shrink();
    if (!kShowAds) return const SizedBox.shrink();
    if (!_supportsMobileAds) return const SizedBox(height: 52);
    _scheduleBannerAdLoadIfNeeded();
    return Container(
      height: 52,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.transparent,
      ),
      alignment: Alignment.center,
      child: _isBannerAdReady && _bannerAd != null
          ? AdWidget(ad: _bannerAd!)
          : _hasBannerAdError
              ? const SizedBox.shrink()
              : const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
    );
  }

  Color _contextCategoryColor(String category) {
    switch (category) {
      case 'future':
        return Colors.blue;
      case 'past':
        return Colors.purple;
      case 'emotion':
        return Colors.pink;
      case 'action':
        return Colors.yellow;
      default:
        return Colors.white54;
    }
  }

  Widget _buildContextThoughtSection(AppLocalizations loc) {
    final contextThoughts = widget.contextThoughts;
    if (contextThoughts == null || contextThoughts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.constellationContextLabel,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.42),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: _contextCarouselHeight,
          width: double.infinity,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            clipBehavior: Clip.none,
            itemCount: contextThoughts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final thought = contextThoughts[index];
              return _buildContextThoughtCard(
                thought,
                _contextCategoryColor(thought.category),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContextThoughtCard(Thought thought, Color color) {
    return Container(
      width: 160,
      height: _contextCarouselHeight,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.035),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(Icons.star, size: 11, color: color),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  thought.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          if ((thought.insight ?? '').isNotEmpty)
            Text(
              thought.insight!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                height: 1.2,
              ),
            ),
          if ((thought.action ?? '').isNotEmpty) ...[
            if ((thought.insight ?? '').isNotEmpty) const SizedBox(height: 2),
            Text(
              thought.action!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color.withValues(alpha: 0.72),
                fontSize: 10,
                height: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 計算された星のパラメータを取得
    final starColor = _calculateStarColor();
    final starSize = 28.0 * _starSize;
    final glowRadius = 12.0 * _glowIntensity;
    final particleCount = _calculateParticleCount();
    final particleRadius = _calculateParticleRadius();

    // ローカライズ取得
    final loc = AppLocalizations.of(context)!;
    final viewPadding = MediaQuery.of(context).viewPadding;
    final isTablet = context.isTabletLayout;
    final bottomSafeInset = viewPadding.bottom;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final keyboardVisible = keyboardInset > 0;
    final hasContextThoughts =
        widget.contextThoughts != null && widget.contextThoughts!.isNotEmpty;
    final showFooterAd =
        !keyboardVisible && !AppSettings.isPremium && kShowAds;
    /// まとめ入力＋キーボード時は保存を画面下に固定し、キーボード直上で常にタップ可能にする。
    final bool pinBulkSaveAboveKeyboard = keyboardVisible && isBulkMode;
    final double pinnedBulkSaveOuterBottom =
        (8 + MediaQuery.paddingOf(context).bottom).clamp(8.0, 64.0);
    const double pinnedBulkSaveBarTotalHeight = 84.0;
    // キーボード時は末尾（行動枠・保存）までスクロールできる余白を確保
    final formBottomPadding = keyboardVisible
        ? (pinBulkSaveAboveKeyboard && isBulkMode
            ? pinnedBulkSaveBarTotalHeight +
                pinnedBulkSaveOuterBottom +
                keyboardInset +
                20.0
            : 32.0 +
                bottomSafeInset +
                keyboardInset +
                (isBulkMode ? 112.0 : 48.0))
        : ((showFooterAd ? 104.0 : 32.0) + bottomSafeInset);
    final horizontalPadding = isTablet ? 40.0 : 28.0;
    final starAreaSize = isTablet ? 240.0 : 200.0;
    // ヘッダー行（8 + 48）の直下から入力欄までのオフセット
    const headerBlockHeight = 56.0;
    double formTopGap;
    final double fixedStarTop;
    final double? bulkStarBandTop;
    final double? bulkStarBandHeight;
    final double bulkKeyboardStarSize = isTablet ? 64.0 : 56.0;
    if (isBulkMode) {
      if (keyboardVisible) {
        // キーボード時: ヘッダー直下の専用帯に星を収め、入力枠と被らせない
        bulkStarBandTop = viewPadding.top + headerBlockHeight;
        bulkStarBandHeight = bulkKeyboardStarSize;
        formTopGap = bulkStarBandHeight + 18.0;
      } else {
        const bulkLayoutLift = 16.0;
        bulkStarBandTop = viewPadding.top + headerBlockHeight - bulkLayoutLift;
        bulkStarBandHeight = hasContextThoughts
            ? (isTablet ? 148.0 : 132.0)
            : (isTablet ? 210.0 : 200.0);
        formTopGap = bulkStarBandHeight +
            (isTablet ? 12.0 : 8.0) -
            bulkLayoutLift;
      }
      fixedStarTop = bulkStarBandTop; // まとめ入力は ClipRect 帯内で配置
    } else {
      bulkStarBandTop = null;
      bulkStarBandHeight = null;
      formTopGap = keyboardVisible
          ? (isTablet ? 88.0 : 108.0)
          : (isTablet ? 140.0 : 170.0);
      fixedStarTop = viewPadding.top +
          (keyboardVisible ? 20.0 : (isTablet ? 36.0 : 46.0));
    }
    // 演出キャンバス: まとめ入力＋キーボードはコンパクト、それ以外はシンプル入力と同一
    final starEffectSize = keyboardVisible
        ? (isBulkMode
            ? bulkKeyboardStarSize
            : (starAreaSize * 0.52).clamp(96.0, starAreaSize))
        : starAreaSize;

    final bulkFieldGapAfterContent =
        keyboardVisible && isBulkMode ? 8.0 : 16.0;
    final bulkFieldGapBetween =
        keyboardVisible && isBulkMode ? 8.0 : 12.0;
    final bulkContentMaxLines = keyboardVisible && isBulkMode ? 2 : 3;

    final fieldScrollPadding = EdgeInsets.fromLTRB(
      0,
      keyboardVisible ? headerBlockHeight + 12 : 16,
      0,
      96 + keyboardInset.clamp(0.0, 520.0) * 0.45,
    );
    // まとめ入力の下段：OS / EditableText 側の ensureVisible と競合しづらいよう余白を抑える
    final bulkFieldScrollPadding = keyboardVisible && isBulkMode
        ? EdgeInsets.fromLTRB(
            0,
            64,
            0,
            24 + keyboardInset * 0.25 + pinnedBulkSaveBarTotalHeight * 0.5,
          )
        : fieldScrollPadding;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_isNavigatingAway) return;
        _isNavigatingAway = true;
        try {
          final navigator = Navigator.of(context);
          if (!await _confirmDiscardIfNeeded()) return;
          if (!navigator.mounted) return;
          if (navigator.canPop()) {
            await navigator.maybePop();
          }
        } finally {
          _isNavigatingAway = false;
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        // まとめ入力は viewInsets.bottom で手動調整（二重リサイズを防ぐ）
        resizeToAvoidBottomInset: !isBulkMode,
        body: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            // ===============================================
            // 🚀 背景の成長・発光・粒子する星（位置調整付き）
            // ===============================================
            if (!_isSaving)
              AnimatedBuilder(
                animation: Listenable.merge([
                  _idleController,
                  _inputPulseController,
                  _controller,
                  insightController,
                  actionController,
                ]),
                builder: (context, _) {
                  final particleBoost =
                      isBulkMode ? _bulkParticleBoost : 1.0;
                  final glowBoost = isBulkMode
                      ? (keyboardVisible
                          ? _bulkGlowBoostKeyboard
                          : _bulkGlowBoostNoKeyboard)
                      : 1.0;
                  final glowScale = isBulkMode && keyboardVisible
                      ? (starEffectSize / starAreaSize).clamp(0.38, 0.55)
                      : 1.0;
                  final hasGlow = insightLen > 0;
                  // まとめ入力は常に内側グロー（キーボード開閉で描画経路が切り替わらない）
                  final useInnerGlowLayout = isBulkMode && hasGlow;
                  final pulseBoost = 1.0 +
                      (_inputPulseAnim.value - 1.0) *
                          (isBulkMode ? particleBoost : 1.0);
                  final pulseT = (_inputPulseController.value).clamp(0.0, 1.0);
                  final boostedStarColor = Color.lerp(
                          starColor, Colors.amberAccent, pulseT * 0.55) ??
                      starColor;
                  // 粒子（外側）→ グロー（内側）→ 星（中心）
                  var dynamicGlow = hasGlow
                      ? glowRadius * _pulseAnim.value * glowBoost * glowScale
                      : 0.0;
                  if (hasGlow && isBulkMode && keyboardVisible) {
                    dynamicGlow = dynamicGlow.clamp(5.0, 14.0);
                  }
                  final whiteGlowAlpha = (0.28 + pulseT * 0.14) *
                      (isBulkMode && !keyboardVisible ? 1.1 : 1.0);
                  final cyanGlowAlpha = (0.16 + pulseT * 0.14) *
                      (isBulkMode && !keyboardVisible ? 1.12 : 1.0);
                  const whiteBlurMul = 1.2;
                  const cyanBlurMul = 0.75;
                  const whiteSpreadMul = 2.4;
                  const cyanSpreadMul = 0.95;
                  const innerGlowBlurScale = 0.72;
                  const innerGlowSpreadScale = 0.38;
                  final glowSpreadBase =
                      (_glowIntensity - 1.0) * glowBoost * glowScale;
                  final renderParticleCount = particleCount == 0
                      ? 0
                      : (particleCount * particleBoost)
                          .round()
                          .clamp(particleCount, 52);
                  _syncParticleNoise(renderParticleCount);
                  final renderParticleRadius =
                      particleRadius * particleBoost;
                  final renderParticleSize =
                      (1.6 + (_particleSpread - 1.0) * 3.6) *
                          (isBulkMode ? 1.12 : 1.0);
                  final renderStarSize = isBulkMode && keyboardVisible
                      ? (24.0 * _starSize).clamp(22.0, 38.0)
                      : starSize;
                  final activeParticleRadius = renderParticleCount > 0
                      ? renderParticleRadius * _pulseAnim.value
                      : 0.0;
                  // グローは粒子リングより内側。粒子が小さいときも clamp 逆転で落ちないよう min/max で合成
                  final innerGlowDiameter = useInnerGlowLayout
                      ? (renderParticleCount > 0
                          ? min(
                              starEffectSize,
                              max(
                                renderStarSize * 1.4,
                                activeParticleRadius * 0.88,
                              ),
                            )
                          : keyboardVisible
                              ? _bounded(
                                  renderStarSize * 2.1,
                                  28.0,
                                  starEffectSize * 0.82,
                                )
                              : _bounded(
                                  renderStarSize * 2.2 + dynamicGlow * 0.55,
                                  56.0,
                                  starEffectSize * 0.42,
                                ))
                      : starEffectSize;
                  final innerBlurCap = renderParticleCount > 0
                      ? activeParticleRadius * 0.36
                      : innerGlowDiameter * 0.24;

                  List<BoxShadow> buildGlowShadows({
                    required double blurScale,
                    required double spreadScale,
                    double? maxBlur,
                  }) {
                    double cappedBlur(double raw) {
                      final v = raw * blurScale;
                      return maxBlur == null ? v : min(v, maxBlur);
                    }

                    return [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: whiteGlowAlpha),
                        blurRadius:
                            cappedBlur(dynamicGlow * whiteBlurMul),
                        spreadRadius:
                            glowSpreadBase * whiteSpreadMul * spreadScale,
                      ),
                      BoxShadow(
                        color: Colors.cyanAccent
                            .withValues(alpha: cyanGlowAlpha),
                        blurRadius:
                            cappedBlur(dynamicGlow * cyanBlurMul),
                        spreadRadius:
                            glowSpreadBase * cyanSpreadMul * spreadScale,
                      ),
                    ];
                  }

                  final starVisual = AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: starEffectSize,
                    height: starEffectSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: hasGlow && !useInnerGlowLayout
                          ? buildGlowShadows(
                              blurScale: 1.0,
                              spreadScale: 1.0,
                            )
                          : const [],
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        if (useInnerGlowLayout)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            width: innerGlowDiameter,
                            height: innerGlowDiameter,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: buildGlowShadows(
                                blurScale: innerGlowBlurScale,
                                spreadScale: innerGlowSpreadScale,
                                maxBlur: innerBlurCap,
                              ),
                            ),
                          ),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                              end: renderStarSize * pulseBoost),
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          builder: (context, animatedSize, _) {
                            return Icon(
                              Icons.star_rounded,
                              color: boostedStarColor,
                              size: animatedSize,
                            );
                          },
                        ),
                        if (renderParticleCount > 0)
                          ...List.generate(renderParticleCount, (i) {
                            final angle =
                                (i / renderParticleCount) * 2 * pi;
                            final currentRadius = activeParticleRadius;
                            final noise = i < _particleNoiseOffsets.length
                                ? _particleNoiseOffsets[i]
                                : Offset.zero;

                            return Transform.translate(
                              offset: Offset(
                                cos(angle) * currentRadius + noise.dx,
                                sin(angle) * currentRadius + noise.dy,
                              ),
                              child: Opacity(
                                opacity: (_particleOpacityAnim.value * 1.25)
                                    .clamp(0.0, 1.0),
                                child: Icon(
                                  Icons.circle,
                                  size: renderParticleSize,
                                  color: boostedStarColor,
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  );

                  if (isBulkMode &&
                      bulkStarBandTop != null &&
                      bulkStarBandHeight != null) {
                    return Positioned(
                      top: bulkStarBandTop,
                      left: 0,
                      right: 0,
                      height: bulkStarBandHeight,
                      child: Align(
                        alignment: keyboardVisible
                            ? Alignment.topCenter
                            : Alignment.center,
                        child: SizedBox(
                          width: starEffectSize,
                          height: starEffectSize,
                          child: starVisual,
                        ),
                      ),
                    );
                  }

                  return Positioned(
                    left: 0,
                    right: 0,
                    top: fixedStarTop,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: starVisual,
                    ),
                  );
                },
              ),

            // ===============================================
            // 入力UI（スクロール可能）
            // ===============================================
            if (!_isSaving)
              SafeArea(
                bottom: false,
                child: ResponsiveContentWidth(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    children: [
                      // モード切替・ホームはキーボード表示中も常に見えるようスクロール外に固定
                      DecoratedBox(
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          border: Border(
                            bottom: BorderSide(
                              color: Color(0x1AFFFFFF),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const SizedBox(width: 48, height: 48),
                              TextButton(
                                onPressed: _toggleInputMode,
                                child: Text(
                                  isBulkMode ? loc.simpleMode : loc.bulkMode,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 15,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _handleBackToHome,
                                icon: const Icon(
                                  Icons.home_outlined,
                                  color: Colors.white70,
                                ),
                                tooltip: loc.homeTooltip,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          physics: keyboardVisible
                              ? const AlwaysScrollableScrollPhysics()
                              : null,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.only(bottom: formBottomPadding),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              textSelectionTheme:
                                  const TextSelectionThemeData(
                                cursorColor: AppColors.inputFocus,
                                selectionColor: Color(0x408FB0E8),
                                selectionHandleColor: AppColors.inputFocus,
                              ),
                            ),
                            child: Column(
                            children: [
                              // モードに応じて上部余白を調整（星の位置に合わせる）
                              SizedBox(height: formTopGap),

                              // メイン思考入力
                              TextField(
                                controller: _controller,
                                focusNode: _contentFocusNode,
                                maxLength: 200,
                                minLines: 1,
                                maxLines: bulkContentMaxLines,
                                autofocus: !isBulkMode,
                                scrollPadding: fieldScrollPadding,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 18),
                                onChanged: (value) {
                                  setState(() {
                                    _starSize =
                                        _sizeFromContentLength(value.length);
                                  });
                                  _triggerInputPulse();
                                },
                                decoration: _labeledInputDecoration(
                                  label: loc.thoughtLabel,
                                  hint: loc.inputHint,
                                  currentLength: contentLen,
                                  maxLength: 200,
                                  fillAlpha: 0.10,
                                ),
                              ),
                              SizedBox(height: bulkFieldGapAfterContent),

                              // まとめ入力フィールド
                              if (isBulkMode) ...[
                                KeyedSubtree(
                                  key: _bulkInsightFieldKey,
                                  child: TextField(
                                    controller: insightController,
                                    focusNode: _insightFocusNode,
                                    maxLength: 200,
                                    maxLines: 2,
                                    scrollPadding: bulkFieldScrollPadding,
                                    style:
                                        const TextStyle(color: Colors.white),
                                    onChanged: (_) {
                                      setState(() {
                                        _glowIntensity = _glowFromInsightLength(
                                            insightController.text.length);
                                      });
                                      _triggerInputPulse();
                                      if (insightLen == 1) {
                                        HapticFeedback
                                            .lightImpact(); // 書き始めにフィードバック
                                      }
                                    },
                                    decoration: _labeledInputDecoration(
                                      label: loc.insightLabel,
                                      hint: loc.insightHint,
                                      currentLength: insightLen,
                                      maxLength: 200,
                                    ),
                                ),
                                ),
                                SizedBox(height: bulkFieldGapBetween),
                                Column(
                                  key: _bulkBottomSectionKey,
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    TextField(
                                      controller: actionController,
                                      focusNode: _actionFocusNode,
                                      maxLength: 200,
                                      maxLines: 2,
                                      scrollPadding: bulkFieldScrollPadding,
                                      style:
                                          const TextStyle(color: Colors.white),
                                      onChanged: (_) {
                                        setState(() {
                                          _particleSpread =
                                              _spreadFromActionLength(
                                                  actionController
                                                      .text.length);
                                        });
                                        _triggerInputPulse();
                                        if (actionLen == 1) {
                                          HapticFeedback.mediumImpact();
                                        }
                                      },
                                      decoration: _labeledInputDecoration(
                                        label: loc.actionLabel,
                                        hint: loc.actionHint,
                                        currentLength: actionLen,
                                        maxLength: 200,
                                      ),
                                    ),
                                    if (hasContextThoughts) ...[
                                      const SizedBox(height: 14),
                                      _buildContextThoughtSection(loc),
                                    ],
                                    const SizedBox(height: 12),
                                    if (!pinBulkSaveAboveKeyboard)
                                      KeyedSubtree(
                                        key: _saveButtonKey,
                                        child: ElevatedButton(
                                          onPressed: _saveThought,
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 40, vertical: 14),
                                            backgroundColor: Colors.white,
                                            foregroundColor: Colors.black,
                                          ),
                                          child: Text(loc.saveThought),
                                        ),
                                      )
                                    else
                                      const SizedBox(
                                          height: pinnedBulkSaveBarTotalHeight),
                                  ],
                                ),
                              ] else ...[
                                const SizedBox(height: 12),
                                KeyedSubtree(
                                  key: _saveButtonKey,
                                  child: ElevatedButton(
                                    onPressed: _saveThought,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 40, vertical: 14),
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                    ),
                                    child: Text(loc.saveThought),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 24),
                            ],
                          ),
                          ),
                        ),
                      ),
                      if (showFooterAd)
                        ValueListenableBuilder<Box>(
                          valueListenable: Hive.box('settings').listenable(
                            keys: const ['isPremium'],
                          ),
                          builder: (context, _, __) {
                            return Padding(
                              padding: EdgeInsets.only(
                                top: 6,
                                bottom: 8 + bottomSafeInset,
                              ),
                              child: _buildBottomBannerAd(
                                isPremium: AppSettings.isPremium,
                              ),
                            );
                          },
                        )
                      else
                        SizedBox(height: 10 + bottomSafeInset),
                    ],
                  ),
                ),
              ),

            if (!_isSaving && pinBulkSaveAboveKeyboard)
              Positioned(
                left: horizontalPadding,
                right: horizontalPadding,
                bottom: pinnedBulkSaveOuterBottom + keyboardInset,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ResponsiveContentWidth(
                    padding: EdgeInsets.zero,
                    child: KeyedSubtree(
                      key: _saveButtonKey,
                      child: ElevatedButton(
                        onPressed: _saveThought,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 14),
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                        child: Text(loc.saveThought),
                      ),
                    ),
                  ),
                ),
              ),

            // 保存時：中央星が共鳴し、周囲の星へ波紋が伝わって銀河へ還元
            if (_isSaving)
              ConstellationResonanceOverlay(
                animation: _saveAnimController,
                mainStarColor: starColor,
                contextStarColors: _resonanceContextColors(),
              ),
          ],
        ),
      ),
    );
  }
}
