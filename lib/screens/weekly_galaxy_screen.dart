import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../models/thought.dart';
import '../utils/web_image_download.dart';

class WeeklyGalaxyScreen extends StatefulWidget {
  const WeeklyGalaxyScreen({super.key});

  @override
  State<WeeklyGalaxyScreen> createState() => _WeeklyGalaxyScreenState();
}

class _WeeklyGalaxyScreenState extends State<WeeklyGalaxyScreen> {
  static const Color _statsEmerald = Color(0xFF50E3C2);
  final List<Thought> _weekThoughts = <Thought>[];
  final ScreenshotController _screenshotController = ScreenshotController();
  int? _selectedThoughtId;
  Offset? _selectedPosition;
  bool _isSharingImage = false;

  static const List<String> _layerOrder = <String>[
    'future',
    'emotion',
    'action',
    'past',
    'neutral',
  ];

  @override
  void initState() {
    super.initState();
    _loadWeekThoughts();
  }

  DateTime _startOfWeek(DateTime base) {
    final dayStart = DateTime(base.year, base.month, base.day);
    return dayStart
        .subtract(Duration(days: dayStart.weekday - DateTime.monday));
  }

  bool _isFilled(String? value) => value != null && value.trim().isNotEmpty;

  Color _colorForCategory(String category) {
    switch (category) {
      case 'future':
        return const Color(0xFF5CA8FF);
      case 'emotion':
        return const Color(0xFFFF79CC);
      case 'action':
        return const Color(0xFFFFE066);
      case 'past':
        return const Color(0xFFC184FF);
      default:
        return Colors.white;
    }
  }

  String _categoryLabel(String category) {
    final loc = AppLocalizations.of(context)!;
    switch (category) {
      case 'future':
        return loc.categoryFuture;
      case 'emotion':
        return loc.categoryEmotion;
      case 'action':
        return loc.categoryAction;
      case 'past':
        return loc.categoryPast;
      default:
        return loc.categoryUncategorized;
    }
  }

  String _classifyThought(Thought thought) {
    final normalized = thought.category.toLowerCase().trim();
    if (_layerOrder.contains(normalized)) return normalized;

    // Fallback is language-agnostic: infer from filled fields only.
    if (_isFilled(thought.action)) return 'action';
    if (_isFilled(thought.insight)) return 'emotion';
    return 'neutral';
  }

  void _loadWeekThoughts() {
    final box = Hive.box<Thought>('thoughts');
    final now = DateTime.now();
    final weekStart = _startOfWeek(now);
    final weekEnd = weekStart.add(const Duration(days: 7));

    final thoughts = box.values
        .where((t) =>
            !t.isArchived &&
            !t.createdAt.isBefore(weekStart) &&
            t.createdAt.isBefore(weekEnd))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    setState(() {
      _weekThoughts
        ..clear()
        ..addAll(thoughts);
    });
  }

  Future<void> _shareWeeklyGalaxy() async {
    final loc = AppLocalizations.of(context)!;
    if (_isSharingImage) return;

    setState(() => _isSharingImage = true);
    HapticFeedback.selectionClick();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          kIsWeb
              ? loc.generatingWeeklyImageForDownload
              : loc.generatingWeeklyImageForShare,
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xCC000000),
      ),
    );

    try {
      if (kIsWeb) {
        final imageBytes = await _screenshotController.capture(
          delay: const Duration(milliseconds: 80),
          pixelRatio: 2.0,
        );
        if (!mounted || imageBytes == null) return;
        await downloadImageOnWeb(
          imageBytes,
          fileName: 'mindgalaxy_weekly_galaxy.png',
        );
      } else {
        final tempDir = await getTemporaryDirectory();
        final fileName =
            'mindgalaxy_weekly_${DateTime.now().millisecondsSinceEpoch}.png';
        final imagePath = await _screenshotController.captureAndSave(
          tempDir.path,
          fileName: fileName,
          delay: const Duration(milliseconds: 80),
          pixelRatio: 2.0,
        );
        if (!mounted || imagePath == null) return;
        await Share.shareXFiles(
          [XFile(imagePath)],
          text: loc.shareWeeklyGalaxyText,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharingImage = false);
      }
    }
  }

  String _previewText(Thought thought) {
    final loc = AppLocalizations.of(context)!;
    final dt = thought.createdAt;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final insight = _isFilled(thought.insight) ? loc.insightShort : '-';
    final action = _isFilled(thought.action) ? loc.actionShort : '-';
    return "${loc.thoughtLabel}\n"
        "${loc.createdAtLabel} ${dt.month}/${dt.day} $hh:$mm\n"
        "$insight / $action";
  }

  _WeeklySummary _buildWeeklySummary() {
    final counts = <String, int>{for (final c in _layerOrder) c: 0};
    var insightCount = 0;
    var actionCount = 0;
    for (final thought in _weekThoughts) {
      final c = _classifyThought(thought);
      counts[c] = (counts[c] ?? 0) + 1;
      if (_isFilled(thought.insight)) insightCount++;
      if (_isFilled(thought.action)) actionCount++;
    }
    return _WeeklySummary(
      totalThoughts: _weekThoughts.length,
      countsByCategory: counts,
      insightCount: insightCount,
      actionCount: actionCount,
    );
  }

  int _weeklyDensityPercent(int totalThoughts) {
    const targetThoughtsPerWeek = 28;
    return ((totalThoughts / targetThoughtsPerWeek) * 100)
        .clamp(0, 100)
        .round();
  }

  Widget _buildDensityWidget(_WeeklySummary summary, {required bool compact}) {
    final densityPercent = _weeklyDensityPercent(summary.totalThoughts);
    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 6 : 8,
        compact ? 6 : 8,
        compact ? 6 : 8,
        compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF101624), Color(0xFF151E30), Color(0xFF0E1522)],
        ),
        border: Border.all(color: _statsEmerald.withOpacity(0.38), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: _statsEmerald.withOpacity(0.12),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CardStarDustPainter(
                  color: _statsEmerald.withOpacity(0.22),
                  seed: summary.totalThoughts + 21,
                ),
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: Align(
                  alignment: const Alignment(0, -0.16),
                  child: Transform.scale(
                    scale: compact ? 1.45 : 1.72,
                    child: SizedBox(
                      height: compact ? 82 : 118,
                      width: compact ? 82 : 118,
                      child: _WeeklyDensityOrb(
                        count: summary.totalThoughts,
                        color: _statsEmerald,
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                AppLocalizations.of(context)!.weeklyDensity,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: compact ? 9 : 11,
                  letterSpacing: 2.4,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '$densityPercent%',
                style: TextStyle(
                  color: _statsEmerald.withOpacity(0.78),
                  fontSize: compact ? 12 : 14,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatConstellation({
    required int count,
    required String label,
    required bool particleMode,
    required bool compact,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 6 : 8,
        compact ? 6 : 8,
        compact ? 6 : 8,
        compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF101624), Color(0xFF172336), Color(0xFF0E1522)],
        ),
        border: Border.all(color: _statsEmerald.withOpacity(0.45), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: _statsEmerald.withOpacity(0.14),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CardStarDustPainter(
                  color: _statsEmerald.withOpacity(0.24),
                  seed: count + (particleMode ? 91 : 47),
                ),
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: Align(
                  alignment: const Alignment(0, -0.1),
                  child: Transform.scale(
                    scale: compact ? 1.45 : 1.62,
                    child: CustomPaint(
                      painter: _StatConstellationPainter(
                        count: count,
                        color: _statsEmerald,
                        particleMode: particleMode,
                      ),
                      child: SizedBox(
                        width: compact ? 108 : 132,
                        height: compact ? 82 : 106,
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: compact ? 9 : 11,
                  letterSpacing: 2.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context)!.starsCount(count),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _statsEmerald.withOpacity(0.62),
                  fontSize: compact ? 8 : 9,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportArea(_WeeklySummary summary, double height) {
    final compact = height < 220;
    final loc = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF090E19),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.12), width: 0.8),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 8 : 12,
          compact ? 8 : 10,
          compact ? 8 : 12,
          compact ? 8 : 10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.weeklyAnalysis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.78),
                fontSize: compact ? 10 : 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 2.4,
              ),
            ),
            SizedBox(height: compact ? 6 : 8),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _buildDensityWidget(summary, compact: compact),
                  ),
                  SizedBox(width: compact ? 6 : 10),
                  Expanded(
                    child: _buildStatConstellation(
                      count: summary.insightCount,
                      label: loc.weeklyInsightsLabel,
                      particleMode: false,
                      compact: compact,
                    ),
                  ),
                  SizedBox(width: compact ? 6 : 10),
                  Expanded(
                    child: _buildStatConstellation(
                      count: summary.actionCount,
                      label: loc.weeklyActionsLabel,
                      particleMode: true,
                      compact: compact,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final summary = _buildWeeklySummary();

    return Scaffold(
      backgroundColor: const Color(0xFF04060D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          loc.weeklyGalaxyTitle,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            letterSpacing: 2.4,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: _isSharingImage ? null : _shareWeeklyGalaxy,
            tooltip: loc.shareWeeklyGalaxyTooltip,
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: loc.close,
          ),
        ],
      ),
      body: Screenshot(
        controller: _screenshotController,
        child: DefaultTextStyle.merge(
          style: const TextStyle(letterSpacing: 2.4),
          child: LayoutBuilder(
            builder: (context, viewport) {
              final totalHeight = viewport.maxHeight;
              final maxTop = max(220.0, totalHeight - 120.0);
              final topHeight = (totalHeight * 0.65).clamp(220.0, maxTop);
              final bottomHeight = totalHeight - topHeight;
              return Column(
                children: [
                  SizedBox(
                    height: topHeight,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final layout = _WeeklyGalaxyLayout.build(
                          thoughts: _weekThoughts,
                          categoryResolver: _classifyThought,
                          layerOrder: _layerOrder,
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          colorForCategory: _colorForCategory,
                        );
                        _PlottedStar? selected;
                        if (_selectedThoughtId != null) {
                          for (final star in layout.stars) {
                            if (star.thought.id == _selectedThoughtId) {
                              selected = star;
                              break;
                            }
                          }
                        }

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (details) {
                            final tap = details.localPosition;
                            _PlottedStar? hit;
                            var nearest = 28.0;
                            for (final star in layout.stars) {
                              final d = (star.position - tap).distance;
                              if (d <= nearest) {
                                nearest = d;
                                hit = star;
                              }
                            }
                            setState(() {
                              _selectedThoughtId = hit?.thought.id;
                              _selectedPosition = hit?.position;
                            });
                          },
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _WeeklyGalaxyPainter(layout: layout),
                                ),
                              ),
                              Positioned(
                                left: 12,
                                right: 12,
                                top: 12,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: List<Widget>.generate(
                                    7,
                                    (index) => Text(
                                      const [
                                        'Mon',
                                        'Tue',
                                        'Wed',
                                        'Thu',
                                        'Fri',
                                        'Sat',
                                        'Sun'
                                      ][index],
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.45),
                                        fontSize: 10,
                                        letterSpacing: 2.4,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              ...layout.layerY.entries.map((entry) {
                                final categoryCount =
                                    summary.countsByCategory[entry.key] ?? 0;
                                return Positioned(
                                  left: 10,
                                  top: entry.value - 14,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _categoryLabel(entry.key),
                                        style: TextStyle(
                                          color: _colorForCategory(entry.key)
                                              .withOpacity(0.72),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w300,
                                          letterSpacing: 2.4,
                                        ),
                                      ),
                                      Text(
                                        loc.starsCount(categoryCount),
                                        style: TextStyle(
                                          color: _colorForCategory(entry.key)
                                              .withOpacity(0.52),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w300,
                                          letterSpacing: 2.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              Positioned(
                                left: (_selectedPosition?.dx ?? 8)
                                    .clamp(8.0, constraints.maxWidth - 170.0),
                                top: ((_selectedPosition?.dy ?? 64) - 56)
                                    .clamp(8.0, constraints.maxHeight - 90.0),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 240),
                                  transitionBuilder: (child, animation) =>
                                      FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                  child: (selected == null ||
                                          _selectedPosition == null)
                                      ? const SizedBox.shrink(
                                          key: ValueKey('empty-preview'))
                                      : Container(
                                          key: ValueKey<int>(
                                              selected.thought.id),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 8),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.black.withOpacity(0.42),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.white
                                                  .withOpacity(0.18),
                                              width: 0.7,
                                            ),
                                          ),
                                          child: Text(
                                            _previewText(selected.thought),
                                            style: const TextStyle(
                                              color: Color(0xFFE9EEF9),
                                              fontSize: 11,
                                              height: 1.25,
                                              letterSpacing: 2.4,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              if (_weekThoughts.isEmpty)
                                Center(
                                  child: Text(
                                    loc.noThoughtsThisWeek,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.45),
                                      fontSize: 13,
                                      letterSpacing: 2.4,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    height: bottomHeight,
                    child: _buildReportArea(summary, bottomHeight),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WeeklySummary {
  final int totalThoughts;
  final Map<String, int> countsByCategory;
  final int insightCount;
  final int actionCount;

  const _WeeklySummary({
    required this.totalThoughts,
    required this.countsByCategory,
    required this.insightCount,
    required this.actionCount,
  });
}

class _WeeklyGalaxyLayout {
  final List<_PlottedStar> stars;
  final Map<String, List<_PlottedStar>> grouped;
  final Map<String, double> layerY;

  const _WeeklyGalaxyLayout({
    required this.stars,
    required this.grouped,
    required this.layerY,
  });

  static _WeeklyGalaxyLayout build({
    required List<Thought> thoughts,
    required String Function(Thought) categoryResolver,
    required List<String> layerOrder,
    required double width,
    required double height,
    required Color Function(String) colorForCategory,
  }) {
    const topPad = 44.0;
    const bottomPad = 28.0;
    final usableHeight = max(1.0, height - topPad - bottomPad);
    final yMap = <String, double>{};
    for (var i = 0; i < layerOrder.length; i++) {
      final ratio = layerOrder.length == 1 ? 0.5 : i / (layerOrder.length - 1);
      yMap[layerOrder[i]] = topPad + usableHeight * ratio;
    }

    final plotted = <_PlottedStar>[];
    for (final thought in thoughts) {
      final category = categoryResolver(thought);
      final dayOffset = thought.createdAt.weekday - DateTime.monday;
      final minutes = thought.createdAt.hour * 60 + thought.createdAt.minute;
      final xRatio = ((dayOffset + (minutes / 1440)).clamp(0.0, 6.9999)) / 7.0;
      final x = 16 + (width - 32) * xRatio;
      final baseline = yMap[category] ?? (topPad + usableHeight * 0.5);
      final jitter = ((thought.id % 7) - 3) * 2.2;
      final y = baseline + jitter;

      plotted.add(
        _PlottedStar(
          thought: thought,
          category: category,
          color: colorForCategory(category),
          position: Offset(x, y),
          hasInsight:
              thought.insight != null && thought.insight!.trim().isNotEmpty,
          hasAction:
              thought.action != null && thought.action!.trim().isNotEmpty,
        ),
      );
    }

    final grouped = <String, List<_PlottedStar>>{
      for (final c in layerOrder) c: <_PlottedStar>[],
    };
    for (final star in plotted) {
      grouped.putIfAbsent(star.category, () => <_PlottedStar>[]).add(star);
    }
    for (final group in grouped.values) {
      group.sort((a, b) => a.thought.createdAt.compareTo(b.thought.createdAt));
    }

    return _WeeklyGalaxyLayout(stars: plotted, grouped: grouped, layerY: yMap);
  }
}

class _PlottedStar {
  final Thought thought;
  final String category;
  final Color color;
  final Offset position;
  final bool hasInsight;
  final bool hasAction;

  const _PlottedStar({
    required this.thought,
    required this.category,
    required this.color,
    required this.position,
    required this.hasInsight,
    required this.hasAction,
  });
}

class _WeeklyGalaxyPainter extends CustomPainter {
  final _WeeklyGalaxyLayout layout;

  const _WeeklyGalaxyPainter({
    required this.layout,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackdrop(canvas, size);
    _drawConstellations(canvas);
    _drawStars(canvas);
  }

  void _drawBackdrop(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF050A18),
          Color(0xFF080D1B),
          Color(0xFF03050B),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bg);
  }

  void _drawConstellations(Canvas canvas) {
    for (final entry in layout.grouped.entries) {
      final stars = entry.value;
      if (stars.length < 2) continue;

      final path = Path()
        ..moveTo(stars.first.position.dx, stars.first.position.dy);
      for (var i = 1; i < stars.length - 1; i++) {
        final current = stars[i].position;
        final next = stars[i + 1].position;
        final mid =
            Offset((current.dx + next.dx) * 0.5, (current.dy + next.dy) * 0.5);
        path.quadraticBezierTo(current.dx, current.dy, mid.dx, mid.dy);
      }
      final penultimate = stars[stars.length - 2].position;
      final last = stars.last.position;
      path.quadraticBezierTo(penultimate.dx, penultimate.dy, last.dx, last.dy);

      final density = ((stars.length - 2) / 14).clamp(0.0, 1.0);
      final coreWidth = 2.0 - 1.0 * density;
      final glowWidth = 4.2 - 2.1 * density;
      final color = stars.first.color;

      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = glowWidth
        ..color = color.withOpacity(0.24)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2)
        ..blendMode = BlendMode.plus;
      final corePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = coreWidth
        ..color = color.withOpacity(0.78)
        ..blendMode = BlendMode.plus;

      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, corePaint);
    }
  }

  void _drawStars(Canvas canvas) {
    for (final star in layout.stars) {
      final center = star.position;

      final base = Paint()
        ..color = star.color.withOpacity(0.92)
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(center, 2.0, base);

      final baseGlow = Paint()
        ..color = star.color.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(center, 4.4, baseGlow);

      if (star.hasInsight) {
        final insightGlow = Paint()
          ..color = star.color.withOpacity(0.56)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
          ..blendMode = BlendMode.plus;
        canvas.drawCircle(center, 9.4, insightGlow);
      }

      if (star.hasAction) {
        final random = Random(star.thought.id);
        final count =
            14 + (star.thought.particleSpread * 4).round().clamp(0, 18);
        final spread = 10 + star.thought.particleSpread * 8;
        for (var i = 0; i < count; i++) {
          final angle = random.nextDouble() * pi * 2;
          final radius = spread * (0.25 + random.nextDouble() * 0.95);
          final p = Offset(
            center.dx + cos(angle) * radius,
            center.dy + sin(angle) * radius * 0.72,
          );
          final alpha = (0.14 + random.nextDouble() * 0.34).clamp(0.0, 1.0);
          final size = 0.7 + random.nextDouble() * 1.6;
          final particle = Paint()
            ..color = star.color.withOpacity(alpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2)
            ..blendMode = BlendMode.plus;
          canvas.drawCircle(p, size, particle);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyGalaxyPainter oldDelegate) {
    if (oldDelegate.layout.stars.length != layout.stars.length) return true;
    for (var i = 0; i < layout.stars.length; i++) {
      final current = layout.stars[i];
      final old = oldDelegate.layout.stars[i];
      if (current.position != old.position ||
          current.category != old.category ||
          current.hasInsight != old.hasInsight ||
          current.hasAction != old.hasAction) {
        return true;
      }
    }
    return false;
  }
}

class _CardStarDustPainter extends CustomPainter {
  final Color color;
  final int seed;

  const _CardStarDustPainter({
    required this.color,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed);
    const count = 44;
    for (var i = 0; i < count; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 0.4 + random.nextDouble() * 1.15;
      final alpha = (0.06 + random.nextDouble() * 0.26).clamp(0.0, 1.0);
      final dotPaint = Paint()
        ..color = color.withOpacity(alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.1)
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(Offset(x, y), radius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CardStarDustPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.seed != seed;
  }
}

class _StatConstellationPainter extends CustomPainter {
  final int count;
  final Color color;
  final bool particleMode;

  const _StatConstellationPainter({
    required this.count,
    required this.color,
    required this.particleMode,
  });

  List<Offset> _buildPoints(Size size) {
    final starCount = count.clamp(1, 18);
    final center = Offset(size.width * 0.5, size.height * 0.48);
    final baseRadius = min(size.width, size.height) * 0.28;
    final points = <Offset>[];
    for (var i = 0; i < starCount; i++) {
      final angle = (-pi / 2) + (2 * pi * i / starCount);
      final radiusMod = 0.82 + ((i % 3) * 0.11);
      points.add(
        Offset(
          center.dx + cos(angle) * baseRadius * radiusMod,
          center.dy + sin(angle) * baseRadius * radiusMod,
        ),
      );
    }
    return points;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final points = _buildPoints(size);
    if (points.isEmpty) return;

    if (points.length >= 2) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      if (points.length > 2) {
        path.lineTo(points.first.dx, points.first.dy);
      }

      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = color.withOpacity(0.55)
        ..blendMode = BlendMode.plus;
      final lineGlow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = color.withOpacity(0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2)
        ..blendMode = BlendMode.plus;
      canvas.drawPath(path, lineGlow);
      canvas.drawPath(path, linePaint);
    }

    final random = Random(count * (particleMode ? 37 : 17));
    for (final point in points) {
      final core = Paint()
        ..color = color.withOpacity(0.9)
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(point, 1.9, core);

      final glow = Paint()
        ..color = color.withOpacity(particleMode ? 0.3 : 0.58)
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, particleMode ? 4.5 : 7.5)
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(point, particleMode ? 4.1 : 5.8, glow);

      if (particleMode) {
        for (var i = 0; i < 6; i++) {
          final a = random.nextDouble() * pi * 2;
          final r = 4 + random.nextDouble() * 9;
          final particle = Offset(
            point.dx + cos(a) * r,
            point.dy + sin(a) * r * 0.78,
          );
          final paint = Paint()
            ..color = color.withOpacity(0.22 + random.nextDouble() * 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.1)
            ..blendMode = BlendMode.plus;
          canvas.drawCircle(particle, 0.8 + random.nextDouble(), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StatConstellationPainter oldDelegate) {
    return oldDelegate.count != count ||
        oldDelegate.color != color ||
        oldDelegate.particleMode != particleMode;
  }
}

class _WeeklyDensityOrb extends StatefulWidget {
  final int count;
  final Color color;

  const _WeeklyDensityOrb({
    required this.count,
    required this.color,
  });

  @override
  State<_WeeklyDensityOrb> createState() => _WeeklyDensityOrbState();
}

class _WeeklyDensityOrbState extends State<_WeeklyDensityOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _DensityOrbPainter(
            progress: _controller.value,
            count: widget.count,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class _DensityOrbPainter extends CustomPainter {
  final double progress;
  final int count;
  final Color color;

  const _DensityOrbPainter({
    required this.progress,
    required this.count,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) * 0.47;
    final shell = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF0C1622);
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = color.withOpacity(0.45);
    canvas.drawCircle(center, radius, shell);
    canvas.drawCircle(center, radius, border);

    final starCount = count.clamp(1, 30);
    final random = Random(starCount * 111);
    for (var i = 0; i < starCount; i++) {
      final seedA = random.nextDouble() * pi * 2;
      final seedR = random.nextDouble();
      final drift = (progress * pi * 2) + (i * 0.55);
      final r = radius * (0.2 + seedR * 0.7);
      final p = Offset(
        center.dx + cos(seedA + drift * 0.35) * r,
        center.dy + sin(seedA + drift * 0.25) * r * 0.72,
      );
      final point = Paint()
        ..color = color.withOpacity(0.35 + (0.4 * (0.5 + 0.5 * sin(drift))))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8)
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(p, 1.2 + (seedR * 1.3), point);
    }
  }

  @override
  bool shouldRepaint(covariant _DensityOrbPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.count != count ||
        oldDelegate.color != color;
  }
}
