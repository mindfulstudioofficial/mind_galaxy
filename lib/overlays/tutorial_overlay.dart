import 'package:flutter/material.dart';

class TutorialOverlay extends StatelessWidget {
  final Widget child;
  final bool visible;

  const TutorialOverlay({
    super.key,
    required this.child,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Positioned.fill(child: child);
  }
}
