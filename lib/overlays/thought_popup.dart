import 'package:flutter/material.dart';
import 'package:mindgalaxy/l10n/app_localizations.dart';

import '../models/thought.dart';
import '../utils/constellation_naming.dart';
import '../utils/revisit_prompt.dart';

/// Revisit dialog shown after a constellation forms or for a single star revisit.
class ThoughtPopup {
  ThoughtPopup._();

  /// Returns `true` when the user chooses to update, otherwise `false`/`null`.
  static Future<bool?> show(
    BuildContext context, {
    required Thought mainThought,
    List<Thought> contextThoughts = const [],
    String? constellationName,
  }) {
    final loc = AppLocalizations.of(context)!;
    final name = constellationName ??
        deriveConstellationName([mainThought, ...contextThoughts]);
    final prompt = revisitNavigationPrompt(mainThought, loc);
    final hasContext = contextThoughts.isNotEmpty;

    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF1C1C1E),
          elevation: 24,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 360,
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.72,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    hasContext ? '✨ $name' : '✨ ${loc.starRevisitTitle}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasContext) ...[
                            Text(
                              loc.constellationContextHint,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 10),
                            for (final thought in contextThoughts)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _ContextPreviewCard(thought: thought),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              loc.constellationMainStarLabel,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ] else ...[
                            Text(
                              loc.revisitThoughtLabel,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Text(
                            '「${mainThought.content}」',
                            style: const TextStyle(
                              color: Colors.yellowAccent,
                              fontSize: 18,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            prompt,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: Text(
                          loc.laterButtonLabel,
                          style: const TextStyle(color: Colors.white38),
                        ),
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                        child: Text(loc.updateContentButtonLabel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ContextPreviewCard extends StatelessWidget {
  final Thought thought;

  const _ContextPreviewCard({required this.thought});

  Color _categoryColor(String category) {
    switch (category) {
      case 'future':
        return Colors.blue;
      case 'past':
        return Colors.purple;
      case 'emotion':
        return Colors.pink;
      case 'action':
        return Colors.yellow;
      default:
        return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(thought.category);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.star, size: 13, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  thought.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                if ((thought.insight ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    thought.insight!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
