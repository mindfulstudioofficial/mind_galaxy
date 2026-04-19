import 'package:hive/hive.dart';

part 'thought.g.dart';

@HiveType(typeId: 0)
class Thought extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  double dx;

  @HiveField(2)
  double dy;

  @HiveField(3)
  String content;

  @HiveField(4)
  String? insight;

  @HiveField(5)
  String? action;

  @HiveField(6)
  String category;

  /// 分類タグ（未来/過去/感情/行動）。Hive では [category] と同一フィールド。
  String get tag => category;
  set tag(String value) => category = value;

  @HiveField(7)
  bool isDeleting;
  
  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  DateTime? revisitAt;
  
  @HiveField(10)
  String? clusterId; // 将来、特定の「星団（週）」に属させるためのID

  @HiveField(11)
  bool isArchived; // 銀河（過去ログ）に送られたかどうかのフラグ

  bool isDragging = false;

  @HiveField(12) // 空いている番号（12）を使用
  int revisitCount; // 🚀 追加：0=未、1=1日後、2=3日後, 3=7日後...

  @HiveField(13)
  double starSize;

  @HiveField(14)
  double glowIntensity;

  @HiveField(15)
  double particleSpread;

  Thought({
    required this.id,
    required this.dx,
    required this.dy,
    required this.content,
    this.insight,
    this.action,
    required this.category,
    this.isDeleting = false,
    required this.createdAt,
    this.revisitAt,
    this.clusterId,
    this.revisitCount = 0,
    this.isArchived = false,
    this.starSize = 1.0,
    this.glowIntensity = 1.0,
    this.particleSpread = 1.0,
  });

  // 🚀 追加：再訪の準備ができているか判定する
  bool get isReadyToRevisit {
    final now = DateTime.now();
    final elapsedHours = now.difference(createdAt).inHours;
    if (elapsedHours < 0) return false;
    const targets = [24, 72, 168]; // 1日後 / 3日後 / 7日後
    const toleranceHours = 18;
    for (final target in targets) {
      if ((elapsedHours - target).abs() <= toleranceHours) return true;
    }
    return false;
  }
  @override
  bool get isInBox => key != null;
}