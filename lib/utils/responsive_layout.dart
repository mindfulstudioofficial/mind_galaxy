import 'package:flutter/material.dart';

/// Breakpoint aligned with Material "medium" width (tablet / unfolded phone).
const double kTabletBreakpoint = 600;

/// Max width for form-like content on large screens.
const double kMaxContentWidth = 720;

/// Max width for modal panels (popups, pickers) on tablet.
const double kMaxModalWidth = 560;

extension ResponsiveLayoutContext on BuildContext {
  Size get layoutSize => MediaQuery.sizeOf(this);

  EdgeInsets get layoutViewPadding => MediaQuery.viewPaddingOf(this);

  bool get isTabletLayout => layoutSize.shortestSide >= kTabletBreakpoint;

  double get contentMaxWidth =>
      isTabletLayout ? kMaxContentWidth : layoutSize.width;

  double get modalMaxWidth =>
      isTabletLayout ? kMaxModalWidth : layoutSize.width * 0.9;
}

/// Centers [child] and constrains width on tablet-sized layouts.
class ResponsiveContentWidth extends StatelessWidget {
  const ResponsiveContentWidth({
    super.key,
    required this.child,
    this.maxWidth = kMaxContentWidth,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Bottom sheet on phone; centered dialog on tablet.
Future<T?> showAdaptivePanel<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  ShapeBorder? sheetShape,
}) {
  if (context.isTabletLayout) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: backgroundColor ?? const Color(0xFF080E1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxModalWidth),
          child: builder(ctx),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: backgroundColor ?? const Color(0xFF080E1A),
    shape: sheetShape ??
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
    builder: builder,
  );
}
