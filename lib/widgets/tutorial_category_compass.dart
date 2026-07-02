import 'dart:ui';

import 'package:flutter/material.dart';

/// Tutorial compass for classifying stars by drag direction.
///
/// Placed in the top safe zone so it stays visible while the user drags
/// (fingers typically cover the lower half of the screen).
class TutorialCategoryCompass extends StatelessWidget {
  const TutorialCategoryCompass({
    super.key,
    required this.labels,
    required this.colorForCategory,
    this.activeCategory,
    this.isDragging = false,
    this.compact = false,
  });

  final Map<String, String> labels;
  final Color Function(String category) colorForCategory;
  final String? activeCategory;
  final bool isDragging;
  final bool compact;

  static const List<String> _topCategory = ['future'];
  static const List<String> _leftCategory = ['emotion'];
  static const List<String> _rightCategory = ['action'];
  static const List<String> _bottomCategory = ['past'];

  @override
  Widget build(BuildContext context) {
    final slotSize = compact ? 52.0 : 60.0;
    final crossGap = compact ? 6.0 : 8.0;
    final centerSize = compact ? 28.0 : 32.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 18,
            vertical: compact ? 12 : 14,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CompassRow(
                categories: _topCategory,
                labels: labels,
                colorForCategory: colorForCategory,
                activeCategory: activeCategory,
                isDragging: isDragging,
                slotSize: slotSize,
                crossGap: crossGap,
                direction: _CompassDirection.up,
              ),
              SizedBox(height: crossGap),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CompassRow(
                    categories: _leftCategory,
                    labels: labels,
                    colorForCategory: colorForCategory,
                    activeCategory: activeCategory,
                    isDragging: isDragging,
                    slotSize: slotSize,
                    crossGap: crossGap,
                    direction: _CompassDirection.left,
                  ),
                  SizedBox(width: crossGap),
                  _CompassCenter(
                    size: centerSize,
                    activeColor: activeCategory == null
                        ? null
                        : colorForCategory(activeCategory!),
                    isDragging: isDragging,
                  ),
                  SizedBox(width: crossGap),
                  _CompassRow(
                    categories: _rightCategory,
                    labels: labels,
                    colorForCategory: colorForCategory,
                    activeCategory: activeCategory,
                    isDragging: isDragging,
                    slotSize: slotSize,
                    crossGap: crossGap,
                    direction: _CompassDirection.right,
                  ),
                ],
              ),
              SizedBox(height: crossGap),
              _CompassRow(
                categories: _bottomCategory,
                labels: labels,
                colorForCategory: colorForCategory,
                activeCategory: activeCategory,
                isDragging: isDragging,
                slotSize: slotSize,
                crossGap: crossGap,
                direction: _CompassDirection.down,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _CompassDirection { up, down, left, right }

class _CompassRow extends StatelessWidget {
  const _CompassRow({
    required this.categories,
    required this.labels,
    required this.colorForCategory,
    required this.activeCategory,
    required this.isDragging,
    required this.slotSize,
    required this.crossGap,
    required this.direction,
  });

  final List<String> categories;
  final Map<String, String> labels;
  final Color Function(String category) colorForCategory;
  final String? activeCategory;
  final bool isDragging;
  final double slotSize;
  final double crossGap;
  final _CompassDirection direction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < categories.length; i++) ...[
          if (i > 0) SizedBox(width: crossGap),
          _CompassSlot(
            category: categories[i],
            label: labels[categories[i]] ?? categories[i],
            color: colorForCategory(categories[i]),
            isActive: activeCategory == categories[i],
            isDragging: isDragging,
            slotSize: slotSize,
            direction: direction,
          ),
        ],
      ],
    );
  }
}

class _CompassCenter extends StatelessWidget {
  const _CompassCenter({
    required this.size,
    required this.activeColor,
    required this.isDragging,
  });

  final double size;
  final Color? activeColor;
  final bool isDragging;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDragging && activeColor != null
            ? activeColor!.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: isDragging && activeColor != null
              ? activeColor!.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.12),
        ),
        boxShadow: isDragging && activeColor != null
            ? [
                BoxShadow(
                  color: activeColor!.withValues(alpha: 0.35),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: Icon(
        Icons.star_rounded,
        size: size * 0.52,
        color: isDragging && activeColor != null
            ? activeColor
            : Colors.white.withValues(alpha: 0.35),
      ),
    );
  }
}

class _CompassSlot extends StatelessWidget {
  const _CompassSlot({
    required this.category,
    required this.label,
    required this.color,
    required this.isActive,
    required this.isDragging,
    required this.slotSize,
    required this.direction,
  });

  final String category;
  final String label;
  final Color color;
  final bool isActive;
  final bool isDragging;
  final double slotSize;
  final _CompassDirection direction;

  IconData get _directionIcon {
    switch (direction) {
      case _CompassDirection.up:
        return Icons.north_rounded;
      case _CompassDirection.down:
        return Icons.south_rounded;
      case _CompassDirection.left:
        return Icons.west_rounded;
      case _CompassDirection.right:
        return Icons.east_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final showFullChip = !isDragging || isActive;
    final targetOpacity = isDragging
        ? (isActive ? 1.0 : 0.22)
        : (isActive ? 0.85 : 0.42);
    final targetScale = isDragging ? (isActive ? 1.0 : 0.82) : 0.94;

    return AnimatedScale(
      scale: targetScale,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: targetOpacity,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: slotSize,
          height: slotSize,
          child: showFullChip
              ? _CategoryChip(
                  label: label,
                  color: color,
                  isActive: isActive,
                  isDragging: isDragging,
                  directionIcon: _directionIcon,
                )
              : Center(
                  child: Icon(
                    _directionIcon,
                    size: 16,
                    color: color.withValues(alpha: 0.55),
                  ),
                ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.color,
    required this.isActive,
    required this.isDragging,
    required this.directionIcon,
  });

  final String label;
  final Color color;
  final bool isActive;
  final bool isDragging;
  final IconData directionIcon;

  @override
  Widget build(BuildContext context) {
    final highlight = isDragging && isActive;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: highlight ? 0.22 : 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: highlight ? 0.75 : 0.35),
          width: highlight ? 1.4 : 1.0,
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            directionIcon,
            size: highlight ? 14 : 12,
            color: color.withValues(alpha: highlight ? 0.95 : 0.7),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color.withValues(alpha: highlight ? 1.0 : 0.82),
              fontSize: highlight ? 12.5 : 11,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: 0.3,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
