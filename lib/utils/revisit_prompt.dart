import 'package:mindgalaxy/l10n/app_localizations.dart';

import '../models/thought.dart';

bool isThoughtFieldBlank(String? value) =>
    value == null || value.trim().isEmpty;

String revisitNavigationPrompt(Thought thought, AppLocalizations loc) {
  if (isThoughtFieldBlank(thought.action)) {
    return loc.revisitPromptAddAction;
  }
  if (isThoughtFieldBlank(thought.insight)) {
    return loc.revisitPromptAddInsight;
  }
  if (DateTime.now().difference(thought.createdAt).inDays >= 7) {
    return loc.revisitPromptReflectTimePassed;
  }
  return loc.revisitPromptDeepen;
}

/// Advances automatic revisit schedule after a user completes a revisit session.
void applyRevisitSaveSchedule(Thought thought) {
  if (thought.revisitCount == 1) {
    thought.revisitAt = thought.createdAt.add(const Duration(minutes: 1));
    thought.revisitCount = 2;
  } else if (thought.revisitCount == 2) {
    thought.revisitAt = thought.createdAt.add(const Duration(days: 7));
    thought.revisitCount = 3;
  } else {
    thought.revisitAt = null;
  }
}

/// Batch-advances revisit schedule for a constellation group on save.
Future<void> applyRevisitSaveScheduleToGroup(Iterable<Thought> thoughts) async {
  for (final thought in thoughts) {
    applyRevisitSaveSchedule(thought);
    if (thought.isInBox) {
      await thought.save();
    }
  }
}
