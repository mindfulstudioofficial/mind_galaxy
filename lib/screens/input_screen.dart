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
import '../utils/responsive_layout.dart';

class InputScreen extends StatefulWidget {
  final String? initialContent;
  final String? initialInsight;
  final String? initialAction;
  final double? initialStarSize;
  final double? initialGlowIntensity;
  final double? initialParticleSpread;
  final Thought? thoughtToEdit;
  final bool forceBulkMode;
  final bool focusFollowupOnOpen;

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
  });

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen>
    with TickerProviderStateMixin {
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

  bool isBulkMode = false;

  // ⭐ 保存時のアニメーション（吸い込み）
  late AnimationController _saveAnimController;
  late Animation<double> _saveScaleAnim;
  late Animation<double> _saveOpacityAnim;
  late Animation<Offset> _saveMoveAnim;

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
  final Random _random = Random();
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

    // --- 保存時のアニメーション設定 ---
    _saveAnimController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _saveScaleAnim = Tween(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _saveAnimController, curve: Curves.easeIn),
    );
    _saveOpacityAnim = Tween(begin: 1.0, end: 0.0).animate(_saveAnimController);
    _saveMoveAnim = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -200),
    ).animate(
        CurvedAnimation(parent: _saveAnimController, curve: Curves.easeIn));

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
      Navigator.of(context).popUntil((route) => route.isFirst);
    } finally {
      _isNavigatingAway = false;
    }
  }

  Future<void> _toggleInputMode() async {
    if (_isModeToggleLocked) return;
    _isModeToggleLocked = true;
    if (mounted) {
      setState(() => isBulkMode = !isBulkMode);
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

  // --- 保存処理 ---
  Future<void> _saveThought() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSaving = true);
    HapticFeedback.heavyImpact(); // 保存時は強く
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
      thought.revisitAt = DateTime.now().add(const Duration(days: 1));
      if (thought.isInBox) {
        await thought.save();
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
    if (_bannerAd == null && !_hasBannerAdError) {
      _loadBannerAd();
    }
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
    final showFooterAd =
        !keyboardVisible && !AppSettings.isPremium && kShowAds;
    // キーボード時は末尾（行動枠・保存）までスクロールできる余白を確保
    final formBottomPadding = keyboardVisible
        ? (32.0 +
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
    if (isBulkMode) {
      if (keyboardVisible) {
        // キーボード時: シンプル入力ボタン行の直下に星、その直下へ入力3枠
        bulkStarBandTop = viewPadding.top + headerBlockHeight;
        bulkStarBandHeight = isTablet ? 48.0 : 36.0;
        formTopGap = bulkStarBandHeight + 6.0;
      } else {
        const bulkLayoutLift = 16.0;
        bulkStarBandTop = viewPadding.top + headerBlockHeight - bulkLayoutLift;
        bulkStarBandHeight = isTablet ? 210.0 : 200.0;
        formTopGap = bulkStarBandHeight +
            (isTablet ? 16.0 : 12.0) -
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
    final starLayoutSize = keyboardVisible
        ? (isBulkMode
            ? (isTablet ? 36.0 : 30.0)
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
        ? const EdgeInsets.fromLTRB(0, 64, 0, 24)
        : fieldScrollPadding;

    /// まとめ入力＋キーボード時は保存を画面下に固定し、キーボード直上で常にタップ可能にする。
    final bool pinBulkSaveAboveKeyboard = keyboardVisible && isBulkMode;
    final double pinnedBulkSaveOuterBottom =
        (8 + MediaQuery.paddingOf(context).bottom).clamp(8.0, 64.0);
    const double pinnedBulkSaveBarTotalHeight = 84.0;

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
        resizeToAvoidBottomInset: true, // キーボード表示時にリサイズ
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
                  final pulseBoost = _inputPulseAnim.value;
                  final hasGlow = insightLen > 0;
                  final pulseT = (_inputPulseController.value).clamp(0.0, 1.0);
                  final boostedStarColor = Color.lerp(
                          starColor, Colors.amberAccent, pulseT * 0.55) ??
                      starColor;
                  // キーボード表示中のまとめ入力は星が小さくても外側グローが見えるよう別係数
                  final bulkKeyboardGlow = isBulkMode && keyboardVisible;
                  final glowScale = bulkKeyboardGlow
                      ? 1.0
                      : (isBulkMode
                          ? (starLayoutSize / starAreaSize).clamp(0.5, 1.0)
                          : 1.0);
                  final keyboardGlowBoost = bulkKeyboardGlow ? 1.42 : 1.0;
                  var dynamicGlow = hasGlow
                      ? glowRadius *
                          _pulseAnim.value *
                          glowScale *
                          keyboardGlowBoost
                      : 0.0;
                  if (hasGlow && bulkKeyboardGlow) {
                    dynamicGlow = dynamicGlow.clamp(22.0, 72.0);
                  }

                  final whiteGlowAlpha =
                      bulkKeyboardGlow ? 0.42 + pulseT * 0.18 : 0.28 + pulseT * 0.14;
                  final cyanGlowAlpha =
                      bulkKeyboardGlow ? 0.28 + pulseT * 0.18 : 0.16 + pulseT * 0.14;
                  final whiteBlurMul = bulkKeyboardGlow ? 1.55 : 1.2;
                  final cyanBlurMul = bulkKeyboardGlow ? 1.15 : 0.75;
                  final whiteSpreadMul = bulkKeyboardGlow ? 3.4 : 2.4;
                  final cyanSpreadMul = bulkKeyboardGlow ? 1.35 : 0.95;

                  final starVisual = AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: starLayoutSize,
                    height: starLayoutSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: hasGlow
                          ? [
                              BoxShadow(
                                color: Colors.white
                                    .withValues(alpha: whiteGlowAlpha),
                                blurRadius: dynamicGlow * whiteBlurMul,
                                spreadRadius: (_glowIntensity - 1.0) *
                                    whiteSpreadMul *
                                    glowScale,
                              ),
                              BoxShadow(
                                color: Colors.cyanAccent
                                    .withValues(alpha: cyanGlowAlpha),
                                blurRadius: dynamicGlow * cyanBlurMul,
                                spreadRadius: (_glowIntensity - 1.0) *
                                    cyanSpreadMul *
                                    glowScale,
                              ),
                              if (bulkKeyboardGlow)
                                BoxShadow(
                                  color: Colors.cyanAccent
                                      .withValues(alpha: 0.12 + pulseT * 0.1),
                                  blurRadius: dynamicGlow * 1.35,
                                  spreadRadius:
                                      (_glowIntensity - 1.0) * 1.1,
                                ),
                            ]
                          : const [],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(end: starSize * pulseBoost),
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
                        if (particleCount > 0)
                          ...List.generate(particleCount, (i) {
                            final angle = (i / particleCount) * 2 * pi;
                            final currentRadius =
                                particleRadius * _pulseAnim.value;
                            final noiseX = (_random.nextDouble() - 0.5) * 3;
                            final noiseY = (_random.nextDouble() - 0.5) * 3;

                            return Transform.translate(
                              offset: Offset(
                                cos(angle) * currentRadius + noiseX,
                                sin(angle) * currentRadius + noiseY,
                              ),
                              child: Opacity(
                                opacity: (_particleOpacityAnim.value * 1.25).clamp(0.0, 1.0),
                                child: Icon(
                                  Icons.circle,
                                  size: 1.6 + (_particleSpread - 1.0) * 3.6,
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
                        alignment: keyboardVisible && isBulkMode
                            ? Alignment.topCenter
                            : Alignment.center,
                        child: starVisual,
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
                                tooltip: 'Home',
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
                                autofocus: !isBulkMode, // シンプル入力時はオートフォーカス
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
                                decoration: InputDecoration(
                                  hintText: loc.inputHint,
                                  hintMaxLines: 2,
                                  hintStyle: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 15,
                                    height: 1.25,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white10,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  counter: _buildUnifiedCounter(
                                    context,
                                    currentLength: contentLen,
                                    maxLength: 200,
                                  ),
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
                                    decoration: InputDecoration(
                                    hintText: loc.insightHint,
                                    hintStyle:
                                        const TextStyle(color: Colors.white30),
                                    filled: true,
                                    fillColor:
                                        Colors.white.withValues(alpha: 0.05),
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    counter: _buildUnifiedCounter(
                                      context,
                                      currentLength: insightLen,
                                      maxLength: 200,
                                    ),
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
                                      decoration: InputDecoration(
                                        hintText: loc.actionHint,
                                        hintStyle: const TextStyle(
                                            color: Colors.white38),
                                        filled: true,
                                        fillColor: Colors.white
                                            .withValues(alpha: 0.05),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(14)),
                                        counter: _buildUnifiedCounter(
                                          context,
                                          currentLength: actionLen,
                                          maxLength: 200,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    if (!pinBulkSaveAboveKeyboard)
                                      ElevatedButton(
                                        onPressed: _saveThought,
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 40, vertical: 14),
                                          backgroundColor: Colors.white,
                                          foregroundColor: Colors.black,
                                        ),
                                        child: Text(loc.saveThought),
                                      )
                                    else
                                      const SizedBox(
                                          height: pinnedBulkSaveBarTotalHeight),
                                  ],
                                ),
                              ] else ...[
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: _saveThought,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 40, vertical: 14),
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                  ),
                                  child: Text(loc.saveThought),
                                ),
                              ],

                              const SizedBox(height: 24),
                            ],
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
                bottom: pinnedBulkSaveOuterBottom,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ResponsiveContentWidth(
                    padding: EdgeInsets.zero,
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

            // ===============================================
            // ⭐ 保存時の吸い込みアニメーション（そのまま残す）
            // ===============================================
            if (_isSaving)
              Center(
                child: AnimatedBuilder(
                  animation: _saveAnimController,
                  builder: (_, __) {
                    return Transform.translate(
                      offset: _saveMoveAnim.value,
                      child: Transform.scale(
                        scale: _saveScaleAnim.value,
                        child: Opacity(
                          opacity: _saveOpacityAnim.value,
                          child: const Icon(Icons.star,
                              color: Colors.white, size: 40),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
