import 'package:uuid/uuid.dart';

class RestTime {
  final String id;
  final int seconds;
  final bool isCustom;
  final DateTime createdAt;

  const RestTime({
    required this.id,
    required this.seconds,
    required this.isCustom,
    required this.createdAt,
  });

  factory RestTime.create({
    required int seconds,
    bool isCustom = true,
  }) =>
      RestTime(
        id: const Uuid().v4(),
        seconds: seconds,
        isCustom: isCustom,
        createdAt: DateTime.now(),
      );

  factory RestTime.fromMap(Map<String, dynamic> map) => RestTime(
        id: map['id'] as String,
        seconds: map['seconds'] as int,
        isCustom: map['isCustom'] as bool,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'seconds': seconds,
        'isCustom': isCustom,
        'createdAt': createdAt.toIso8601String(),
      };

  RestTime copyWith({
    String? id,
    int? seconds,
    bool? isCustom,
    DateTime? createdAt,
  }) =>
      RestTime(
        id: id ?? this.id,
        seconds: seconds ?? this.seconds,
        isCustom: isCustom ?? this.isCustom,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestTime && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
