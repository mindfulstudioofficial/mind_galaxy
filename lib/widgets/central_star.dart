import 'package:flutter/material.dart';

class CentralStar extends StatefulWidget {
  final int thoughtCount;
  final bool flash;
  final int revisitCount;

  const CentralStar({
    super.key,
    required this.thoughtCount,
    required this.flash,
    required this.revisitCount,
  });

  @override
  State<CentralStar> createState() => _CentralStarState();
}

class _CentralStarState extends State<CentralStar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // 固定のデザインパラメータ
  double get starSize => 72.0;
  double get auraSize => 180.0; // 四角く見えないよう少しサイズを抑える

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final p = Curves.easeInOut.transform(_pulseController.value);
        final flashBoost = widget.flash ? 1.1 : 1.0;
        
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none, // 🚀 これにより、赤いドットがはみ出しても消えません
          children: [
            // 1. 周囲のオーラ（ここが四角く見えないよう BoxDecoration を徹底）
            Container(
              width: auraSize * flashBoost,
              height: auraSize * flashBoost,
              decoration: BoxDecoration(
                shape: BoxShape.circle, // 🚀 確実に円形にする
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: widget.flash ? 0.3 : 0.15 + p * 0.1),
                    blurRadius: 40 + p * 20,
                    spreadRadius: 2,
                  ),
                  // 最大ティア用の黄金の輝き
                  BoxShadow(
                    color: const Color(0xFFE8C547).withValues(alpha: 0.1 + p * 0.05),
                    blurRadius: 60,
                    spreadRadius: -10,
                  ),
                ],
              ),
            ),

            // 2. 中心星
            Icon(
              Icons.star,
              color: Colors.white.withValues(alpha: widget.flash ? 1.0 : 0.8),
              size: starSize,
            ),

            // 3. 🚀 通知の赤いドット（配置を調整）
            if (widget.revisitCount > 0)
              Positioned(
                top: 10, // 位置を微調整
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2), // 🚀 黒い縁取りで視認性アップ
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      "${widget.revisitCount}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}