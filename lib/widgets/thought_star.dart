import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/thought.dart';

class ThoughtStar extends StatefulWidget {
  final Thought thought;
  final double x;
  final double y;
  final String content;
  final String insight;
  final String action;
  final String category;

  final Function(String)? onCategoryChanged;
  final Function(Offset)? onPositionChanged;
  final Function(Thought) onTap;
  final VoidCallback onLongPress;

  final bool isDeleting;
  final Offset blackHolePosition; // 🚀 重複を削除し、1つにまとめました
  final Offset revisitPosition;
  final bool isTarget;

  final bool suppressDetailPopup;
  final bool interactionEnabled;
  final VoidCallback? onThoughtPersisted;
  final VoidCallback? onThoughtRemovedFromHive;
  final VoidCallback? onDragEnd; // 🚀 必須(required)ではなく任意(? )として定義

  const ThoughtStar({
    super.key,
    required this.thought,
    required this.x,
    required this.y,
    required this.content,
    required this.insight,
    required this.action,
    required this.category,
    required this.revisitPosition,
    this.onCategoryChanged,
    this.onPositionChanged,
    required this.onTap,
    required this.onLongPress,
    required this.isDeleting,
    required this.blackHolePosition,
    this.suppressDetailPopup = false,
    this.interactionEnabled = true,
    this.onThoughtPersisted,
    this.onThoughtRemovedFromHive,
    this.onDragEnd, // 🚀 コンストラクタに追加
    this.isTarget = false,
  });

  @override
  State<ThoughtStar> createState() => _ThoughtStarState();
}

class _ThoughtStarState extends State<ThoughtStar>
    with TickerProviderStateMixin {
  static const double _dragVisualYOffset = -50.0;
  static const double _dragDeadZone = 14.0;
  static const double _axisSwitchRatio = 1.22;

  late AnimationController _appearController;
  late AnimationController _idleController;

  late Animation<double> _appearScale;
  late Animation<double> _appearOpacity;

  late Animation<double> _pulseAnim;
  late Animation<double> _particleAnim;
  late Animation<Offset> _floatingAnim;
  bool _isDragging = false;

  final Random _random = Random();
  Offset _currentOffset = Offset.zero;
  Offset? _dragStart;
  Offset _dragVector = Offset.zero;
  String? _dragPreviewCategory;

  double getStarSize() {
    return (18.0 * widget.thought.starSize).clamp(14.0, 40.0).toDouble();
  }

  int getStage() {
    if (widget.action.isNotEmpty) return 2;
    if (widget.insight.isNotEmpty) return 1;
    return 0;
  }

  Color getStarColor() {
    final category = _isDragging && _dragPreviewCategory != null
        ? _dragPreviewCategory!
        : widget.thought.category;

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
        return Colors.white;
    }
  }

  double getGlow() {
    final baseGlow = 2.0 + (widget.thought.glowIntensity - 1.0) * 12.0;
    if (getStage() == 2) return baseGlow + 4.0;
    return baseGlow;
  }

  int getParticleCount() {
    if (widget.action.isEmpty) return 0;
    return (6 + ((widget.thought.particleSpread - 1.0) * 10))
        .round()
        .clamp(6, 18);
  }

  double getParticleRadius() {
    return 8.0 + (widget.thought.particleSpread * 10.0);
  }

  @override
  void initState() {
    super.initState();
    _currentOffset = Offset(widget.x, widget.y);

    _appearController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _appearScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _appearController, curve: Curves.easeOutBack),
    );

    _appearOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _appearController, curve: Curves.easeIn),
    );

    _idleController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
    );

    _particleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeOut),
    );

    _floatingAnim = Tween<Offset>(
      begin: Offset(
          (_random.nextDouble() - 0.5) * 10, (_random.nextDouble() - 0.5) * 10),
      end: Offset(
          (_random.nextDouble() - 0.5) * 10, (_random.nextDouble() - 0.5) * 10),
    ).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
    );

    _appearController.forward();
  }

  @override
  void didUpdateWidget(ThoughtStar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging) {
      _currentOffset = Offset(widget.x, widget.y);
    }
  }

  Offset _clampToScreen(Offset offset) {
    final size = MediaQuery.of(context).size;
    const margin = 40.0;
    return Offset(
      offset.dx.clamp(margin, size.width - margin),
      offset.dy.clamp(margin, size.height - margin),
    );
  }

  String _dominantCategoryFromVector(Offset vector) {
    final absX = vector.dx.abs();
    final absY = vector.dy.abs();

    if (absY > absX) {
      return vector.dy <= 0 ? "future" : "past";
    }
    return vector.dx >= 0 ? "action" : "emotion";
  }

  String _resolveDragCategory(Offset vector, String fallbackCategory) {
    final distance = vector.distance;
    if (distance < _dragDeadZone) return fallbackCategory;

    final dominant = _dominantCategoryFromVector(vector);
    if (_dragPreviewCategory == null) return dominant;

    // Keep the current preview unless the new axis is clearly stronger.
    final previewIsVertical = _dragPreviewCategory == "future" ||
        _dragPreviewCategory == "past";
    final dominantIsVertical = dominant == "future" || dominant == "past";
    if (previewIsVertical == dominantIsVertical) return dominant;

    final axisRatio = (vector.dy.abs() + 0.001) / (vector.dx.abs() + 0.001);
    if (dominantIsVertical) {
      return axisRatio >= _axisSwitchRatio ? dominant : _dragPreviewCategory!;
    }
    return (1 / axisRatio) >= _axisSwitchRatio ? dominant : _dragPreviewCategory!;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _currentOffset = _clampToScreen(_currentOffset + details.delta);
      _dragVector += details.delta;
    });

    widget.thought.dx = _currentOffset.dx;
    widget.thought.dy = _currentOffset.dy;
    widget.onPositionChanged?.call(_currentOffset);

    if (_isDragging && (_dragVector.dx != 0 || _dragVector.dy != 0)) {
      final preview = _resolveDragCategory(
        _dragVector,
        widget.thought.category,
      );
      if (_dragPreviewCategory != preview) {
        setState(() {
          _dragPreviewCategory = preview;
        });
      }
    }
  }

  Future<void> _handleDragEnd() async {
    if (_dragStart == null) return;

    final syncedCategory = _dragPreviewCategory ?? widget.category;
    final syncedX = _currentOffset.dx;
    final syncedY = _currentOffset.dy;

    widget.thought.category = syncedCategory;
    widget.thought.dx = syncedX;
    widget.thought.dy = syncedY;

    if (syncedCategory != widget.category) {
      widget.onCategoryChanged?.call(syncedCategory);
      HapticFeedback.lightImpact();
    }

    if (widget.thought.isInBox) {
      await widget.thought.save();
      widget.onThoughtPersisted?.call();
    }

    widget.onDragEnd?.call();

    setState(() {
      _isDragging = false; // 🚀 ここを確実に更新
      _dragPreviewCategory = null; // プレビューを消す
      _dragStart = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final starSize = getStarSize();
    final hitSize = starSize + 50;

    return AnimatedBuilder(
      animation: Listenable.merge([_appearController, _idleController]),
      builder: (context, child) {
        Offset offset;
        if (_isDragging) {
          // Keep the dragged star slightly above the fingertip.
          offset = _currentOffset.translate(0, _dragVisualYOffset);
        } else if (widget.isDeleting) {
          offset = Offset.lerp(_currentOffset, widget.blackHolePosition,
              _appearController.value)!;
        } else if (widget.isTarget &&
            !_isDragging &&
            (_currentOffset == widget.revisitPosition)) {
          // 🚀 修正：一度も動かしていない（初期位置が中央）場合のみ、中央に固定する
          offset = widget.revisitPosition;
        } else {
          // 🚀 ドラッグ後の位置、または浮遊アニメーションを適用
          offset = _currentOffset + _floatingAnim.value;
        }
        // スケール（大きさ）の計算はそのまま
        final scale =
            _appearScale.value * (getStage() == 2 ? _pulseAnim.value : 1.0);
        final particleCount = getParticleCount();
        final particleRadius = getParticleRadius() + (_particleAnim.value * 10);

        return Positioned(
          left: offset.dx - hitSize / 2,
          top: offset.dy - hitSize / 2,
          child: Opacity(
            opacity:
                (widget.isTarget ? 0.8 : _appearOpacity.value).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: widget.interactionEnabled
                    ? () => widget.onTap(widget.thought)
                    : null,
                onLongPress: widget.interactionEnabled ? widget.onLongPress : null,
                onPanStart: widget.interactionEnabled
                    ? (details) {
                  setState(() {
                    _isDragging = true;
                    // 🚀 現在の星の表示位置をドラッグの開始位置として確定させる
                    if (widget.isTarget &&
                        _currentOffset == widget.revisitPosition) {
                      _currentOffset = widget.revisitPosition;
                    } else {
                      _currentOffset =
                          Offset(widget.thought.dx, widget.thought.dy);
                    }

                    // 🚀 指が触れた「星の中の相対的な位置」を記録（これがズレ防止の鍵です）
                    _dragStart = details.localPosition;
                    _dragVector = Offset.zero;
                    _dragPreviewCategory = widget.thought.category;
                  });
                }
                    : null,

                // 🚀 外側のメソッドを呼び出すように変更します
                onPanUpdate:
                    widget.interactionEnabled ? (details) => _handleDragUpdate(details) : null,
                onPanEnd: widget.interactionEnabled ? (_) => _handleDragEnd() : null,
                child: SizedBox(
                  width: hitSize,
                  height: hitSize,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: getStarColor().withValues(alpha: 0.7),
                            blurRadius: getGlow(),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.star,
                              color: getStarColor(), size: starSize),
                          if (particleCount > 0)
                            ...List.generate(particleCount, (i) {
                              final angle = (i / particleCount) * 2 * pi;
                              final radius = particleRadius;
                              return Transform.translate(
                                offset: Offset(
                                    cos(angle) * radius, sin(angle) * radius),
                                child: Opacity(
                                  opacity: 1 - _particleAnim.value,
                                  child: Icon(
                                    Icons.circle,
                                    size: 2 +
                                        (widget.thought.particleSpread - 1.0),
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _appearController.dispose();
    _idleController.dispose();
    super.dispose();
  }
}
