import '../models/thought.dart';
import 'thought_repository.dart';

class ThoughtService {
  final ThoughtRepository repository;

  ThoughtService({ThoughtRepository? repository})
      : repository = repository ?? const ThoughtRepository();

  List<Thought> loadThoughts() => repository.fetchAll();
}
