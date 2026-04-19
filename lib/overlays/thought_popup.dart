import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/thought.dart';
import '../utils/colors.dart';

class ThoughtPopup {
  static OverlayEntry? _overlayEntry;

  static void show({
    required BuildContext context,
    required Thought thought,
    required VoidCallback onUpdated,
    required VoidCallback onThoughtDeleted,
  }) {
    hide();

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (ctx) {
        return _ThoughtPopupOverlay(
          thought: thought,
          onSaved: () {
            onUpdated();
            hide();
          },
          onDeleted: () {
            onThoughtDeleted();
            hide();
          },
        );
      },
    );

    overlay.insert(_overlayEntry!);
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _ThoughtPopupOverlay extends StatefulWidget {
  final Thought thought;
  final VoidCallback onSaved;
  final VoidCallback onDeleted;

  const _ThoughtPopupOverlay({
    required this.thought,
    required this.onSaved,
    required this.onDeleted,
  });

  @override
  State<_ThoughtPopupOverlay> createState() => _ThoughtPopupOverlayState();
}

class _ThoughtPopupOverlayState extends State<_ThoughtPopupOverlay>
    with TickerProviderStateMixin {
  late final TextEditingController _insightController;
  late final TextEditingController _actionController;

  late final AnimationController _introController;
  late final AnimationController _absorbController;

  late final Animation<double> _introScale;
  late final Animation<double> _introOpacity;

  late final Animation<double> _absorbCurved;
  late final AnimationController _saveBurstController;
  late final Animation<double> _saveBurstScale;

  @override
  void initState() {
    super.initState();
    _insightController = TextEditingController(
      text: widget.thought.insight ?? '',
    );
    _actionController = TextEditingController(
      text: widget.thought.action ?? '',
    );

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _introScale = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic),
    );
    _introOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOut),
    );
    _introController.forward();

    _absorbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _absorbCurved = CurvedAnimation(
      parent: _absorbController,
      curve: Curves.easeInBack,
    );
    _saveBurstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _saveBurstScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.07)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 42,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.07, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 58,
      ),
    ]).animate(_saveBurstController);
  }

  @override
  void dispose() {
    _insightController.dispose();
    _actionController.dispose();
    _introController.dispose();
    _absorbController.dispose();
    _saveBurstController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ins = _insightController.text.trim();
    final act = _actionController.text.trim();
    widget.thought.insight = ins.isEmpty ? null : ins;
    widget.thought.action = act.isEmpty ? null : act;
    // revisitCount が 1(1日後) なら次は 3日後、2(3日後) なら次は 7日後
    if (widget.thought.revisitCount == 1) {
      widget.thought.revisitAt =
          widget.thought.createdAt.add(const Duration(minutes: 1));
      widget.thought.revisitCount = 2;
    } else if (widget.thought.revisitCount == 2) {
      widget.thought.revisitAt =
          widget.thought.createdAt.add(const Duration(days: 7));
      widget.thought.revisitCount = 3;
    } else {
      // 3回目（7日後）が終わったら、自動来訪は卒業
      widget.thought.revisitAt = null;
    }

    // Hiveに保存
    await widget.thought.save();

    HapticFeedback.lightImpact();
    if (!mounted) return;
    widget.onSaved();
  }

  Future<void> _saveWithBurst() async {
    await _saveBurstController.forward(from: 0);
    if (!mounted) return;
    await _save();
  }

  Widget _buildCosmicPanel({
    required Size size,
    required double raw,
  }) {
    final loc = AppLocalizations.of(context)!;
    const panelRadius = BorderRadius.all(Radius.circular(28));

    return SizedBox(
      width: (size.width * 0.9).clamp(300.0, 460.0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: panelRadius,
                  gradient: const RadialGradient(
                    center: Alignment(-0.3, -0.9),
                    radius: 1.15,
                    colors: [
                      Color(0x22376AFF),
                      Color(0x1A102C59),
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xAA061023).withOpacity(0.55),
                      blurRadius: 36,
                      spreadRadius: 1.5,
                    ),
                  ],
                ),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: panelRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                constraints: BoxConstraints(maxHeight: size.height * 0.76),
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
                decoration: BoxDecoration(
                  borderRadius: panelRadius,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xEE0D1325),
                      Color(0xE6121A2E),
                      Color(0xEE080D19),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0x507C93C9),
                    width: 1.0,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  color:
                                      AppColors.textPrimary.withOpacity(0.62),
                                  size: 21,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    widget.thought.content,
                                    style: TextStyle(
                                      color: AppColors.textPrimary
                                          .withOpacity(0.94),
                                      fontSize: 15,
                                      height: 1.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            Text(
                              loc.insightLabel,
                              style: TextStyle(
                                color:
                                    AppColors.textSecondary.withOpacity(0.78),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.35,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _insightController,
                              minLines: 2,
                              maxLines: 8,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              style: TextStyle(
                                color: AppColors.textPrimary.withOpacity(0.96),
                                fontSize: 14,
                                height: 1.5,
                              ),
                              decoration: InputDecoration(
                                hintText: loc.popupInsightHint,
                                hintStyle: TextStyle(
                                  color:
                                      AppColors.textSecondary.withOpacity(0.42),
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 6),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              loc.actionLabel,
                              style: TextStyle(
                                color:
                                    AppColors.textSecondary.withOpacity(0.78),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.35,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _actionController,
                              minLines: 2,
                              maxLines: 8,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              style: TextStyle(
                                color: AppColors.textPrimary.withOpacity(0.96),
                                fontSize: 14,
                                height: 1.5,
                              ),
                              decoration: InputDecoration(
                                hintText: loc.popupActionHint,
                                hintStyle: TextStyle(
                                  color:
                                      AppColors.textSecondary.withOpacity(0.42),
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 6),
                              ),
                            ),
                            const SizedBox(height: 18),
                            ScaleTransition(
                              scale: _saveBurstScale,
                              child: ElevatedButton(
                                onPressed: raw > 0.02 ? null : _saveWithBurst,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF15203A),
                                  foregroundColor: const Color(0xFFEAF0FF),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                    horizontal: 14,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22),
                                    side: const BorderSide(
                                      color: Color(0x4F6B86C4),
                                      width: 1,
                                    ),
                                  ),
                                ).copyWith(
                                  overlayColor:
                                      MaterialStateProperty.resolveWith(
                                    (states) =>
                                        states.contains(MaterialState.pressed)
                                            ? const Color(0x66305087)
                                            : null,
                                  ),
                                  shadowColor: MaterialStatePropertyAll(
                                    const Color(0x99203055).withOpacity(0.38),
                                  ),
                                ),
                                child: Text(
                                  loc.releaseStarToGalaxy,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (raw < 0.02)
                      Positioned(
                        right: 16,
                        top: 10,
                        child: _PopupIconButton(
                          enabled: true,
                          icon: Icons.close,
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            ThoughtPopup.hide();
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: Listenable.merge([_introController, _absorbController]),
      builder: (context, _) {
        final raw = _absorbController.value;
        final t = _absorbCurved.value;

        final spin = t * 18 * math.pi;
        final wobble = math.sin(t * 28 * math.pi) * 0.5 + 0.5;

        var scale = _introScale.value * (1.0 - t);
        if (raw > 0.88) {
          final snap = ((raw - 0.88) / 0.12).clamp(0.0, 1.0);
          scale *= 1.0 - Curves.easeIn.transform(snap);
        }

        final opacity = (_introOpacity.value * (1.0 - t)).clamp(0.0, 1.0);

        final pullY = t * size.height * 0.22;
        final pullX =
            math.sin(t * 22 * math.pi) * 36 * (1.0 - t) + t * size.width * 0.04;
        final sink = Offset(pullX, pullY + wobble * 8 * (1.0 - t));

        final scrimOpacity = (0.32 * _introOpacity.value) * (1.0 - t * 0.85);

        return Material(
          color: Colors.black.withOpacity(scrimOpacity.clamp(0.0, 0.55)),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: raw > 0.02
                      ? null
                      : () {
                          FocusScope.of(context).unfocus();
                          ThoughtPopup.hide();
                        },
                ),
              ),
              Transform.translate(
                offset: sink,
                child: Transform.rotate(
                  angle: spin,
                  child: Transform.scale(
                    scale: scale.clamp(0.0, 2.0),
                    alignment: Alignment.center,
                    child: Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: GestureDetector(
                        onTap: () {},
                        child: _buildCosmicPanel(size: size, raw: raw),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PopupIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool enabled;
  final IconData icon;

  const _PopupIconButton({
    required this.onTap,
    required this.enabled,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.textPrimary.withOpacity(0.08),
            border: Border.all(
              color: AppColors.textPrimary.withOpacity(0.16),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: AppColors.textSecondary.withOpacity(0.95),
            size: 18,
          ),
        ),
      ),
    );
  }
}
