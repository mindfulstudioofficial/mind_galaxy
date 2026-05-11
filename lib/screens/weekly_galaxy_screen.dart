import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mindgalaxy/l10n/app_localizations.dart';
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
      case 'neutral':
        return const Color(0xFFDCE7FF);
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

  bool _useCinematicWeeklyRendering() {
    if (_weekThoughts.length < 180) return false;

    final countsByCategory = <String, int>{for (final c in _layerOrder) c: 0};
    for (final thought in _weekThoughts) {
      final c = _classifyThought(thought);
      countsByCategory[c] = (countsByCategory[c] ?? 0) + 1;
    }
    final denseCategoryCount =
        countsByCategory.values.where((count) => count >= 30).length;
    return denseCategoryCount >= 3;
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
        border: Border.all(color: _statsEmerald.withValues(alpha: 0.38), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: _statsEmerald.withValues(alpha: 0.12),
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
                  color: _statsEmerald.withValues(alpha: 0.22),
                  seed: summary.totalThoughts + 21,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: Transform.scale(
                    scale: compact ? 1.12 : 1.28,
                    child: SizedBox(
                      height: compact ? 74 : 102,
                      width: compact ? 74 : 102,
                      child: _WeeklyDensityOrb(
                        count: summary.totalThoughts,
                        color: _statsEmerald,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: compact ? 10 : 14),
              Text(
                AppLocalizations.of(context)!.weeklyDensity,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: compact ? 9 : 11,
                  letterSpacing: 2.4,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '$densityPercent%',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _statsEmerald.withValues(alpha: 0.78),
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

  String _starsCountLabel(int count) {
    return AppLocalizations.of(context)!.starsCount(count);
  }

  double _measureTextWidth(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  _LabelLayoutSpec _computeLabelLayoutSpec(
    BoxConstraints constraints,
    _WeeklySummary summary,
  ) {
    const minLabelWidth = 86.0;
    final maxLabelWidth = constraints.maxWidth * 0.34;
    const baseCategorySize = 12.0;
    const baseCountSize = 10.0;
    const minCategorySize = 9.6;
    const minCountSize = 8.6;
    const sidePadding = 16.0;

    var categorySize = baseCategorySize;
    var countSize = baseCountSize;
    var categorySpacing = 1.0;
    var countSpacing = 1.0;

    double requiredWidthFor({
      required double categoryFontSize,
      required double countFontSize,
      required double categoryLetterSpacing,
      required double countLetterSpacing,
    }) {
      var maxCategoryWidth = 0.0;
      var maxCountWidth = 0.0;
      for (final category in _layerOrder) {
        final categoryLabel = _categoryLabel(category);
        final starsLabel =
            _starsCountLabel(summary.countsByCategory[category] ?? 0);
        final categoryWidth = _measureTextWidth(
          categoryLabel,
          TextStyle(
            fontSize: categoryFontSize,
            fontWeight: FontWeight.w300,
            letterSpacing: categoryLetterSpacing,
          ),
        );
        final countWidth = _measureTextWidth(
          starsLabel,
          TextStyle(
            fontSize: countFontSize,
            fontWeight: FontWeight.w300,
            letterSpacing: countLetterSpacing,
          ),
        );
        if (categoryWidth > maxCategoryWidth) maxCategoryWidth = categoryWidth;
        if (countWidth > maxCountWidth) maxCountWidth = countWidth;
      }
      return max(maxCategoryWidth, maxCountWidth) + sidePadding;
    }

    var requiredWidth = requiredWidthFor(
      categoryFontSize: categorySize,
      countFontSize: countSize,
      categoryLetterSpacing: categorySpacing,
      countLetterSpacing: countSpacing,
    );

    if (requiredWidth > maxLabelWidth) {
      final scale = (maxLabelWidth / requiredWidth).clamp(0.75, 1.0);
      categorySize =
          (baseCategorySize * scale).clamp(minCategorySize, baseCategorySize);
      countSize = (baseCountSize * scale).clamp(minCountSize, baseCountSize);
      categorySpacing = (1.0 * scale).clamp(0.55, 1.0);
      countSpacing = (1.0 * scale).clamp(0.55, 1.0);
      requiredWidth = requiredWidthFor(
        categoryFontSize: categorySize,
        countFontSize: countSize,
        categoryLetterSpacing: categorySpacing,
        countLetterSpacing: countSpacing,
      );
    }

    final shouldWrapCategory = requiredWidth > maxLabelWidth;
    final labelWidth = shouldWrapCategory
        ? maxLabelWidth
        : requiredWidth.clamp(minLabelWidth, maxLabelWidth);
    final chartLeftGap = shouldWrapCategory ? 1.5 : 0.8;
    return _LabelLayoutSpec(
      labelColumnWidth: labelWidth,
      chartLeftGap: chartLeftGap,
      chartRightPadding: 3.0,
      categoryFontSize: categorySize,
      countFontSize: countSize,
      categoryLetterSpacing: categorySpacing,
      countLetterSpacing: countSpacing,
      categoryMaxLines: shouldWrapCategory ? 2 : 1,
      labelOverlayHeight: shouldWrapCategory ? 54.0 : 44.0,
      labelTopOffset: shouldWrapCategory ? -18.0 : -14.0,
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
        border: Border.all(color: _statsEmerald.withValues(alpha: 0.45), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: _statsEmerald.withValues(alpha: 0.14),
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
                  color: _statsEmerald.withValues(alpha: 0.24),
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
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: compact ? 9 : 11,
                  letterSpacing: 2.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _starsCountLabel(count),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _statsEmerald.withValues(alpha: 0.78),
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

  Widget _buildReportArea(_WeeklySummary summary, double height) {
    final compact = height < 220;
    final loc = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF090E19),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.12), width: 0.8),
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
              loc.weeklyAnalysis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
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
    final useCinematicRendering = _useCinematicWeeklyRendering();

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
                        final labelSpec =
                            _computeLabelLayoutSpec(constraints, summary);
                        final labelColumnWidth = labelSpec.labelColumnWidth;
                        final chartLeftGap = labelSpec.chartLeftGap;
                        final chartRightPadding = labelSpec.chartRightPadding;
                        final chartLeftInset = labelColumnWidth + chartLeftGap;
                        final layout = _WeeklyGalaxyLayout.build(
                          thoughts: _weekThoughts,
                          categoryResolver: _classifyThought,
                          layerOrder: _layerOrder,
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          leftInset: chartLeftInset,
                          rightInset: chartRightPadding,
                          colorForCategory: _colorForCategory,
                          isDemoMode: useCinematicRendering,
                        );
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _WeeklyGalaxyPainter(layout: layout),
                              ),
                            ),
                            Positioned(
                              left: chartLeftInset,
                              right: chartRightPadding,
                              top: 12,
                              child: Row(
                                children: List<Widget>.generate(
                                  7,
                                  (index) => Expanded(
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: Text(
                                        [
                                          loc.weekdayMonShort,
                                          loc.weekdayTueShort,
                                          loc.weekdayWedShort,
                                          loc.weekdayThuShort,
                                          loc.weekdayFriShort,
                                          loc.weekdaySatShort,
                                          loc.weekdaySunShort,
                                        ][index],
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.45),
                                          fontSize: 8.5,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            ...layout.layerY.entries.map((entry) {
                              final categoryCount =
                                  summary.countsByCategory[entry.key] ?? 0;
                              final categoryColor =
                                  _colorForCategory(entry.key);
                              return Positioned(
                                left: 10,
                                width: labelColumnWidth - 10,
                                top: entry.value + labelSpec.labelTopOffset,
                                child: IgnorePointer(
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        left: -2,
                                        top: -7,
                                        child: Container(
                                          width: labelColumnWidth + 12,
                                          height: labelSpec.labelOverlayHeight,
                                          decoration: const BoxDecoration(
                                            gradient: RadialGradient(
                                              center: Alignment(-0.75, -0.08),
                                              radius: 0.92,
                                              colors: [
                                                Color(0x50000000),
                                                Color(0x20000000),
                                                Color(0x00000000),
                                              ],
                                              stops: [0.0, 0.62, 1.0],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _categoryLabel(entry.key),
                                            maxLines:
                                                labelSpec.categoryMaxLines,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: categoryColor
                                                  .withValues(alpha: 0.78),
                                              fontSize:
                                                  labelSpec.categoryFontSize,
                                              fontWeight: FontWeight.w300,
                                              letterSpacing: labelSpec
                                                  .categoryLetterSpacing,
                                            ),
                                          ),
                                          Text(
                                            _starsCountLabel(categoryCount),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: categoryColor
                                                  .withValues(alpha: 0.58),
                                              fontSize: labelSpec.countFontSize,
                                              fontWeight: FontWeight.w300,
                                              letterSpacing:
                                                  labelSpec.countLetterSpacing,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            if (_weekThoughts.isEmpty)
                              Center(
                                child: Text(
                                  loc.noThoughtsThisWeek,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    fontSize: 13,
                                    letterSpacing: 2.4,
                                  ),
                                ),
                              ),
                          ],
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

class _LabelLayoutSpec {
  final double labelColumnWidth;
  final double chartLeftGap;
  final double chartRightPadding;
  final double categoryFontSize;
  final double countFontSize;
  final double categoryLetterSpacing;
  final double countLetterSpacing;
  final int categoryMaxLines;
  final double labelOverlayHeight;
  final double labelTopOffset;

  const _LabelLayoutSpec({
    required this.labelColumnWidth,
    required this.chartLeftGap,
    required this.chartRightPadding,
    required this.categoryFontSize,
    required this.countFontSize,
    required this.categoryLetterSpacing,
    required this.countLetterSpacing,
    required this.categoryMaxLines,
    required this.labelOverlayHeight,
    required this.labelTopOffset,
  });
}

class _WeeklyGalaxyLayout {
  static const int _maxConstellationStarsPerCategory = 14;
  final List<_PlottedStar> stars;
  final Map<String, List<_PlottedStar>> grouped;
  final Set<_PlottedStar> constellationStars;
  final Set<int> constellationThoughtIds;
  final Map<String, double> layerY;

  /// When true, constellation lines use [demoCurveAnchors] and stars use lightweight painting.
  final bool isDemoGalaxy;

  /// Monotonic X anchor points per category → smooth spline, no spaghetti crossings.
  final Map<String, List<Offset>>? demoCurveAnchors;

  const _WeeklyGalaxyLayout({
    required this.stars,
    required this.grouped,
    required this.constellationStars,
    required this.constellationThoughtIds,
    required this.layerY,
    this.isDemoGalaxy = false,
    this.demoCurveAnchors,
  });

  static _WeeklyGalaxyLayout build({
    required List<Thought> thoughts,
    required String Function(Thought) categoryResolver,
    required List<String> layerOrder,
    required double width,
    required double height,
    required double leftInset,
    required double rightInset,
    required Color Function(String) colorForCategory,
    bool isDemoMode = false,
  }) {
    if (isDemoMode) {
      return _buildDemoWeeklyGalaxyLayout(
        thoughts: thoughts,
        categoryResolver: categoryResolver,
        layerOrder: layerOrder,
        width: width,
        height: height,
        leftInset: leftInset,
        rightInset: rightInset,
        colorForCategory: colorForCategory,
      );
    }
    const topPad = 44.0;
    const bottomPad = 28.0;
    final usableHeight = max(1.0, height - topPad - bottomPad);
    final yMap = <String, double>{};
    for (var i = 0; i < layerOrder.length; i++) {
      final ratio = layerOrder.length == 1 ? 0.5 : i / (layerOrder.length - 1);
      yMap[layerOrder[i]] = topPad + usableHeight * ratio;
    }
    final categoryIndexByName = <String, int>{
      for (var i = 0; i < layerOrder.length; i++) layerOrder[i]: i,
    };

    final plotted = <_PlottedStar>[];
    for (final thought in thoughts) {
      final category = categoryResolver(thought);
      final dayOffset = thought.createdAt.weekday - DateTime.monday;
      final minutes = thought.createdAt.hour * 60 + thought.createdAt.minute;
      final xRatio = ((dayOffset + (minutes / 1440)).clamp(0.0, 6.9999)) / 7.0;
      final graphLeft = leftInset.clamp(0.0, width);
      final graphRight = rightInset.clamp(0.0, width);
      final graphWidth = max(1.0, width - graphLeft - graphRight);
      final x = graphLeft + graphWidth * xRatio;
      final baseline = yMap[category] ?? (topPad + usableHeight * 0.5);
      final categoryIndex =
          categoryIndexByName[category] ?? (layerOrder.length ~/ 2);
      final upperBound = categoryIndex == 0
          ? topPad + 5
          : ((yMap[layerOrder[categoryIndex - 1]] ?? baseline) + baseline) *
              0.5;
      final lowerBound = categoryIndex == layerOrder.length - 1
          ? height - bottomPad - 5
          : (baseline + (yMap[layerOrder[categoryIndex + 1]] ?? baseline)) *
              0.5;
      final halfBand = max(6.0, (lowerBound - upperBound) * 0.5);
      final phase = xRatio * pi * 2;
      final random = Random(thought.id * 9973 + categoryIndex * 131);
      final wavePrimary =
          sin(phase * 1.85 + categoryIndex * 0.9) * halfBand * 0.62;
      final waveSecondary =
          cos(phase * 2.1 + (thought.id % 17) * 0.22) * halfBand * 0.14;
      final localScatter = (random.nextDouble() - 0.5) * halfBand * 0.1;
      final y = (baseline + wavePrimary + waveSecondary + localScatter)
          .clamp(upperBound + 3, lowerBound - 3)
          .toDouble();

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
    for (final entry in grouped.entries) {
      final group = entry.value;
      group.sort((a, b) => a.thought.createdAt.compareTo(b.thought.createdAt));
      _smoothCategoryWave(
          group, yMap[entry.key] ?? (topPad + usableHeight * 0.5));
    }

    final alignedPlotted = grouped.values.expand((group) => group).toList()
      ..sort((a, b) => a.thought.createdAt.compareTo(b.thought.createdAt));

    final representativeGroups = <String, List<_PlottedStar>>{
      for (final c in layerOrder) c: <_PlottedStar>[],
    };
    final representativeSet = <_PlottedStar>{};
    for (final entry in grouped.entries) {
      final sampled = _pickRepresentativeStars(
        entry.value,
        maxStars: _maxConstellationStarsPerCategory,
      );
      representativeGroups[entry.key] = sampled;
      representativeSet.addAll(sampled);
    }

    return _WeeklyGalaxyLayout(
      stars: alignedPlotted,
      grouped: representativeGroups,
      constellationStars: representativeSet,
      constellationThoughtIds:
          representativeSet.map((star) => star.thought.id).toSet(),
      layerY: yMap,
      isDemoGalaxy: false,
      demoCurveAnchors: null,
    );
  }

  /// Screenshot-oriented layout: dense star field per band + single smooth S-curve per category.
  static _WeeklyGalaxyLayout _buildDemoWeeklyGalaxyLayout({
    required List<Thought> thoughts,
    required String Function(Thought) categoryResolver,
    required List<String> layerOrder,
    required double width,
    required double height,
    required double leftInset,
    required double rightInset,
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
    final categoryIndexByName = <String, int>{
      for (var i = 0; i < layerOrder.length; i++) layerOrder[i]: i,
    };

    final graphLeft = leftInset.clamp(0.0, width);
    final graphRight = rightInset.clamp(0.0, width);
    final graphWidth = max(1.0, width - graphLeft - graphRight);

    const anchorCount = 56;
    final demoAnchors = <String, List<Offset>>{};
    final plotted = <_PlottedStar>[];

    final phaseByCategory = <String, double>{
      'future': 0.15,
      'emotion': 1.05,
      'action': 1.95,
      'past': 0.65,
      'neutral': 1.4,
    };

    for (final cat in layerOrder) {
      final catThoughts = thoughts
          .where((t) => categoryResolver(t) == cat)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      final baseline = yMap[cat] ?? (topPad + usableHeight * 0.5);
      final categoryIndex =
          categoryIndexByName[cat] ?? (layerOrder.length ~/ 2);
      final upperBound = categoryIndex == 0
          ? topPad + 6
          : ((yMap[layerOrder[categoryIndex - 1]] ?? baseline) + baseline) *
              0.5;
      final lowerBound = categoryIndex == layerOrder.length - 1
          ? height - bottomPad - 6
          : (baseline + (yMap[layerOrder[categoryIndex + 1]] ?? baseline)) *
              0.5;
      final halfBand = max(10.0, (lowerBound - upperBound) * 0.5);
      final phase = phaseByCategory[cat] ?? 0.0;

      double yOnCurve(double xNorm) {
        final wobble = sin(2 * pi * xNorm * 0.88 + phase) * halfBand * 0.52;
        return (baseline + wobble).clamp(upperBound + 5, lowerBound - 5);
      }

      final anchors = <Offset>[];
      for (var j = 0; j < anchorCount; j++) {
        final xNorm = j / (anchorCount - 1);
        final x = graphLeft + graphWidth * xNorm;
        final y = yOnCurve(xNorm);
        anchors.add(Offset(x, y));
      }
      demoAnchors[cat] = anchors;

      for (var i = 0; i < catThoughts.length; i++) {
        final t = catThoughts[i];
        final xNorm = (i + 0.5) / catThoughts.length;
        final xBase = graphLeft + graphWidth * xNorm;
        final yBase = yOnCurve(xNorm);
        final rnd = Random(t.id * 1315423 + cat.hashCode);
        final x = (xBase + (rnd.nextDouble() - 0.5) * 12)
            .clamp(graphLeft + 3, graphLeft + graphWidth - 3);
        final y = (yBase + (rnd.nextDouble() - 0.5) * halfBand * 0.44)
            .clamp(upperBound + 3, lowerBound - 3);

        plotted.add(
          _PlottedStar(
            thought: t,
            category: cat,
            color: colorForCategory(cat),
            position: Offset(x, y),
            hasInsight: t.insight != null && t.insight!.trim().isNotEmpty,
            hasAction: t.action != null && t.action!.trim().isNotEmpty,
          ),
        );
      }
    }

    plotted.sort((a, b) => a.thought.createdAt.compareTo(b.thought.createdAt));
    final emptyGrouped = <String, List<_PlottedStar>>{
      for (final c in layerOrder) c: <_PlottedStar>[],
    };
    final allSet = plotted.toSet();

    return _WeeklyGalaxyLayout(
      stars: plotted,
      grouped: emptyGrouped,
      constellationStars: allSet,
      constellationThoughtIds: plotted.map((s) => s.thought.id).toSet(),
      layerY: yMap,
      isDemoGalaxy: true,
      demoCurveAnchors: demoAnchors,
    );
  }

  static List<_PlottedStar> _pickRepresentativeStars(
    List<_PlottedStar> stars, {
    required int maxStars,
  }) {
    final orderedByX = List<_PlottedStar>.from(stars)
      ..sort((a, b) => a.position.dx.compareTo(b.position.dx));
    final compactByX = _compactStarsByX(orderedByX, minXGap: 16.0);
    if (compactByX.length <= maxStars) return compactByX;
    if (maxStars <= 1) return <_PlottedStar>[compactByX.first];

    final selected = <_PlottedStar>[];
    final used = <int>{};
    final step = (compactByX.length - 1) / (maxStars - 1);

    for (var i = 0; i < maxStars; i++) {
      var index = (i * step).round().clamp(0, compactByX.length - 1);
      while (used.contains(index) && index < compactByX.length - 1) {
        index++;
      }
      if (used.contains(index)) {
        while (used.contains(index) && index > 0) {
          index--;
        }
      }
      if (used.add(index)) {
        selected.add(compactByX[index]);
      }
    }

    selected.sort((a, b) => a.position.dx.compareTo(b.position.dx));
    return selected;
  }

  static List<_PlottedStar> _compactStarsByX(
    List<_PlottedStar> stars, {
    required double minXGap,
  }) {
    if (stars.length <= 2) return stars;
    final compact = <_PlottedStar>[stars.first];
    for (var i = 1; i < stars.length; i++) {
      final current = stars[i];
      final last = compact.last;
      if ((current.position.dx - last.position.dx).abs() < minXGap) {
        final lastWeight = (last.hasInsight ? 1 : 0) + (last.hasAction ? 1 : 0);
        final currentWeight =
            (current.hasInsight ? 1 : 0) + (current.hasAction ? 1 : 0);
        if (currentWeight >= lastWeight) {
          compact[compact.length - 1] = current;
        }
        continue;
      }
      compact.add(current);
    }
    return compact;
  }

  static void _smoothCategoryWave(List<_PlottedStar> stars, double fallbackY) {
    if (stars.length < 3) return;
    final originalY = stars.map((s) => s.position.dy).toList(growable: false);
    final smoothed = List<double>.from(originalY);
    for (var i = 1; i < stars.length - 1; i++) {
      smoothed[i] = (originalY[i - 1] * 0.24) +
          (originalY[i] * 0.56) +
          (originalY[i + 1] * 0.24);
    }
    for (var i = 1; i < stars.length - 1; i++) {
      final star = stars[i];
      stars[i] = _PlottedStar(
        thought: star.thought,
        category: star.category,
        color: star.color,
        position: Offset(
            star.position.dx, smoothed[i].isNaN ? fallbackY : smoothed[i]),
        hasInsight: star.hasInsight,
        hasAction: star.hasAction,
      );
    }
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
    if (layout.isDemoGalaxy && layout.demoCurveAnchors != null) {
      for (final entry in layout.demoCurveAnchors!.entries) {
        final points = entry.value;
        if (points.length < 2) continue;

        final path = _buildSmoothSplinePath(points, tension: 0.32);
        final color = _colorForDemoCategory(entry.key);

        final glowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 2.15
          ..color = color.withValues(alpha: 0.14)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2)
          ..blendMode = BlendMode.plus;
        final corePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 0.95
          ..color = color.withValues(alpha: 0.4)
          ..blendMode = BlendMode.plus;

        canvas.drawPath(path, glowPaint);
        canvas.drawPath(path, corePaint);
      }
      return;
    }

    for (final entry in layout.grouped.entries) {
      final stars = List<_PlottedStar>.from(entry.value)
        ..sort((a, b) => a.position.dx.compareTo(b.position.dx));
      if (stars.length < 2) continue;

      final points = stars.map((s) => s.position).toList(growable: false);
      final path = _buildSmoothSplinePath(points, tension: 0.22);

      final density = ((stars.length - 2) / 14).clamp(0.0, 1.0);
      final coreWidth = 1.08 - 0.30 * density;
      final glowWidth = 2.0 - 0.5 * density;
      final color = stars.first.color;

      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = glowWidth
        ..color = color.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.6)
        ..blendMode = BlendMode.plus;
      final corePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = coreWidth
        ..color = color.withValues(alpha: 0.46)
        ..blendMode = BlendMode.plus;

      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, corePaint);
    }
  }

  Color _colorForDemoCategory(String category) {
    switch (category) {
      case 'future':
        return const Color(0xFF5CA8FF);
      case 'emotion':
        return const Color(0xFFFF79CC);
      case 'action':
        return const Color(0xFFFFE066);
      case 'past':
        return const Color(0xFFC184FF);
      case 'neutral':
        return const Color(0xFFDCE7FF);
      default:
        return Colors.white;
    }
  }

  Path _buildSmoothSplinePath(
    List<Offset> points, {
    required double tension,
  }) {
    final path = Path();
    if (points.isEmpty) return path;

    path.moveTo(points.first.dx, points.first.dy);
    if (points.length == 1) return path;
    if (points.length == 2) {
      path.lineTo(points.last.dx, points.last.dy);
      return path;
    }

    // Cardinal spline converted to cubic Bezier segments.
    // This keeps each segment endpoint on the star centers.
    final t = tension.clamp(0.0, 1.0);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = i == 0 ? points[i] : points[i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : points[i + 1];

      final c1 = Offset(
        p1.dx + (p2.dx - p0.dx) * (t / 6),
        p1.dy + (p2.dy - p0.dy) * (t / 6),
      );
      final c2 = Offset(
        p2.dx - (p3.dx - p1.dx) * (t / 6),
        p2.dy - (p3.dy - p1.dy) * (t / 6),
      );

      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }

    return path;
  }

  void _drawStars(Canvas canvas) {
    if (layout.isDemoGalaxy) {
      for (final star in layout.constellationStars) {
        _drawDemoGalaxyStarFieldDot(canvas, star);
      }
      return;
    }
    for (final star in layout.constellationStars) {
      _drawConstellationStar(canvas, star);
    }
  }

  /// Dense, soft stars for demo screenshots (lighter than full constellation hubs).
  void _drawDemoGalaxyStarFieldDot(Canvas canvas, _PlottedStar star) {
    final center = star.position;
    final rnd = Random(star.thought.id * 7919);
    final coreR = 0.55 + rnd.nextDouble() * 1.05;
    final glowR = coreR + 2.6 + rnd.nextDouble() * 3.8;
    final glowAlpha = star.hasInsight
        ? (0.12 + rnd.nextDouble() * 0.1)
        : (0.08 + rnd.nextDouble() * 0.08);
    final coreAlpha = 0.55 + rnd.nextDouble() * 0.35;

    final glow = Paint()
      ..color = star.color.withValues(alpha: glowAlpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.4)
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(center, glowR, glow);

    final core = Paint()
      ..color = star.color.withValues(alpha: coreAlpha)
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(center, coreR, core);

    if (star.hasInsight && rnd.nextDouble() < 0.14) {
      final halo = Paint()
        ..color = star.color.withValues(alpha: 0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(center, glowR * 1.45, halo);
    }
  }

  void _drawConstellationStar(Canvas canvas, _PlottedStar star) {
    final center = star.position;
    final sparkle =
        0.84 + Random(star.thought.id * 53 + 19).nextDouble() * 0.38;
    final coreRadius = 2.05 * sparkle;
    final glowRadius = 5.2 * sparkle;
    final insightRadius = 10.6 * sparkle;

    final base = Paint()
      ..color = star.color.withValues(alpha: 1.0)
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(center, coreRadius, base);

    final baseGlow = Paint()
      ..color = star.color.withValues(alpha: 0.66)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.9)
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(center, glowRadius, baseGlow);

    if (star.hasInsight) {
      final insightGlow = Paint()
        ..color = star.color.withValues(alpha: 0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13.8)
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(center, insightRadius, insightGlow);
    }

    if (star.hasAction) {
      final random = Random(star.thought.id);
      final count = 14 + (star.thought.particleSpread * 4).round().clamp(0, 18);
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
          ..color = star.color.withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2)
          ..blendMode = BlendMode.plus;
        canvas.drawCircle(p, size, particle);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyGalaxyPainter oldDelegate) {
    if (oldDelegate.layout.isDemoGalaxy != layout.isDemoGalaxy) return true;
    if (oldDelegate.layout.stars.length != layout.stars.length) return true;
    if (oldDelegate.layout.constellationThoughtIds.length !=
        layout.constellationThoughtIds.length) {
      return true;
    }
    if (!oldDelegate.layout.constellationThoughtIds
        .containsAll(layout.constellationThoughtIds)) {
      return true;
    }
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
        ..color = color.withValues(alpha: alpha)
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
      final radiusMod = particleMode
          ? 0.985 + sin((2 * pi * i / starCount) * 2.0) * 0.018
          : 0.88 + ((i % 3) * 0.08);
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
        ..color = color.withValues(alpha: 0.55)
        ..blendMode = BlendMode.plus;
      final lineGlow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = color.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2)
        ..blendMode = BlendMode.plus;
      canvas.drawPath(path, lineGlow);
      canvas.drawPath(path, linePaint);
    }

    final random = Random(count * (particleMode ? 37 : 17));
    for (final point in points) {
      final core = Paint()
        ..color = color.withValues(alpha: 0.9)
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(point, 1.9, core);

      final glow = Paint()
        ..color = color.withValues(alpha: particleMode ? 0.44 : 0.58)
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, particleMode ? 5.6 : 7.5)
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(point, particleMode ? 4.7 : 5.8, glow);

      if (particleMode) {
        for (var i = 0; i < 4; i++) {
          final baseAngle = (2 * pi * i / 4) + random.nextDouble() * 0.18;
          final r = 4.8 + random.nextDouble() * 4.6;
          final particle = Offset(
            point.dx + cos(baseAngle) * r,
            point.dy + sin(baseAngle) * r * 0.8,
          );
          final paint = Paint()
            ..color = color.withValues(alpha: 0.18 + random.nextDouble() * 0.2)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0)
            ..blendMode = BlendMode.plus;
          canvas.drawCircle(particle, 0.65 + random.nextDouble() * 0.7, paint);
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
      ..color = color.withValues(alpha: 0.45);
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
        ..color = color.withValues(alpha: 0.35 + (0.4 * (0.5 + 0.5 * sin(drift))))
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
