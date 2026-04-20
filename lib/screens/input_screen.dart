import 'dart:math'; // 🚀 【追加】粒子の計算用
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // ← 追加
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/ads_config.dart';
import '../models/thought.dart';
import '../services/app_settings.dart';
import '../utils/ad_helper.dart';

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
    return (1.0 + (length.clamp(0, 120) / 120) * 2.8)
        .clamp(1.0, 3.8)
        .toDouble();
  }

  // ⭐ 粒子の数：行動が書かれた時だけ、粒子を放つ
  int _calculateParticleCount() {
    if (actionLen == 0) return 0;
    return (8 + ((_particleSpread - 1.0) * 16)).round().clamp(8, 28);
  }

  double _spreadFromActionLength(int length) {
    return (1.0 + (length.clamp(0, 120) / 120) * 3.2)
        .clamp(1.0, 4.2)
        .toDouble();
  }

  // ⭐ 粒子の飛び散る半径（行動入力でのみ成長）
  double _calculateParticleRadius() {
    return 10.0 + (_particleSpread * 18.0);
  }

  void _triggerInputPulse() {
    _inputPulseController.forward(from: 0).then((_) {
      if (mounted) {
        _inputPulseController.reverse();
      }
    });
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
      color = Colors.redAccent.withOpacity(0.9);
    } else if (remaining <= 20) {
      color = Colors.orangeAccent.withOpacity(0.9);
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
      await thought.save();
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
    final bottomSafeInset = MediaQuery.of(context).viewPadding.bottom;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final fixedStarTop = isBulkMode
        ? (keyboardVisible ? 6.0 : 14.0)
        : (keyboardVisible ? 38.0 : 46.0);

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true, // キーボード表示時にリサイズ
      body: Stack(
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
                final dynamicGlow =
                    hasGlow ? glowRadius * _pulseAnim.value : 0.0;
                final pulseT = (_inputPulseController.value).clamp(0.0, 1.0);
                final boostedStarColor =
                    Color.lerp(starColor, Colors.amberAccent, pulseT * 0.55) ??
                        starColor;

                return Positioned(
                  left: 0,
                  right: 0,
                  top: fixedStarTop,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 200, // 粒子も含めた計算領域
                    height: 200,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: hasGlow
                          ? [
                              BoxShadow(
                                color: Colors.white
                                    .withOpacity(0.16 + pulseT * 0.08),
                                blurRadius: dynamicGlow * 0.9,
                                spreadRadius: (_glowIntensity - 1.0) * 1.6,
                              ),
                              BoxShadow(
                                color: Colors.cyanAccent
                                    .withOpacity(0.08 + pulseT * 0.08),
                                blurRadius: dynamicGlow * 0.45,
                                spreadRadius: (_glowIntensity - 1.0) * 0.5,
                              ),
                            ]
                          : const [],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 中央の星（STEP1: サイズのみ変化）
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(end: starSize * pulseBoost),
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          builder: (context, animatedSize, _) {
                            return Icon(
                              Icons.star,
                              color: boostedStarColor,
                              size: animatedSize,
                            );
                          },
                        ),

                        // STEP3: 粒子のみ強化（背景は暗いまま）
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
                                opacity: _particleOpacityAnim.value,
                                child: Icon(
                                  Icons.circle,
                                  size: 1.2 + (_particleSpread - 1.0) * 2.6,
                                  color: boostedStarColor,
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(
                          bottom: 24 + bottomSafeInset + 8,
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      setState(() => isBulkMode = !isBulkMode),
                                  child: Text(
                                    isBulkMode ? loc.simpleMode : loc.bulkMode,
                                    style:
                                        const TextStyle(color: Colors.white70),
                                  ),
                                ),
                              ],
                            ),

                            // モードに応じて上部余白を調整（星の位置に合わせる）
                            SizedBox(height: isBulkMode ? 28 : 170),

                            // メイン思考入力
                            TextField(
                              controller: _controller,
                              maxLength: 200,
                              minLines: 1,
                              maxLines: 3,
                              autofocus: !isBulkMode, // シンプル入力時はオートフォーカス
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
                            const SizedBox(height: 16),

                            // まとめ入力フィールド
                            if (isBulkMode) ...[
                              TextField(
                                controller: insightController,
                                focusNode: _insightFocusNode,
                                maxLength: 200,
                                maxLines: 2,
                                style: const TextStyle(color: Colors.white),
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
                                  fillColor: Colors.white.withOpacity(0.05),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  counter: _buildUnifiedCounter(
                                    context,
                                    currentLength: insightLen,
                                    maxLength: 200,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: actionController,
                                focusNode: _actionFocusNode,
                                maxLength: 200,
                                maxLines: 2,
                                style: const TextStyle(color: Colors.white),
                                onChanged: (_) {
                                  setState(() {
                                    _particleSpread = _spreadFromActionLength(
                                        actionController.text.length);
                                  });
                                  _triggerInputPulse();
                                  if (actionLen == 1) {
                                    HapticFeedback
                                        .mediumImpact(); // 行動の書き始めは少し強く
                                  }
                                },
                                decoration: InputDecoration(
                                  hintText: loc.actionHint,
                                  hintStyle:
                                      const TextStyle(color: Colors.white38),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.05),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  counter: _buildUnifiedCounter(
                                    context,
                                    currentLength: actionLen,
                                    maxLength: 200,
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 30),
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
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                    ValueListenableBuilder<Box>(
                      valueListenable: Hive.box('settings').listenable(
                        keys: const ['isPremium'],
                      ),
                      builder: (context, _, __) {
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: 8 + bottomSafeInset,
                          ),
                          child: _buildBottomBannerAd(
                            isPremium: AppSettings.isPremium,
                          ),
                        );
                      },
                    ),
                  ],
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
    );
  }
}
