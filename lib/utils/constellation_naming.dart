import '../models/thought.dart';

const _futureNames = ['Prospect', 'Aethelgard', 'Neo-Luminous', 'Horizon'];
const _actionNames = ['Kinetic', 'Ignis', 'Vortex', 'Impulse'];
const _pastNames = ['Mneme', 'Echo', 'Archive', 'Remnant'];
const _emotionNames = ['Lumen', 'Aura', 'Serene', 'Pulse'];
const _mixedNames = ['Prism', 'Nebula', 'Chromatic', 'Spectrum'];

/// Returns a catalog-style constellation designation, e.g. "Prospect" or "Prospect座".
String deriveConstellationName(List<Thought> stars, {bool japaneseSuffix = true}) {
  if (stars.isEmpty) return japaneseSuffix ? 'Void座' : 'Void';
  final categories = stars.map((s) => s.category).toSet();
  final pool = _namePoolForCategories(categories);
  final seed = stars.map((s) => s.id).fold<int>(0, (a, b) => a ^ b);
  final name = pool[seed.abs() % pool.length];
  return japaneseSuffix ? '$name座' : name;
}

List<String> _namePoolForCategories(Set<String> categories) {
  if (categories.length == 1) {
    switch (categories.first) {
      case 'future':
        return _futureNames;
      case 'action':
        return _actionNames;
      case 'past':
        return _pastNames;
      case 'emotion':
        return _emotionNames;
      default:
        return _mixedNames;
    }
  }
  if (categories.contains('future') &&
      categories.contains('action') &&
      categories.length == 2) {
    return ['Kinetic', 'Ignis', 'Vortex'];
  }
  return _mixedNames;
}
