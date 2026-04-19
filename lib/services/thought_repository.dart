import 'package:hive/hive.dart';
import '../models/thought.dart';

class ThoughtRepository {
  const ThoughtRepository();

  Box<Thought> get _box => Hive.box<Thought>('thoughts');

  List<Thought> fetchAll() => _box.values.toList();

  Future<int> add(Thought thought) => _box.add(thought);

  Future<void> save(Thought thought) => thought.save();

  Future<void> delete(Thought thought) => thought.delete();
}
