import 'package:flutter/material.dart';

/// Brief welcome message shown once after onboarding completes.
class OnboardingWelcomeOverlay extends StatelessWidget {
  final String message;
  final double opacity;

  const OnboardingWelcomeOverlay({
    super.key,
    required this.message,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        child: Align(
          alignment: const Alignment(0, -0.12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w300,
                letterSpacing: 1.5,
                height: 1.6,
                shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
